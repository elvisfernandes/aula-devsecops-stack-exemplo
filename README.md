# DevSecOps na prática: cadastro de sapatos

Aplicação **propositalmente vulnerável** para demonstrar, em sala de aula, como
as ferramentas de segurança no pipeline (shift-left) detectam e ajudam a corrigir
problemas ainda durante o desenvolvimento.

> **Atenção:** o código da branch `main` contém falhas de segurança intencionais
> e segredos **falsos**. Não use em produção e não exponha a aplicação na internet.

## Visão geral

| Componente | Tecnologia |
|------------|------------|
| Backend    | Python 3 + Flask + psycopg2 |
| Frontend   | React + Vite (servido por nginx) |
| Banco      | PostgreSQL |
| CI/CD      | GitLab CE + GitLab Runner (executor Docker com dind) |
| Gestão de vulnerabilidades | DefectDojo |

A aplicação é um CRUD de sapatos (id, marca, modelo, tamanho, cor, preço), sem
autenticação e sem armazenamento de imagens.

```
backend/                Flask + psycopg2
frontend/               React + Vite
semgrep/                regras Semgrep customizadas (frontend)
docker-compose.yml      aplicação (db + backend + frontend)
.gitlab-ci.yml          pipeline de segurança
infra/gitlab/           GitLab CE + Runner
infra/defectdojo/       script que sobe o DefectDojo oficial
infra/scripts/          bootstrap do GitLab e upload para o DefectDojo
```

## Executando a aplicação

```bash
cp .env.example .env   # preencha POSTGRES_PASSWORD com um valor novo (rotacionado)
docker compose up -d --build
```

- Frontend: <http://localhost:3000>
- API: <http://localhost:5000/api/shoes>

Para desenvolvimento do frontend: `cd frontend && npm install && npm run dev`
(o Vite faz proxy de `/api` para `localhost:5000`).

## Subindo a infraestrutura de demonstração

Requisitos: Docker, Docker Compose e Bash (Linux, WSL ou Git Bash).
O GitLab sozinho consome cerca de 4 GB de RAM; GitLab + DefectDojo pedem de
8 a 12 GB. Para a aula, o ideal é rodar em uma VM. Os mesmos arquivos funcionam
na VM: basta ajustar `GITLAB_HOST` em `infra/.env`.

1. **GitLab + Runner + projeto + push de todos os branches**

   ```bash
   ./infra/scripts/bootstrap-gitlab.sh
   ```

   O script cria `infra/.env` a partir de `infra/.env.example` (ajuste a senha
   do root antes, se quiser), sobe o GitLab, cria um token, cria o projeto,
   registra o runner e envia os branches. Acesso: `http://localhost:8929`,
   usuário `root`.

2. **DefectDojo** (pode ser deixado para o final da demonstração)

   ```bash
   ./infra/defectdojo/setup.sh
   ```

   Acesse `http://localhost:8080` (usuário `admin`; a senha inicial aparece nos
   logs do `initializer`). Gere o token em *usuário > API v2 Key*, preencha
   `DD_TOKEN` em `infra/.env` e execute o bootstrap novamente (ele só atualiza
   as variáveis de CI do projeto). Sem `DD_TOKEN`, o job `defectdojo` não roda.

## Documentação das ferramentas

Cada ferramenta usada no exemplo é explicada (o que é e como funciona) nos arquivos abaixo:

- [FERRAMENTAS.md](FERRAMENTAS.md): visão geral, conceito de shift-left e política de bloqueio por branch
- [SAST.md](SAST.md): Semgrep e Bandit
- [SCA.md](SCA.md): Trivy (fs), pip-audit e npm audit
- [SECRETS.md](SECRETS.md): Gitleaks, rotação e baseline
- [IMAGEM-IAC.md](IMAGEM-IAC.md): Trivy (image), Hadolint e Checkov
- [PLATAFORMA.md](PLATAFORMA.md): GitLab CE, Runner, Docker-in-Docker e DefectDojo

## Pipeline (`.gitlab-ci.yml`)

