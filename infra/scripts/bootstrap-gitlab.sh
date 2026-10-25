#!/usr/bin/env bash
# Sobe GitLab CE + Runner (docker executor com dind), cria o projeto,
# registra o runner, configura as variáveis de CI e envia todos os branches.
# Execute a partir de qualquer pasta, no mesmo host em que o GitLab roda.
set -euo pipefail
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/../.."

[ -f infra/.env ] || cp infra/.env.example infra/.env
set -a
. infra/.env
set +a

GITLAB_PORT="${GITLAB_PORT:-8929}"
GITLAB_PROJECT="${GITLAB_PROJECT:-aula-devsecops-stack-exemplo}"
GL_URL="http://localhost:${GITLAB_PORT}"
COMPOSE="docker compose -f infra/gitlab/docker-compose.yml --env-file infra/.env"
TOKEN_FILE="infra/.gitlab-token"

echo "==> Subindo GitLab e Runner"
$COMPOSE up -d

echo "==> Aguardando o GitLab ficar disponível (pode levar de 3 a 10 minutos)"
for _ in $(seq 1 120); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$GL_URL/users/sign_in" || true)
  [ "$code" = "200" ] && break
  sleep 10
done
[ "$code" = "200" ] || { echo "GitLab não respondeu a tempo"; exit 1; }

api() {
  curl -sS --fail-with-body -H "PRIVATE-TOKEN: $PAT" "$@"
}

if [ -s "$TOKEN_FILE" ] && PAT=$(cat "$TOKEN_FILE") && api -o /dev/null "$GL_URL/api/v4/user" 2>/dev/null; then
  echo "==> Reutilizando token de acesso existente"
else
  echo "==> Criando token de acesso do root"
  PAT="glpat-$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 26)"
  docker exec gitlab gitlab-rails runner "
    user = User.find_by_username('root')
    token = user.personal_access_tokens.create!(
      name: 'bootstrap', scopes: [:api, :create_runner], expires_at: 60.days.from_now)
    token.set_token('${PAT}')
    token.save!
  "
  echo "$PAT" > "$TOKEN_FILE"
fi

echo "==> Aumentando o limite de artefatos para 2 GB (os .tar das imagens passam de 100 MB)"
api -o /dev/null -X PUT "$GL_URL/api/v4/application/settings" --data "max_artifacts_size=2048"

echo "==> Criando o projeto $GITLAB_PROJECT"
if ! api -o /dev/null "$GL_URL/api/v4/projects/root%2F${GITLAB_PROJECT}" 2>/dev/null; then
  api -o /dev/null -X POST "$GL_URL/api/v4/projects" \
    --data "name=${GITLAB_PROJECT}" --data "visibility=private" --data "initialize_with_readme=false"
fi
PROJECT_ID=$(api "$GL_URL/api/v4/projects/root%2F${GITLAB_PROJECT}" | sed -E 's/^\{"id":([0-9]+).*/\1/')

echo "==> Registrando o runner"
if ! docker exec gitlab-runner grep -q '\[\[runners\]\]' /etc/gitlab-runner/config.toml 2>/dev/null; then
  RUNNER_TOKEN=$(api -X POST "$GL_URL/api/v4/user/runners" \
    --data "runner_type=project_type" --data "project_id=${PROJECT_ID}" \
    --data "description=docker-dind" --data "run_untagged=true" \
    | sed -E 's/.*"token":"([^"]+)".*/\1/')
  docker exec gitlab-runner gitlab-runner register --non-interactive \
    --url "http://gitlab:${GITLAB_PORT}" \
    --clone-url "http://gitlab:${GITLAB_PORT}" \
    --token "$RUNNER_TOKEN" \
    --executor docker \
    --docker-image docker:27 \
    --docker-privileged \
    --docker-network-mode devsecops \
    --docker-volumes /cache \
    --docker-volumes /var/run/docker.sock:/var/run/host-docker.sock
else
  echo "    runner já registrado"
fi

if [ -n "${DD_TOKEN:-}" ]; then
  echo "==> Configurando variáveis DD_URL e DD_TOKEN no projeto"
  for pair in "DD_URL:${DD_URL}:false" "DD_TOKEN:${DD_TOKEN}:true"; do
    key="${pair%%:*}"; rest="${pair#*:}"; masked="${rest##*:}"; value="${rest%:*}"
    api -o /dev/null -X DELETE "$GL_URL/api/v4/projects/${PROJECT_ID}/variables/${key}" 2>/dev/null || true
    api -o /dev/null -X POST "$GL_URL/api/v4/projects/${PROJECT_ID}/variables" \
      --data "key=${key}" --data-urlencode "value=${value}" --data "masked=${masked}"
  done
else
  echo "==> DD_TOKEN vazio: o envio ao DefectDojo ficará desativado no pipeline"
fi

echo "==> Enviando branches"
REMOTE="http://root:${PAT}@localhost:${GITLAB_PORT}/root/${GITLAB_PROJECT}.git"
git push "$REMOTE" main
git push "$REMOTE" --all

echo
echo "Pronto: $GL_URL/root/${GITLAB_PROJECT}"
echo "Usuário: root | Senha: definida em GITLAB_ROOT_PASSWORD (infra/.env)"
