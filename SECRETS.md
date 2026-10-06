# Secret scanning

Detecta **credenciais versionadas por engano**: senhas, chaves de API, tokens. Um segredo no git e comprometido para sempre, pois fica no historico mesmo depois de removido do codigo.

## Gitleaks

**O que e:** scanner open source que procura segredos em arquivos e no historico git.

**Como funciona:**
1. Usa um conjunto de regras (regex por tipo de segredo: AWS, GitLab PAT, Stripe, chaves privadas...) e, em varias regras, checa a **entropia** da string para reduzir falsos positivos.
2. Por padrao percorre **todos os commits** (`git log -p`), nao so o estado atual. Assim acha segredos ja removidos.
3. Cada achado tem uma *fingerprint* (`commit:arquivo:regra:linha`).

```
gitleaks detect --source . --redact
```

## Rotacao e baseline

O Gitleaks **nao sabe** se um segredo foi rotacionado: ele so ve texto. O fluxo correto e:

1. Detectar o vazamento.
2. **Revogar/rotacionar** o segredo no provedor (a correcao real).
3. Remover do codigo e passar a ler de variaveis de ambiente (`.env.example` documenta os nomes).
4. Registrar os achados historicos em `.gitleaks-baseline.json`, para o scanner ignorar apenas aquelas fingerprints ja tratadas.
5. Marcar o finding como *Mitigated* no DefectDojo.

```
gitleaks detect --baseline-path .gitleaks-baseline.json
```
Qualquer segredo **novo** continua falhando o job. Reescrever o historico (`git filter-repo`) e opcional e nao substitui a rotacao.

## Segredos plantados em `main`

Credenciais de banco e AWS em `backend/config.py`, token GitLab no `frontend/src/api.js`, `.env` versionado e uma chave Stripe em um arquivo depois removido (visivel so no historico).

## Boas praticas

Pre-commit hook com Gitleaks, `.env` no `.gitignore`, secrets do CI em variaveis mascaradas, e cofres (Vault, AWS Secrets Manager) em producao.