| Estágio | Job | Ferramenta | Detecta |
|---------|-----|------------|---------|
| sast | `semgrep`, `bandit` | Semgrep, Bandit | SQL injection, XSS, `eval`, `shell=True`, SSRF, path traversal, hash fraco, debug ligado... |
| sca | `trivy-fs`, `pip-audit`, `npm-audit` | Trivy, pip-audit, npm audit | Dependências Python e npm com CVEs |
| secrets | `gitleaks` | Gitleaks | Segredos no código **e no histórico git** |
| build | `build-images` | Docker (dind) | Constrói as imagens |
| image-scan | `trivy-image-*` | Trivy | CVEs do SO/pacotes e segredos nas camadas da imagem |
| iac | `hadolint`, `checkov` | Hadolint, Checkov | Más práticas nos Dockerfiles |
| report | `defectdojo` | API do DefectDojo | Importa todos os relatórios (`reimport-scan`) |

Cada branch vira um *engagement* no DefectDojo e cada ferramenta um *test*,
o que permite comparar a evolução entre os branches.

### Jobs bloqueantes

Na `main` todos os jobs usam `allow_failure: true` (o pipeline termina em
"passed with warnings"). A cada branch de correção, os jobs da categoria
corrigida **perdem** o `allow_failure` e passam a bloquear o pipeline: o merge
só é possível se a categoria estiver limpa. Esse é o ponto central do shift-left.

## Roteiro da demonstração

Os branches são incrementais:

```
main -> fix/sast -> fix/sca -> fix/secrets -> fix/image -> fixed
```

| Branch | O que corrige | Como demonstrar |
|--------|---------------|-----------------|
| `main` | nada (aplicação vulnerável) | Rode o pipeline, mostre os relatórios e explore a app (ex.: `?q=%' OR 1=1 --`, `/api/tools/ping?host=localhost;id`) |
| `fix/sast` | Queries parametrizadas, `yaml.safe_load`, `shell=True` removido, SHA-256, path traversal, SSRF, SSTI, `debug` e CORS, XSS/`eval` no React | `git diff main..fix/sast`; jobs `semgrep` e `bandit` passam |
| `fix/sca` | Dependências atualizadas (`requirements.txt`, `package.json` e lockfile) | Jobs `trivy-fs`, `pip-audit` e `npm-audit` passam |
| `fix/secrets` | Segredos movidos para variáveis de ambiente, `.env` removido do git, `.env.example`, baseline do Gitleaks | Veja a seção abaixo |
| `fix/image` | Imagens base atuais, multi-stage, usuário não-root, `COPY`, `HEALTHCHECK`, gunicorn | Jobs `trivy-image-*`, `hadolint` e `checkov` passam |
| `fixed` | Hardening extra: validação de entrada, headers de segurança, limites de recursos, containers `read_only`, banco isolado | Versão final de referência |

### Sobre segredos e rotação

O Gitleaks **não sabe** se um segredo foi rotacionado: ele só faz correspondência
de padrões em arquivos e commits, e não consulta o provedor da credencial.
Remover o segredo do código não basta, pois ele continua no histórico do git.
O fluxo correto é:

1. Detectar o vazamento (Gitleaks no histórico completo).
2. **Rotacionar** a credencial no provedor (fora do git): trocar a senha do
   Postgres e revogar/recriar as chaves de API. Neste projeto os segredos são
   falsos, então basta gerar novos valores e colocá-los em `.env`.
3. Remover o segredo do código e passar a ler de variáveis de ambiente.
4. Registrar que o vazamento histórico já foi tratado em `.gitleaks-baseline.json`
   (`--baseline-path`). Novos segredos continuam derrubando o pipeline.
5. No DefectDojo, marcar o achado como *Mitigated*/*Risk Accepted* com a
   justificativa "segredo rotacionado em `<data>`".

O histórico propositalmente contém um commit que adiciona e outro que remove
`backend/legacy_settings.py`, para mostrar que o segredo "apagado" continua
acessível no git. Reescrever o histórico (`git filter-repo`) seria a alternativa.

Para verificar se um segredo ainda está **ativo**, existe o TruffleHog
(`--only-verified`), que testa credenciais reais de provedores conhecidos.
Ele não se aplica aos segredos falsos deste projeto.

## Executando os scanners localmente

```bash
docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:latest detect --source /repo
docker run --rm -v "$PWD:/src" -w /src aquasec/trivy:latest fs --scanners vuln .
docker run --rm -v "$PWD:/src" -w /src semgrep/semgrep semgrep scan --config p/python --config semgrep/frontend.yml backend frontend/src
```

## Notas

- Os jobs dos scanners baixam bancos de regras/CVEs da internet.
- Os tokens e segredos presentes neste repositório são fictícios.
- Dentro do runner, o DefectDojo é acessado por `http://defectdojo:8080` (o
  script `setup.sh` conecta o DefectDojo à rede Docker `devsecops`).
