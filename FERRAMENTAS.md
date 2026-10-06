# Ferramentas do projeto

Visao geral das ferramentas usadas neste exemplo de DevSecOps e onde cada uma atua no pipeline (`.gitlab-ci.yml`).

| Categoria | Ferramenta | Documento | Estagio do pipeline |
|---|---|---|---|
| SAST | Semgrep, Bandit | [SAST.md](SAST.md) | `sast` |
| SCA | Trivy (fs), pip-audit, npm audit | [SCA.md](SCA.md) | `sca` |
| Secret scanning | Gitleaks | [SECRETS.md](SECRETS.md) | `secrets` |
| Imagem e IaC | Trivy (image), Hadolint, Checkov | [IMAGEM-IAC.md](IMAGEM-IAC.md) | `build`, `image-scan`, `iac` |
| Plataforma | GitLab CE, GitLab Runner, Docker-in-Docker, DefectDojo | [PLATAFORMA.md](PLATAFORMA.md) | `report` |

## Conceito: shift-left

Shift-left e levar a verificacao de seguranca para o inicio do ciclo de desenvolvimento (commit e merge request), onde corrigir e barato, em vez de descobrir problemas em producao. Cada ferramenta abaixo roda automaticamente no pipeline e, quando o job e *bloqueante*, impede o merge de codigo com problemas.

## O que cada tipo de analise enxerga

| Analise | Olha para | Exemplo de achado | Precisa executar a app? |
|---|---|---|---|
| SAST | Codigo-fonte proprio | SQL injection, `eval`, `shell=True` | Nao |
| SCA | Dependencias de terceiros | `axios 0.21.1` com CVE | Nao |
| Secrets | Codigo e historico git | Chave AWS, token GitLab | Nao |
| Image scanning | Imagem Docker pronta | CVE no pacote do SO da base | Nao |
| IaC / Dockerfile | Arquivos de infraestrutura | Container rodando como root | Nao |

Nenhuma delas substitui testes dinamicos (DAST) ou revisao humana; elas se complementam.

## Politica de bloqueio por branch

Em `main` todos os jobs de seguranca tem `allow_failure: true` (a pipeline mostra os problemas mas passa). Cada branch `fix/*` torna bloqueantes os jobs da categoria que corrige; em `fixed` todos bloqueiam.