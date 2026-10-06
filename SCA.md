# SCA - Software Composition Analysis

SCA inventaria as **dependências de terceiros** (diretas e transitivas) e cruza as versões com bases de vulnerabilidades conhecidas (CVE, GHSA, OSV). A maior parte do código de uma aplicação moderna vem de bibliotecas, então é uma superfície de ataque grande.
Limitação: só conhece vulnerabilidades *publicadas*; não diz se o código vulnerável da biblioteca é realmente alcançado pela aplicação.

## Como funciona (comum às ferramentas)

1. Lê manifestos e lockfiles (`requirements.txt`, `package-lock.json`).
2. Monta a lista de pacotes e versões exatas.
3. Consulta uma base de advisories e reporta os pacotes afetados, a severidade e a **versão corrigida**.

Por isso o *lockfile* importa: sem versões fixadas o resultado não é reprodutível.

## Trivy (modo `fs`)

**O que é:** scanner open source da Aqua Security para vulnerabilidades, segredos e misconfigurations.
**Como funciona no modo fs:** varre o diretório, detecta lockfiles e compara com seu banco de vulnerabilidades (baixado e atualizado automaticamente).
```
trivy fs --severity HIGH,CRITICAL .
```

## pip-audit

**O que é:** ferramenta da PyPA para auditar dependências Python.
**Como funciona:** resolve as versões de `requirements.txt` e consulta o PyPI/OSV Advisory Database.
```
pip-audit -r backend/requirements.txt
```

## npm audit

**O que é:** auditoria embutida no npm.
**Como funciona:** envia a árvore de dependências do `package-lock.json` ao registry, que responde com os advisories aplicáveis.
```
cd frontend && npm audit --audit-level=high
```

## Dependências vulneráveis em `main`

Flask 1.1.2, Werkzeug 1.0.1, Jinja2 2.11.2, PyYAML 5.3.1, requests 2.25.1, urllib3 1.26.5, axios 0.21.1, lodash 4.17.15, moment 2.29.1, vite 4.2.0, entre outras.

## Como corrigir (branch `fix/sca`)

Atualizar para versões corrigidas e regenerar o lockfile (`npm install`, `pip-compile`/pin manual). Em produção, automatize com Dependabot ou Renovate.