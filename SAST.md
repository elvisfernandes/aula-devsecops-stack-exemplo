# SAST - Static Application Security Testing

SAST analisa o **código-fonte** sem executá-lo, procurando padrões inseguros. Roda cedo, é rápido e aponta arquivo e linha.
Limitações: gera falsos positivos e não enxerga problemas que só aparecem em execução ou na configuração do ambiente.

## Semgrep

**O que é:** motor de análise estática baseado em padrões de sintaxe (AST), multi-linguagem, open source (LGPL).

**Como funciona:**
1. Lê regras em YAML (do registry `p/python`, `p/flask`, `p/javascript`, `p/react`, `p/owasp-top-ten`... ou locais).
2. Faz parse do código em árvore sintática e procura trechos que casem com o padrão, ex.: `cursor.execute($X + ...)`.
3. Pode rastrear fluxo simples de dados (*taint mode*): de uma fonte (`request.args`) até um sink perigoso (`subprocess.run(shell=True)`).
4. Emite achados com severidade, regra (CWE/OWASP) e localização, em texto ou JSON/SARIF.

**Neste projeto:** além dos rulesets do registry, [semgrep/frontend.yml](semgrep/frontend.yml) traz regras próprias para `dangerouslySetInnerHTML`, `eval` e `innerHTML`, que os rulesets públicos não cobriam.
Comando local:
```
semgrep --config p/python --config p/flask --config semgrep/frontend.yml backend frontend/src
```

## Bandit

**O que é:** analisador SAST específico para Python, mantido pela PyCQA.

**Como funciona:** percorre a AST de cada arquivo `.py` e executa *plugins* de teste (ex.: B602 `subprocess` com `shell=True`, B324 hash fraco MD5, B201 Flask `debug=True`, B105 senha hardcoded). Cada achado tem severidade e confiança.
Neste projeto roda com `-ll` (apenas severidade média ou maior):
```
bandit -ll -r backend
```

## Semgrep x Bandit

| | Semgrep | Bandit |
|---|---|---|
| Linguagens | Muitas (Python, JS, Go...) | Só Python |
| Regras | Customizáveis em YAML | Plugins em Python |
| Uso aqui | Backend e frontend | Backend |

## Vulnerabilidades que cada um encontra em `main`

SQL injection, desserialização `yaml.load`, path traversal, MD5, SSTI, command injection, SSRF com `verify=False`, `debug=True`, XSS (`dangerouslySetInnerHTML`, `innerHTML`), `eval`.

## Como corrigir (branch `fix/sast`)

Queries parametrizadas, `yaml.safe_load`, validação de caminho, SHA-256, `render_template` sem entrada do usuário, `subprocess` sem shell e com lista de argumentos, allowlist para SSRF, remoção do `eval`/HTML cru e `debug` desligado.