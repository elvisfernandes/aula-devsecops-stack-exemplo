# Image scanning e IaC / Dockerfile

## Trivy (modo `image`)

**O que é:** o mesmo scanner do [SCA.md](SCA.md), aplicado a uma imagem de container.

**Como funciona:**
1. A imagem é exportada (`docker save`) e suas camadas são lidas.
2. Identifica o SO (Debian, Alpine) e os pacotes instalados (`dpkg`, `apk`) e também pacotes Python/Node dentro da imagem.
3. Compara com as bases de vulnerabilidades (CVEs de distribuição e de linguagem).
4. Com `--scanners secret` também procura segredos esquecidos nas camadas, como `ENV` com senha.

Neste projeto: `--severity HIGH,CRITICAL --ignore-unfixed`, ou seja, só falha para o que tem correção disponível.
```
trivy image --severity HIGH,CRITICAL --ignore-unfixed --scanners vuln,secret IMAGEM
```
Correção: base atual e enxuta (`python:3.12-slim`, `alpine`), `apt-get upgrade` / `apk upgrade` no build e rebuild frequente.

## Hadolint

**O que é:** linter de Dockerfile.

**Como funciona:** faz parse do Dockerfile e aplica regras `DLxxxx` (boas práticas) e, internamente, ShellCheck nos comandos `RUN`. Exemplos: DL3020 (use `COPY` em vez de `ADD`), DL3042 (`pip --no-cache-dir`), DL3064 (segredos em `ENV`), DL3025 (CMD em formato JSON).
```
hadolint --failure-threshold warning Dockerfile
```

## Checkov

**O que é:** scanner de IaC (Terraform, Kubernetes, Dockerfile, CloudFormation...) da Prisma Cloud/Bridgecrew.

**Como funciona:** converte o arquivo em uma estrutura/grafo e avalia políticas `CKV_*`. Em Dockerfiles verifica, por exemplo: CKV_DOCKER_2 (falta `HEALTHCHECK`), CKV_DOCKER_3 (falta usuário não-root), CKV_DOCKER_1 (porta 22 exposta).
```
checkov --framework dockerfile -d .
```

## Diferença entre eles

| Ferramenta | Pergunta que responde |
|---|---|
| Trivy image | A imagem final contém pacotes vulneráveis ou segredos? |
| Hadolint | O Dockerfile segue boas práticas de build? |
| Checkov | A configuração atende políticas de segurança (usuário, healthcheck, portas)? |

## Em `fix/image` e `fixed`

Multi-stage build, usuário não-root, `HEALTHCHECK`, `nginx-unprivileged` na porta 8080, gunicorn em vez do servidor de desenvolvimento. Em `fixed`, o compose ainda usa `read_only`, `cap_drop: ALL`, `no-new-privileges`, rede interna para o banco e limites de memória.