# Plataforma: GitLab, Runner, DinD e DefectDojo

## GitLab CE

**O que e:** plataforma de DevOps (git, merge requests, CI/CD) em versao Community, open source. Aqui roda em container (`infra/gitlab/docker-compose.yml`).
**Papel:** hospeda o repositorio e, a cada push, le o [.gitlab-ci.yml](.gitlab-ci.yml) e cria uma *pipeline* com estagios (`sast`, `sca`, `secrets`, `build`, `image-scan`, `iac`, `report`). Jobs de um mesmo estagio rodam em paralelo; um job que falha sem `allow_failure` bloqueia o merge.

## GitLab Runner

**O que e:** agente que executa os jobs. Registra-se no GitLab, busca jobs pendentes e roda cada um em um container descrito pela chave `image:` do job.
**Neste projeto:** executor `docker`, em modo privilegiado e na rede `devsecops` (para alcancar `gitlab` e `defectdojo` pelo nome).

## Docker-in-Docker (dind)

**Problema:** o job de build precisa executar `docker build`, mas o job ja roda dentro de um container.
**Solucao:** o job `build-images` usa a imagem `docker:27` e o servico `docker:27-dind`, um daemon Docker rodando como container auxiliar. O build acontece nele e a imagem e salva como `.tar` artefato para o Trivy ler (`--input`).
**Atencao:** exige `privileged`, o que e um risco em runners compartilhados; aceitavel em uma demo local.

## DefectDojo

**O que e:** plataforma open source de gestao de vulnerabilidades (ASPM). Centraliza resultados de varias ferramentas em um so lugar.

**Como funciona:**
- Modelo: *Product* -> *Engagement* -> *Test* -> *Findings*.
- Recebe relatorios (SARIF, JSON do Trivy, Gitleaks, Bandit, Semgrep, npm audit...) pela API (`/api/v2/reimport-scan/`) e os **normaliza**.
- **Deduplica** achados repetidos entre execucoes e acompanha o ciclo de vida (Active, Mitigated, False Positive, Risk Accepted).
- Oferece metricas, SLAs e integracao com Jira.

**Neste projeto:** o job `defectdojo` (sempre executado, quando `DD_URL` e `DD_TOKEN` existem) chama [infra/scripts/upload-defectdojo.sh](infra/scripts/upload-defectdojo.sh), que envia cada relatorio com `reimport-scan` e `auto_create_context`. O engagement recebe o nome do branch e cada teste, o da ferramenta; assim da para comparar `main` com os `fix/*` e ver os findings passarem para Mitigated.

## Fluxo completo

```
commit -> GitLab -> Runner -> [Semgrep, Bandit | Trivy fs, pip-audit, npm audit | Gitleaks
          | build (dind) -> Trivy image, Hadolint, Checkov] -> relatorios -> DefectDojo
```