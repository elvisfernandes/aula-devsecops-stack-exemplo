# Secret scanning

Detecta **credenciais versionadas por engano**: senhas, chaves de API, tokens. Um segredo no git está comprometido para sempre, pois fica no histórico mesmo depois de removido do código.

## Gitleaks

**O que é:** scanner open source que procura segredos em arquivos e no histórico git.

**Como funciona:**
1. Usa um conjunto de regras (regex por tipo de segredo: AWS, GitLab PAT, Stripe, chaves privadas...) e, em várias regras, checa a **entropia** da string para reduzir falsos positivos.
2. Por padrão percorre **todos os commits** (`git log -p`), não só o estado atual. Assim acha segredos já removidos.
3. Cada achado tem uma *fingerprint* (`commit:arquivo:regra:linha`).

```
gitleaks detect --source . --redact
```

## Rotação e baseline

O Gitleaks **não sabe** se um segredo foi rotacionado: ele só vê texto. O fluxo correto é:

1. Detectar o vazamento.
2. **Revogar/rotacionar** o segredo no provedor (a correção real).
3. Remover do código e passar a ler de variáveis de ambiente (`.env.example` documenta os nomes).
4. Registrar os achados históricos em `.gitleaks-baseline.json`, para o scanner ignorar apenas aquelas fingerprints já tratadas.
5. Marcar o finding como *Mitigated* no DefectDojo.

```
gitleaks detect --baseline-path .gitleaks-baseline.json
```
Qualquer segredo **novo** continua falhando o job. Reescrever o histórico (`git filter-repo`) é opcional e não substitui a rotação.

## Segredos plantados em `main`

Credenciais de banco e AWS em `backend/config.py`, token GitLab no `frontend/src/api.js`, `.env` versionado e uma chave Stripe em um arquivo depois removido (visível só no histórico).

## Boas práticas

Pre-commit hook com Gitleaks, `.env` no `.gitignore`, secrets do CI em variáveis mascaradas, e cofres (Vault, AWS Secrets Manager) em produção.