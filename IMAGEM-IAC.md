# Image scanning e IaC / Dockerfile

## Trivy (modo `image`)

**O que e:** o mesmo scanner do [SCA.md](SCA.md), aplicado a uma imagem de container.

**Como funciona:**
1. A imagem e exportada (`docker save`) e suas camadas sao lidas.
2. Identifica o SO (Debian, Alpine) e os pacotes instalados (`dpkg`, `apk`) e tambem pacotes Python/Node dentro da imagem.
3. Compara com as bases de vulnerabilidades (CVEs de distribuicao e de linguagem).
4. Com `--scanners secret` tambem procura segredos esquecidos nas camadas, como `ENV` com senha.

Neste projeto: `--severity HIGH,CRITICAL --ignore-unfixed`, ou seja, so falha para o que tem correcao disponivel.
```
trivy image --severity HIGH,CRITICAL --ignore-unfixed --scanners vuln,secret IMAGEM
```
Correcao: base atual e enxuta (`python:3.12-slim`, `alpine`), `apt-get upgrade` / `apk upgrade` no build e rebuild frequente.

## Hadolint

**O que e:** linter de Dockerfile.

**Como funciona:** faz parse do Dockerfile e aplica regras `DLxxxx` (boas praticas) e, internamente, ShellCheck nos comandos `RUN`. Exemplos: DL3020 (use `COPY` em vez de `ADD`), DL3042 (`pip --no-cache-dir`), DL3064/DL3002 (segredos em `ENV`, usuario root), DL3025 (CMD em formato JSON).
```
hadolint --failure-threshold warning Dockerfile
```

## Checkov

**O que e:** scanner de IaC (Terraform, Kubernetes, Dockerfile, CloudFormation...) da Prisma Cloud/Bridgecrew.

**Como funciona:** converte o arquivo em um grafo/estrutura e avalia politicas `CKV_*`. Em Dockerfiles verifica, por exemplo: CKV_DOCKER_2 (falta `HEALTHCHECK`), CKV_DOCKER_3 (falta usuario nao-root), CKV_DOCKER_1 (porta 22 exposta).
```
checkov --framework dockerfile -d .
```

## Diferenca entre eles

| Ferramenta | Pergunta que responde |
|---|---|
| Trivy image | A imagem final contem pacotes vulneraveis ou segredos? |
| Hadolint | O Dockerfile segue boas praticas de build? |
| Checkov | A configuracao atende politicas de seguranca (usuario, healthcheck, portas)? |

## Em `fix/image` e `fixed`

Multi-stage build, usuario nao-root, `HEALTHCHECK`, `nginx-unprivileged` na porta 8080, gunicorn em vez do servidor de dev. Em `fixed`, o compose ainda usa `read_only`, `cap_drop: ALL`, `no-new-privileges`, rede interna para o banco e limites de memoria.