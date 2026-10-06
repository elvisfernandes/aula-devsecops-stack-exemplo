# Ferramentas do projeto

Para o panorama do processo (o que proteger em cada etapa), veja [DEVSECOPS.md](DEVSECOPS.md).

Visão geral das ferramentas usadas neste exemplo de DevSecOps e onde cada uma atua no pipeline (`.gitlab-ci.yml`).

| Categoria | Ferramenta | Documento | Estágio do pipeline |
|---|---|---|---|
| SAST | Semgrep, Bandit | [SAST.md](SAST.md) | `sast` |
| SCA | Trivy (fs), pip-audit, npm audit | [SCA.md](SCA.md) | `sca` |
| Secret scanning | Gitleaks | [SECRETS.md](SECRETS.md) | `secrets` |
| Imagem e IaC | Trivy (image), Hadolint, Checkov | [IMAGEM-IAC.md](IMAGEM-IAC.md) | `build`, `image-scan`, `iac` |
| DAST | OWASP ZAP | [DAST.md](DAST.md) | `dast` |
| Plataforma | GitLab CE, GitLab Runner, Docker-in-Docker, DefectDojo | [PLATAFORMA.md](PLATAFORMA.md) | `report` |

## Conceito: shift-left

Shift-left é levar a verificação de segurança para o início do ciclo de desenvolvimento (commit e merge request), onde corrigir é barato, em vez de descobrir problemas em produção. Cada ferramenta abaixo roda automaticamente no pipeline e, quando o job é *bloqueante*, impede o merge de código com problemas.

## O que cada tipo de análise enxerga

| Análise | Olha para | Exemplo de achado | Precisa executar a app? |
|---|---|---|---|
| SAST | Código-fonte próprio | SQL injection, `eval`, `shell=True` | Não |
| SCA | Dependências de terceiros | `axios 0.21.1` com CVE | Não |
| Secrets | Código e histórico git | Chave AWS, token GitLab | Não |
| Image scanning | Imagem Docker pronta | CVE no pacote do SO da base | Não |
| IaC / Dockerfile | Arquivos de infraestrutura | Container rodando como root | Não |

Nenhuma delas substitui testes dinâmicos (DAST) ou revisão humana; elas se complementam.

## Política de bloqueio por branch

A `main` não tem nenhum job de segurança: só `build-images` e `publish-images`. No branch `scans` todos os jobs de segurança têm `allow_failure: true` (a pipeline mostra os problemas, mas passa). Cada branch `fix/*` torna bloqueantes os jobs da categoria que corrige; em `fixed` todos bloqueiam.