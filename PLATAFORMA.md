# Plataforma: GitLab, Runner, DinD e DefectDojo

## GitLab CE

**O que é:** plataforma de DevOps (git, merge requests, CI/CD) em versão Community, open source. Aqui roda em container (`infra/gitlab/docker-compose.yml`).
**Papel:** hospeda o repositório e, a cada push, lê o [.gitlab-ci.yml](.gitlab-ci.yml) e cria uma *pipeline* com estágios (`sast`, `sca`, `secrets`, `build`, `image-scan`, `iac`, `report`). Jobs de um mesmo estágio rodam em paralelo; um job que falha sem `allow_failure` bloqueia o merge.

## GitLab Runner

**O que é:** agente que executa os jobs. Registra-se no GitLab, busca jobs pendentes e roda cada um em um container descrito pela chave `image:` do job.
**Neste projeto:** executor `docker`, em modo privilegiado e na rede `devsecops` (para alcançar `gitlab` e `defectdojo` pelo nome).

## Docker-in-Docker (dind)

**Problema:** o job de build precisa executar `docker build`, mas o job já roda dentro de um container.
**Solução:** o job `build-images` usa a imagem `docker:27` e o serviço `docker:27-dind`, um daemon Docker rodando como container auxiliar. O build acontece nele e a imagem é salva como artefato `.tar` para o Trivy ler (`--input`).
**Atenção:** exige `privileged`, o que é um risco em runners compartilhados; aceitável em uma demo local.

## DefectDojo

**O que é:** plataforma open source de gestão de vulnerabilidades (ASPM). Centraliza resultados de várias ferramentas em um só lugar.

**Como funciona:**
- Modelo: *Product* -> *Engagement* -> *Test* -> *Findings*.
- Recebe relatórios (SARIF, JSON do Trivy, Gitleaks, Bandit, Semgrep, npm audit...) pela API (`/api/v2/reimport-scan/`) e os **normaliza**.
- **Deduplica** achados repetidos entre execuções e acompanha o ciclo de vida (Active, Mitigated, False Positive, Risk Accepted).
- Oferece métricas, SLAs e integração com Jira.

**Neste projeto:** o job `defectdojo` (sempre executado, quando `DD_URL` e `DD_TOKEN` existem) chama [infra/scripts/upload-defectdojo.sh](infra/scripts/upload-defectdojo.sh), que envia cada relatório com `reimport-scan` e `auto_create_context`. O engagement recebe o nome do branch e cada teste, o da ferramenta; assim dá para comparar `main` com os `fix/*` e ver os findings passarem para Mitigated.

## Fluxo completo

```
commit -> GitLab -> Runner -> [Semgrep, Bandit | Trivy fs, pip-audit, npm audit | Gitleaks
          | build (dind) -> Trivy image, Hadolint, Checkov] -> relatórios -> DefectDojo
```