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
  curl -sS --fail-with-body -X POST "$DD_URL/api/v2/reimport-scan/" \
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
    -o /dev/null
}

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
