#!/bin/sh
# Envia os relatórios gerados no pipeline para o DefectDojo.
# Variáveis obrigatórias: DD_URL, DD_TOKEN. As demais vêm do GitLab CI.
set -eu

: "${DD_URL:?DD_URL não definido}"
: "${DD_TOKEN:?DD_TOKEN não definido}"

PRODUCT="${DD_PRODUCT_NAME:-${CI_PROJECT_NAME:-aula-devsecops-stack-exemplo}}"
ENGAGEMENT="${CI_COMMIT_REF_SLUG:-local}"

upload() {
  scan_type="$1"
  file="$2"
  title="$3"

  if [ ! -s "$file" ]; then
    echo "[skip] $file não encontrado"
    return 0
  fi

  echo "[upload] $title ($scan_type)"
  if ! curl -sS --fail-with-body -X POST "$DD_URL/api/v2/reimport-scan/" \
    -H "Authorization: Token $DD_TOKEN" \
    -F "scan_type=$scan_type" \
    -F "file=@$file" \
    -F "product_type_name=Academico" \
    -F "product_name=$PRODUCT" \
    -F "engagement_name=$ENGAGEMENT" \
    -F "test_title=$title" \
    -F "auto_create_context=true" \
    -F "close_old_findings=true" \
    -F "branch_tag=${CI_COMMIT_REF_NAME:-local}" \
    -F "commit_hash=${CI_COMMIT_SHA:-}" \
    -F "build_id=${CI_PIPELINE_ID:-}" \
    -o /tmp/dd-response.txt; then
    echo "[erro] falha ao enviar $title:" >&2
    cat /tmp/dd-response.txt >&2 2>/dev/null || true
    echo >&2
    failures=$((failures + 1))
  fi
}

failures=0

upload "Semgrep JSON Report"          reports/semgrep.json              "Semgrep"
upload "Bandit Scan"                  reports/bandit.json               "Bandit"
upload "Trivy Scan"                   reports/trivy-fs.json             "Trivy FS"
upload "pip-audit Scan"               reports/pip-audit.json            "pip-audit"
upload "NPM Audit v7+ Scan"           reports/npm-audit.json            "npm audit"
upload "Gitleaks Scan"                reports/gitleaks.json             "Gitleaks"
upload "Trivy Scan"                   reports/trivy-image-backend.json  "Trivy Image - backend"
upload "Trivy Scan"                   reports/trivy-image-frontend.json "Trivy Image - frontend"
upload "Hadolint Dockerfile check"    reports/hadolint.json             "Hadolint"
upload "Checkov Scan"                 reports/checkov.json              "Checkov"
upload "ZAP Scan"                     reports/zap-baseline.json         "ZAP Baseline"
upload "ZAP Scan"                     reports/zap-api.json              "ZAP API"

# O reimport grava build_id/commit_hash no Test; o Engagement é atualizado à parte.
echo "[engagement] atualizando metadados do pipeline"
eng_json=$(curl -sS -G "$DD_URL/api/v2/engagements/" \
  -H "Authorization: Token $DD_TOKEN" \
  --data-urlencode "name=$ENGAGEMENT" \
  --data-urlencode "product__name=$PRODUCT" \
  --data-urlencode "limit=1" || true)
eng_id=$(printf '%s' "$eng_json" | sed -n 's/.*"results":\[{"id":\([0-9]*\).*/\1/p')

if [ -n "$eng_id" ]; then
  if ! curl -sS --fail-with-body -X PATCH "$DD_URL/api/v2/engagements/$eng_id/" \
    -H "Authorization: Token $DD_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"build_id\":\"${CI_PIPELINE_ID:-}\",\"commit_hash\":\"${CI_COMMIT_SHA:-}\",\"branch_tag\":\"${CI_COMMIT_REF_NAME:-local}\",\"source_code_management_uri\":\"${CI_PROJECT_URL:-}\",\"description\":\"Pipeline ${CI_PIPELINE_URL:-local} (commit ${CI_COMMIT_SHORT_SHA:-})\"}" \
    -o /dev/null; then
    echo "[aviso] não foi possível atualizar o engagement $eng_id" >&2
  fi
else
  echo "[aviso] engagement '$ENGAGEMENT' não encontrado; metadados não atualizados" >&2
fi

[ "$failures" -eq 0 ] || { echo "$failures upload(s) falharam" >&2; exit 1; }
