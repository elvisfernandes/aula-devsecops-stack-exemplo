#!/usr/bin/env bash
# Clona o repositorio oficial do DefectDojo e sobe o stack via docker compose.
# Depois conecta o DefectDojo a rede "devsecops" (alias "defectdojo") para que
# os jobs do GitLab Runner o alcancem em http://defectdojo:8080.
set -euo pipefail

cd "$(dirname "$0")"

DD_DIR="django-DefectDojo"
export DD_ALLOWED_HOSTS="${DD_ALLOWED_HOSTS:-*}"

[ -d "$DD_DIR" ] || git clone --depth 1 https://github.com/DefectDojo/django-DefectDojo.git "$DD_DIR"
cd "$DD_DIR"

docker compose pull
docker compose up -d

docker network inspect devsecops >/dev/null 2>&1 || docker network create devsecops
NGINX=$(docker compose ps -q nginx)
docker network connect --alias defectdojo devsecops "$NGINX" 2>/dev/null || true

echo
echo "DefectDojo: http://localhost:8080 (usuario: admin)"
echo "Senha inicial (aguarde o initializer terminar):"
echo "  docker compose -f infra/defectdojo/$DD_DIR/docker-compose.yml logs initializer | grep 'Admin password:'"
echo "API token: menu do usuario > API v2 Key"
