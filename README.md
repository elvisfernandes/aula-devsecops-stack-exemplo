# DevSecOps na prÃ¡tica: cadastro de sapatos

AplicaÃ§Ã£o **propositalmente vulnerÃ¡vel** para demonstrar, em sala de aula, como
as ferramentas de seguranÃ§a no pipeline (shift-left) detectam e ajudam a corrigir
problemas ainda durante o desenvolvimento.

> **AtenÃ§Ã£o:** o cÃ³digo da branch `main` contÃ©m falhas de seguranÃ§a intencionais
> e segredos **falsos**. NÃ£o use em produÃ§Ã£o e nÃ£o exponha a aplicaÃ§Ã£o na internet.

## VisÃ£o geral

| Componente | Tecnologia |
|------------|------------|
| Backend    | Python 3 + Flask + psycopg2 |
| Frontend   | React + Vite (servido por nginx) |
| Banco      | PostgreSQL |
| CI/CD      | GitLab CE + GitLab Runner (executor Docker com dind) |
| GestÃ£o de vulnerabilidades | DefectDojo |

A aplicaÃ§Ã£o Ã© um CRUD de sapatos (id, marca, modelo, tamanho, cor, preÃ§o), sem
autenticaÃ§Ã£o e sem armazenamento de imagens.

```
backend/                Flask + psycopg2
frontend/               React + Vite
semgrep/                regras Semgrep customizadas (frontend)
docker-compose.yml      aplicaÃ§Ã£o (db + backend + frontend)
.gitlab-ci.yml          pipeline de seguranÃ§a
infra/gitlab/           GitLab CE + Runner
infra/defectdojo/       script que sobe o DefectDojo oficial
infra/scripts/          bootstrap do GitLab e upload para o DefectDojo
```

## Executando a aplicaÃ§Ã£o

```bash
cp .env.example .env   # preencha POSTGRES_PASSWORD com um valor novo (rotacionado)
docker compose up -d --build
```

- Frontend: <http://localhost:3000>
- API: <http://localhost:5000/api/shoes>

Para desenvolvimento do frontend: `cd frontend && npm install && npm run dev`
(o Vite faz proxy de `/api` para `localhost:5000`).

## Subindo a infraestrutura de demonstraÃ§Ã£o

Requisitos: Docker, Docker Compose e Bash (Linux, WSL ou Git Bash).
O GitLab sozinho consome cerca de 4 GB de RAM; GitLab + DefectDojo pedem de
8 a 12 GB. Para a aula, o ideal Ã© rodar em uma VM. Os mesmos arquivos funcionam
na VM: basta ajustar `GITLAB_HOST` em `infra/.env`.

1. **GitLab + Runner + projeto + push de todos os branches**

   ```bash
   ./infra/scripts/bootstrap-gitlab.sh
   ```

   O script cria `infra/.env` a partir de `infra/.env.example` (ajuste a senha
   do root antes, se quiser), sobe o GitLab, cria um token, cria o projeto,
   registra o runner e envia os branches. Acesso: `http://localhost:8929`,
   usuÃ¡rio `root`.

2. **DefectDojo** (pode ser deixado para o final da demonstraÃ§Ã£o)

   ```bash
   ./infra/defectdojo/setup.sh
   ```

   Acesse `http://localhost:8080` (usuÃ¡rio `admin`; a senha inicial aparece nos
   logs do `initializer`). Gere o token em *usuÃ¡rio > API v2 Key*, preencha
   `DD_TOKEN` em `infra/.env` e execute o bootstrap novamente (ele sÃ³ atualiza
   as variÃ¡veis de CI do projeto). Sem `DD_TOKEN`, o job `defectdojo` nÃ£o roda.

## Pipeline (`.gitlab-ci.yml`)

| EstÃ¡gio | Job | Ferramenta | Detecta |
|---------|-----|------------|---------|
| sast | `semgrep`, `bandit` | Semgrep, Bandit | SQL injection, XSS, `eval`, `shell=True`, SSRF, path traversal, hash fraco, debug ligado... |
| sca | `trivy-fs`, `pip-audit`, `npm-audit` | Trivy, pip-audit, npm audit | DependÃªncias Python e npm com CVEs |
| secrets | `gitleaks` | Gitleaks | Segredos no cÃ³digo **e no histÃ³rico git** |
| build | `build-images` | Docker (dind) | ConstrÃ³i as imagens |
| image-scan | `trivy-image-*` | Trivy | CVEs do SO/pacotes e segredos nas camadas da imagem |
| iac | `hadolint`, `checkov` | Hadolint, Checkov | MÃ¡s prÃ¡ticas nos Dockerfiles |
| report | `defectdojo` | API do DefectDojo | Importa todos os relatÃ³rios (`reimport-scan`) |

