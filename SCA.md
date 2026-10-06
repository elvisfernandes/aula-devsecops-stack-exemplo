# SCA - Software Composition Analysis

SCA inventaria as **dependencias de terceiros** (diretas e transitivas) e cruza as versoes com bases de vulnerabilidades conhecidas (CVE, GHSA, OSV). A maior parte do codigo de uma aplicacao moderna vem de bibliotecas, entao e uma superficie de ataque grande.
Limitacao: so conhece vulnerabilidades *publicadas*; nao diz se o codigo vulneravel da biblioteca e realmente alcancado pela aplicacao.

## Como funciona (comum as ferramentas)

1. Le manifestos e lockfiles (`requirements.txt`, `package-lock.json`).
2. Monta a lista de pacotes e versoes exatas.
3. Consulta uma base de advisories e reporta os pacotes afetados, a severidade e a **versao corrigida**.

Por isso o *lockfile* importa: sem versoes fixadas o resultado nao e reprodutivel.

## Trivy (modo `fs`)

**O que e:** scanner open source da Aqua Security para vulnerabilidades, segredos e misconfiguracoes.
**Como funciona no modo fs:** varre o diretorio, detecta lockfiles e compara com seu banco de vulnerabilidades (baixado e atualizado automaticamente).
```
trivy fs --severity HIGH,CRITICAL .
```

## pip-audit

**O que e:** ferramenta da PyPA para auditar dependencias Python.
**Como funciona:** resolve as versoes de `requirements.txt` e consulta o PyPI/OSV Advisory Database.
```
pip-audit -r backend/requirements.txt
```

## npm audit

**O que e:** auditoria embutida no npm.
**Como funciona:** envia a arvore de dependencias do `package-lock.json` ao registry, que responde com os advisories aplicaveis.
```
cd frontend && npm audit --audit-level=high
```

## Dependencias vulneraveis em `main`

Flask 1.1.2, Werkzeug 1.0.1, Jinja2 2.11.2, PyYAML 5.3.1, requests 2.25.1, urllib3 1.26.5, axios 0.21.1, lodash 4.17.15, moment 2.29.1, vite 4.2.0, entre outras.

## Como corrigir (branch `fix/sca`)

Atualizar para versoes corrigidas e regenerar o lockfile (`npm install`, `pip-compile`/pin manual). Em producao, automatize com Dependabot ou Renovate.