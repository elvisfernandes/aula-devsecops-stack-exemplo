# DAST: OWASP ZAP

DAST (*Dynamic Application Security Testing*) testa a aplicação **em execução**, como um atacante externo: envia requisições, observa as respostas e procura comportamentos inseguros. Não precisa do código-fonte, e por isso encontra problemas que a análise estática não vê (configuração de servidor, headers, comportamento real de injeções).

## Ferramenta: OWASP ZAP

[ZAP](https://www.zaproxy.org/) é um scanner DAST de código aberto. O pipeline usa dois scripts da imagem `ghcr.io/zaproxy/zaproxy:stable`:

| Script | Tipo | O que faz |
|--------|------|-----------|
| `zap-baseline.py` | Passivo | Navega pelo frontend (spider) e analisa as respostas: headers de segurança ausentes, vazamento de versão, cookies, CSP |
| `zap-api-scan.py` | Ativo | Lê [dast/openapi.yaml](dast/openapi.yaml), descobre os endpoints da API e envia payloads de ataque (SQL injection, injeção de comandos, SSTI, path traversal, SSRF) |

O scan ativo **ataca de verdade** a aplicação. Por isso ele roda apenas contra um ambiente descartável, criado pelo próprio job, nunca contra produção.

## Como funciona no pipeline

O job `zap-dast` (estágio `dast`) executa [infra/scripts/dast.sh](infra/scripts/dast.sh):

1. Carrega as imagens geradas pelo job `build-images` (`needs`), de modo que o DAST testa o **mesmo artefato** que passou pelo image scanning.
2. Sobe o stack com `docker compose` dentro do Docker-in-Docker.
3. Espera `http://localhost:3000/api/shoes` responder.
4. Executa o `zap-baseline.py` e o `zap-api-scan.py`, gerando `reports/zap-baseline.json` e `reports/zap-api.json`.
5. Derruba o stack e falha o job se houver alerta de risco **alto** nos relatórios.

Os relatórios são enviados ao DefectDojo (parser "ZAP Scan") pelo job `defectdojo`.

## Por que o job não é bloqueante

O DAST gera mais falsos positivos que as demais ferramentas, pois infere vulnerabilidades pelo comportamento das respostas. Um alerta de SQL injection, por exemplo, pode vir de uma heurística booleana que não corresponde a uma falha real. Por isso o `zap-dast` usa `allow_failure: true` em todos os branches: o resultado precisa de triagem humana antes de virar um bloqueio.

## O que esperar em cada branch

- **`main`:** alertas de risco alto e médio: SQL injection, injeção de comandos, SSTI, inclusão remota de arquivo, além de headers ausentes e vazamento de versão do servidor.
- **`fixed`:** bem menos alertas. Restam, principalmente, avisos de headers opcionais (`Permissions-Policy`, COEP), respostas 500 do endpoint `/api/catalog` (o catálogo externo é fictício) e eventuais falsos positivos.

## Atenção

- O DAST **complementa** SAST e SCA, não os substitui: ele só testa o que o scan alcança (endpoints descritos no OpenAPI e links encontrados pelo spider).
- Mantenha o [dast/openapi.yaml](dast/openapi.yaml) atualizado quando a API mudar.
- O scan ativo cria registros no banco de teste. Isso é esperado, pois o ambiente é descartado ao final.
- Para executar localmente: `sh infra/scripts/dast.sh` (requer Docker).