Cada branch vira um *engagement* no DefectDojo e cada ferramenta um *test*,
o que permite comparar a evoluÃ§Ã£o entre os branches.

### Jobs bloqueantes

Na `main` todos os jobs usam `allow_failure: true` (o pipeline termina em
"passed with warnings"). A cada branch de correÃ§Ã£o, os jobs da categoria
corrigida **perdem** o `allow_failure` e passam a bloquear o pipeline: o merge
sÃ³ Ã© possÃ­vel se a categoria estiver limpa. Esse Ã© o ponto central do shift-left.

## Roteiro da demonstraÃ§Ã£o

Os branches sÃ£o incrementais:

```
main -> fix/sast -> fix/sca -> fix/secrets -> fix/image -> fixed
```

| Branch | O que corrige | Como demonstrar |
|--------|---------------|-----------------|
| `main` | nada (aplicaÃ§Ã£o vulnerÃ¡vel) | Rode o pipeline, mostre os relatÃ³rios e explore a app (ex.: `?q=%' OR 1=1 --`, `/api/tools/ping?host=localhost;id`) |
| `fix/sast` | Queries parametrizadas, `yaml.safe_load`, `shell=True` removido, SHA-256, path traversal, SSRF, SSTI, `debug` e CORS, XSS/`eval` no React | `git diff main..fix/sast`; jobs `semgrep` e `bandit` passam |
| `fix/sca` | DependÃªncias atualizadas (`requirements.txt`, `package.json` e lockfile) | Jobs `trivy-fs`, `pip-audit` e `npm-audit` passam |
| `fix/secrets` | Segredos movidos para variÃ¡veis de ambiente, `.env` removido do git, `.env.example`, baseline do Gitleaks | Veja a seÃ§Ã£o abaixo |
| `fix/image` | Imagens base atuais, multi-stage, usuÃ¡rio nÃ£o-root, `COPY`, `HEALTHCHECK`, gunicorn | Jobs `trivy-image-*`, `hadolint` e `checkov` passam |
| `fixed` | Hardening extra: validaÃ§Ã£o de entrada, headers de seguranÃ§a, limites de recursos, containers `read_only`, banco isolado | VersÃ£o final de referÃªncia |

### Sobre segredos e rotaÃ§Ã£o

O Gitleaks **nÃ£o sabe** se um segredo foi rotacionado: ele sÃ³ faz correspondÃªncia
de padrÃµes em arquivos e commits, e nÃ£o consulta o provedor da credencial.
Remover o segredo do cÃ³digo nÃ£o basta, pois ele continua no histÃ³rico do git.
O fluxo correto Ã©:

1. Detectar o vazamento (Gitleaks no histÃ³rico completo).
2. **Rotacionar** a credencial no provedor (fora do git): trocar a senha do
   Postgres e revogar/recriar as chaves de API. Neste projeto os segredos sÃ£o
   falsos, entÃ£o basta gerar novos valores e colocÃ¡-los em `.env`.
3. Remover o segredo do cÃ³digo e passar a ler de variÃ¡veis de ambiente.
4. Registrar que o vazamento histÃ³rico jÃ¡ foi tratado em `.gitleaks-baseline.json`
   (`--baseline-path`). Novos segredos continuam derrubando o pipeline.
5. No DefectDojo, marcar o achado como *Mitigated*/*Risk Accepted* com a
   justificativa "segredo rotacionado em `<data>`".

O histÃ³rico propositalmente contÃ©m um commit que adiciona e outro que remove
`backend/legacy_settings.py`, para mostrar que o segredo "apagado" continua
acessÃ­vel no git. Reescrever o histÃ³rico (`git filter-repo`) seria a alternativa.

Para verificar se um segredo ainda estÃ¡ **ativo**, existe o TruffleHog
(`--only-verified`), que testa credenciais reais de provedores conhecidos.
Ele nÃ£o se aplica aos segredos falsos deste projeto.

## Executando os scanners localmente

```bash
docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:latest detect --source /repo
docker run --rm -v "$PWD:/src" -w /src aquasec/trivy:latest fs --scanners vuln .
docker run --rm -v "$PWD:/src" -w /src semgrep/semgrep semgrep scan --config p/python --config semgrep/frontend.yml backend frontend/src
```

## Notas

- Os jobs dos scanners baixam bancos de regras/CVEs da internet.
- Os tokens e segredos presentes neste repositÃ³rio sÃ£o fictÃ­cios.
- Dentro do runner, o DefectDojo Ã© acessado por `http://defectdojo:8080` (o
  script `setup.sh` conecta o DefectDojo Ã  rede Docker `devsecops`).
