# SAST - Static Application Security Testing

SAST analisa o **codigo-fonte** sem executa-lo, procurando padroes inseguros. Roda cedo, e rapido e aponta arquivo e linha.
Limitacoes: gera falsos positivos e nao enxerga problemas que so aparecem em execucao ou na configuracao do ambiente.

## Semgrep

**O que e:** motor de analise estatica baseado em padroes de sintaxe (AST), multi-linguagem, open source (LGPL).

**Como funciona:**
1. Le regras em YAML (do registry `p/python`, `p/flask`, `p/javascript`, `p/react`, `p/owasp-top-ten`... ou locais).
2. Faz parse do codigo em arvore sintatica e procura trechos que casem com o padrao, ex.: `cursor.execute($X + ...)`.
3. Pode rastrear fluxo simples de dados (*taint mode*): de uma fonte (`request.args`) ate um sink perigoso (`subprocess.run(shell=True)`).
4. Emite achados com severidade, regra (CWE/OWASP) e localizacao, em texto ou JSON/SARIF.

**Neste projeto:** alem dos rulesets do registry, [semgrep/frontend.yml](semgrep/frontend.yml) traz regras proprias para `dangerouslySetInnerHTML`, `eval` e `innerHTML`, que os rulesets publicos nao cobriam.
Comando local:
```
semgrep --config p/python --config p/flask --config semgrep/frontend.yml backend frontend/src
```

## Bandit

**O que e:** analisador SAST especifico para Python, mantido pela PyCQA.

**Como funciona:** percorre a AST de cada arquivo `.py` e executa *plugins* de teste (ex.: B602 `subprocess` com `shell=True`, B324 hash fraco MD5, B201 Flask `debug=True`, B105 senha hardcoded). Cada achado tem severidade e confianca.
Neste projeto roda com `-ll` (apenas severidade media ou maior):
```
bandit -ll -r backend
```

## Semgrep x Bandit

| | Semgrep | Bandit |
|---|---|---|
| Linguagens | Muitas (Python, JS, Go...) | So Python |
| Regras | Customizaveis em YAML | Plugins em Python |
| Uso aqui | Backend e frontend | Backend |

## Vulnerabilidades que cada um encontra em `main`

SQL injection, desserializacao `yaml.load`, path traversal, MD5, SSTI, command injection, SSRF com `verify=False`, `debug=True`, XSS (`dangerouslySetInnerHTML`, `innerHTML`), `eval`.

## Como corrigir (branch `fix/sast`)

Queries parametrizadas, `yaml.safe_load`, validacao de caminho, SHA-256, `render_template` sem entrada do usuario, `subprocess` sem shell e com lista de argumentos, allowlist para SSRF, remocao do `eval`/HTML cru e `debug` desligado.