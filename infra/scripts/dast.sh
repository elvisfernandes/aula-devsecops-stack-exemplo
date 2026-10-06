#!/bin/sh
# Scan DAST com OWASP ZAP contra a aplicação em execução.
# Pensado para rodar no GitLab CI (imagem docker:27 + serviço dind), mas funciona
# em qualquer host com Docker. Gera reports/zap-baseline.json e reports/zap-api.json.
#
#   1. sobe o stack (db + backend + frontend) com o docker compose
#   2. zap-baseline.py: spider + regras passivas no frontend (headers, cookies, CSP)
#   3. zap-api-scan.py: scan ativo guiado por dast/openapi.yaml (injeções, etc.)
#   4. derruba o stack
#
# Código de saída: 1 se o ZAP falhar ao executar ou se houver alerta de risco ALTO
# (riskcode 3) nos relatórios; alertas médios/baixos apenas aparecem no relatório.
set -eu

cd "$(dirname "$0")/../.."

ZAP_IMAGE="${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy:stable}"
TARGET="${DAST_TARGET:-http://localhost:3000}"
API_SCAN_MINUTES="${DAST_API_SCAN_MINUTES:-5}"
PROJECT="$(sed -n 's/^name: *//p' docker-compose.yml)"

mkdir -p reports

# Na main o .env é versionado; nos demais branches é gerado com senha aleatória.
if [ ! -f .env ]; then
  cp .env.example .env
  password="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${password}|" .env
fi

# Reaproveita as imagens construídas no job build-images, quando existirem,
# para que o DAST teste o mesmo artefato que passou pelo image scanning.
if [ -f images/backend.tar ] && [ -f images/frontend.tar ]; then
  echo "==> Carregando imagens do job build-images"
  docker load -i images/backend.tar
  docker load -i images/frontend.tar
  docker tag "shoes-backend:${CI_COMMIT_SHORT_SHA}" "${PROJECT}-backend:latest"
  docker tag "shoes-frontend:${CI_COMMIT_SHORT_SHA}" "${PROJECT}-frontend:latest"
  compose_up="docker compose up -d --no-build"
else
  compose_up="docker compose up -d --build"
fi

cleanup() {
  docker compose down -v >/dev/null 2>&1 || true
  docker rm -f zap-baseline zap-api >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Subindo a aplicação"
$compose_up

echo "==> Aguardando a aplicação responder em $TARGET"
ready=""
for _ in $(seq 1 60); do
  if docker run --rm --network host curlimages/curl:latest -fsS -o /dev/null "$TARGET/api/shoes" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 3
done
[ -n "$ready" ] || { echo "Aplicação não respondeu a tempo"; docker compose logs --tail 50; exit 1; }

# Executa o ZAP em um container com rede do host (alcança localhost:3000) e copia o
# relatório com docker cp, pois com dind os volumes do job não são visíveis ao daemon.
run_zap() {
  name="$1"
  report="$2"
  shift 2
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker create --name "$name" --network host --user root "$ZAP_IMAGE" "$@" >/dev/null
  docker cp dast/. "$name":/zap/wrk/
  rc=0
  docker start -a "$name" || rc=$?
  docker cp "$name":"/zap/wrk/$report" "reports/$report" || echo "[aviso] relatório $report não gerado"
  return "$rc"
}

status=0

echo "==> ZAP baseline (passivo) em $TARGET"
rc=0
run_zap zap-baseline zap-baseline.json \
  zap-baseline.py -t "$TARGET" -J zap-baseline.json || rc=$?
[ "$rc" -le 2 ] || status=1

echo "==> ZAP API scan (ativo) com dast/openapi.yaml"
rc=0
run_zap zap-api zap-api.json \
  zap-api-scan.py -t openapi.yaml -f openapi -O "$TARGET" -J zap-api.json \
  -z "-config scanner.maxScanDurationInMins=${API_SCAN_MINUTES}" || rc=$?
[ "$rc" -le 2 ] || status=1

for f in reports/zap-baseline.json reports/zap-api.json; do
  if [ -f "$f" ] && grep -q '"riskcode": *"3"' "$f"; then
    echo "[DAST] alerta de risco ALTO em $f"
    status=1
  fi
done

exit "$status"
