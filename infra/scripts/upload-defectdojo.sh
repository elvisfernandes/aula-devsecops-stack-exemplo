#!/bin/sh
# Envia os relatorios gerados no pipeline para o DefectDojo.
# Variaveis obrigatorias: DD_URL, DD_TOKEN. As demais vem do GitLab CI.
set -eu

: "${DD_URL:?DD_URL nao definido}"
: "${DD_TOKEN:?DD_TOKEN nao definido}"

PRODUCT="${DD_PRODUCT_NAME:-${CI_PROJECT_NAME:-shoes-app}}"
ENGAGEMENT="${CI_COMMIT_REF_SLUG:-local}"

upload() {
  scan_type="$1"
  file="$2"
  title="$3"

  if [ ! -s "$file" ]; then
    echo "[skip] $file nao encontrado"
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
upload "NPM Audit Scan"               reports/npm-audit.json            "npm audit"
upload "Gitleaks Scan"                reports/gitleaks.json             "Gitleaks"
upload "Trivy Scan"                   reports/trivy-image-backend.json  "Trivy Image - backend"
upload "Trivy Scan"                   reports/trivy-image-frontend.json "Trivy Image - frontend"
upload "Hadolint Dockerfile check"    reports/hadolint.json             "Hadolint"
upload "Checkov Scan"                 reports/checkov.json              "Checkov"
