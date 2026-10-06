# DevSecOps: o que proteger em cada etapa

Guia de referência sobre segurança no ciclo de desenvolvimento. Para cada etapa do ciclo de desenvolvimento, descreve **o que deve ser protegido**, **o que verificar**, **como automatizar** e **onde isso aparece neste projeto**.

> Para o detalhe de cada ferramenta, veja [FERRAMENTAS.md](FERRAMENTAS.md) e [DAST.md](DAST.md). Para a lista de vulnerabilidades do exemplo, veja o final do [README.md](README.md).

## 1. A ideia central

DevSecOps é incorporar segurança em **todas** as etapas do ciclo, de forma automatizada e contínua, em vez de uma auditoria única no final.

- **Shift-left:** quanto mais cedo o problema é encontrado, mais barato é corrigir. Um segredo achado antes do commit custa segundos; achado em produção exige rotação, investigação e comunicação.
- **Automação:** verificações manuais não escalam. O pipeline executa as mesmas verificações a cada alteração.
- **Responsabilidade compartilhada:** segurança não é só do time de segurança. Quem escreve o código, quem opera a infraestrutura e quem revisa são todos responsáveis.
- **Feedback rápido:** o desenvolvedor precisa ver o problema no próprio merge request, com arquivo, linha e sugestão de correção.
- **Defesa em profundidade:** nenhuma ferramenta pega tudo. As camadas se complementam.

```
Planejar -> Codificar -> Commit -> Build -> Testar -> Release -> Implantar -> Operar -> Monitorar
   ^                                                                                      |
   +------------------------------------ feedback ---------------------------------------+
```

## 2. Visão geral por etapa

| Etapa | O que proteger | Verificação típica | Neste projeto |
|-------|----------------|--------------------|---------------|
| Planejamento | Requisitos e desenho | Modelagem de ameaças, requisitos de segurança | Aplicação sem autenticação (decisão consciente de escopo) |
| Codificação | Código-fonte e ambiente do dev | Boas práticas, revisão, hooks locais | `.gitignore`, `.env.example` |
| Commit / repositório | Código, histórico e credenciais | Secret scanning, proteção de branch | Gitleaks |
| Build / integração | Código próprio e dependências | SAST, SCA, licenças | Semgrep, Bandit, Trivy fs, pip-audit, npm audit |
| Empacotamento | Imagem de container | Image scanning, lint de Dockerfile | Trivy image, Hadolint |
| Infraestrutura como código | Configuração de ambiente | Scan de IaC e de compose/K8s | Checkov |
| Testes | Aplicação em execução | DAST, testes de segurança, fuzzing | OWASP ZAP (job `zap-dast`) |
| Release / implantação | Artefato e processo de entrega | Assinatura, SBOM, aprovação, segredos do CI | Variáveis mascaradas no GitLab |
| Operação | Ambiente em execução | Hardening, mínimo privilégio, patches | Compose do branch `fixed` |
| Monitoramento e resposta | Visibilidade e correção | Logs, alertas, gestão de vulnerabilidades | DefectDojo |

## 3. Etapa a etapa

### 3.1 Planejamento e design

**O que proteger:** as decisões que definem a segurança do sistema. Falhas de design não são corrigidas por scanners.

**O que verificar**
- Quais dados a aplicação trata e qual a sensibilidade deles (classificação).
- Quem pode fazer o quê (autenticação, autorização, perfis).
- Superfície de ataque: entradas, integrações externas, portas expostas.
- Requisitos de segurança e de conformidade (LGPD, PCI, contratos).

**Práticas**
- Modelagem de ameaças (STRIDE, árvores de ataque).
- Requisitos de segurança escritos como critérios de aceite.
- Princípios: mínimo privilégio, falhar de forma segura, defesa em profundidade, segurança por padrão.
- Referências: OWASP ASVS, OWASP Top 10, OWASP SAMM.

**No projeto:** o exemplo é um CRUD sem autenticação, de propósito. Em um sistema real, isso seria uma decisão de design a ser justificada. Uma modelagem de ameaças para este cadastro consideraria, por exemplo, a exposição pública sem autenticação, a alteração ou remoção de dados por qualquer pessoa e o abuso dos endpoints auxiliares (importação, exportação, ping, catálogo).

### 3.2 Codificação (ambiente do desenvolvedor)

**O que proteger:** o código sendo escrito, a máquina do desenvolvedor e as credenciais usadas localmente.

**O que verificar**
- Validação e codificação de toda entrada e saída.
- Uso de consultas parametrizadas, APIs seguras e bibliotecas de criptografia padrão.
- Nenhuma credencial no código.
- Dependências novas: são necessárias, mantidas e confiáveis?

**Práticas**
- Guias de codificação segura e treinamento.
- Plugins de IDE com SAST e secret scanning.
- Hooks de pre-commit (por exemplo, Gitleaks).
- Revisão de código (pair programming, merge request obrigatório).
- Separar configuração de código (variáveis de ambiente, `.env` fora do git).

**No projeto:** na `main`, o código usa concatenação de SQL, `eval`, `shell=True` e segredos fixos. No branch `fixed`, valida entradas, usa parâmetros e lê segredos do ambiente.

### 3.3 Commit e repositório

**O que proteger:** o histórico do git (que é permanente), as credenciais e a integridade do que entra na branch principal.

**O que verificar**
- Segredos versionados, inclusive em commits antigos.
- Arquivos que não deveriam ir ao repositório (`.env`, chaves, dumps).
- Quem pode fazer push, merge e alterar o pipeline.

**Práticas**
- **Secret scanning** no pre-commit e no pipeline, varrendo o histórico completo.
- Branch protegida: merge só via merge request, com pipeline verde e aprovação.
- Commits assinados e autenticação forte (2FA, chaves SSH, tokens de escopo mínimo).
- `CODEOWNERS` para arquivos sensíveis (pipeline, Dockerfile, infraestrutura).
- **Segredo vazado = segredo comprometido.** Remover do código não basta: é preciso rotacionar.

**No projeto:** o Gitleaks encontra os segredos da `main`. No branch `fix/secrets`, os valores saem do código, a rotação é feita e um baseline registra os achados históricos já tratados. Veja [SECRETS.md](SECRETS.md).

### 3.4 Build e integração contínua

É a etapa em que a maior parte das verificações automáticas acontece.

#### Código próprio (SAST)

**O que proteger:** o código que a equipe escreve.
**O que verificar:** injeções (SQL, comando, template), XSS, desserialização insegura, path traversal, criptografia fraca, SSRF, configuração insegura de frameworks.
**Como:** Semgrep e Bandit no pipeline, bloqueando o merge. Veja [SAST.md](SAST.md).

#### Dependências (SCA)

**O que proteger:** o código de terceiros, que costuma ser a maior parte da aplicação.
**O que verificar:** CVEs conhecidos em dependências diretas e transitivas, pacotes abandonados, licenças incompatíveis, lockfiles ausentes, risco de *typosquatting* e de ataques à cadeia de suprimentos.
**Como:** Trivy fs, pip-audit e npm audit; atualização automática (Dependabot, Renovate); fixar versões com lockfile. Veja [SCA.md](SCA.md).

#### Qualidade do pipeline

- O pipeline é código e também precisa ser protegido: quem altera o `.gitlab-ci.yml` altera o que é verificado.
- Variáveis do CI mascaradas e protegidas, escopo mínimo nos tokens.
- Runners isolados. Atenção: o `dind` exige modo privilegiado, aceitável apenas em demonstração ou em runners dedicados.
- Imagens do próprio CI com versão fixada.

### 3.5 Empacotamento (containers)

**O que proteger:** o artefato que será executado em produção.

**O que verificar**
- Vulnerabilidades no sistema operacional e nos pacotes da imagem base.
- Segredos esquecidos nas camadas da imagem (`ENV`, `COPY .env`).
- Boas práticas do Dockerfile: usuário não-root, `COPY` em vez de `ADD`, multi-stage, `HEALTHCHECK`, versões fixas, imagem mínima.
- Portas e serviços desnecessários.

**Como:** Trivy image, Hadolint e Checkov, todos bloqueando o merge. Reconstruir imagens com frequência, porque novas CVEs surgem mesmo sem mudança no código. Veja [IMAGEM-IAC.md](IMAGEM-IAC.md).

**Boas práticas adicionais:** registry privado, assinatura de imagens (cosign), geração de SBOM, imagens *distroless* ou *slim*.

### 3.6 Infraestrutura como código

**O que proteger:** a configuração do ambiente onde a aplicação roda.

**O que verificar**
- Exposição de portas e serviços (banco acessível de fora).
- Containers executando como root, com capabilities excessivas ou sistema de arquivos gravável.
- Redes sem segmentação.
- Ausência de limites de recursos.
- Segredos em arquivos de configuração.

**Como:** Checkov para Dockerfile e, em projetos maiores, Terraform, Kubernetes e Helm. Revisão obrigatória de mudanças de infraestrutura.

**No projeto:** o branch `fixed` isola o banco em rede interna, remove portas publicadas, usa `read_only`, `cap_drop: ALL`, `no-new-privileges` e limites de memória.

### 3.7 Testes

**O que proteger:** o comportamento da aplicação em execução, que as análises estáticas não enxergam.

**O que verificar**
- **DAST:** ataques simulados contra a aplicação rodando (OWASP ZAP, Nuclei).
- Autenticação e autorização (acesso a recursos de outro usuário, escalonamento de privilégio).
- Lógica de negócio (fluxos que podem ser burlados).
- Tratamento de erros e mensagens que vazam informação.
- Testes automatizados de segurança como parte da suíte (por exemplo, "entrada maliciosa deve retornar 400").
- Fuzzing e testes de carga para achar falhas de robustez.

**No projeto:** o estágio `dast` do pipeline sobe a aplicação em um ambiente descartável (Docker-in-Docker, com as mesmas imagens geradas pelo `build-images`) e executa o OWASP ZAP em dois modos: `zap-baseline.py` (passivo, no frontend) e `zap-api-scan.py` (ativo, guiado por [dast/openapi.yaml](dast/openapi.yaml)). O job é informativo em todos os branches, pois o DAST exige triagem de falsos positivos. Os relatórios seguem para o DefectDojo. Veja [DAST.md](DAST.md).

### 3.8 Release e implantação

**O que proteger:** o caminho entre o código aprovado e o ambiente de produção.

**O que verificar**
- Só o artefato que passou por todas as verificações é implantado (mesma imagem, mesmo digest).
- Segredos de produção vêm de um cofre ou do gerenciador do CI, nunca do repositório.
- Quem pode aprovar e disparar uma implantação.
- Rastreabilidade: qual commit gerou qual versão em produção.

**Práticas:** ambientes separados (dev, homologação, produção), aprovação manual para produção, SBOM por release, assinatura e verificação de artefatos, estratégia de *rollback*.

### 3.9 Operação

**O que proteger:** o ambiente em execução.

**O que verificar**
- Mínimo privilégio para contas, serviços e containers.
- Atualizações e *patches* de SO, runtime e imagens.
- Segmentação de rede, TLS, firewall, portas expostas.
- Backups testados e protegidos.
- Gestão de segredos com rotação periódica.
- Configuração real igual ao que foi versionado (sem alterações manuais).

### 3.10 Monitoramento e resposta a incidentes

**O que proteger:** a capacidade de detectar e reagir.

**O que verificar**
- Logs de aplicação e de acesso, sem dados sensíveis (senhas, tokens, dados pessoais).
- Alertas para comportamento anômalo (picos de erro, tentativas de injeção, acessos incomuns).
- Novas vulnerabilidades em componentes já implantados (a imagem de hoje pode ter uma CVE publicada amanhã).
- Plano de resposta a incidentes e contatos definidos.

**Gestão de vulnerabilidades:** centralizar os achados, deduplicar, priorizar por severidade e exposição, definir prazos (SLA) e acompanhar até a correção. É o papel do **DefectDojo** neste projeto. Veja [PLATAFORMA.md](PLATAFORMA.md).

**Ciclo de vida de um achado:** detectado -> triado (real ou falso positivo) -> atribuído -> corrigido -> verificado no pipeline seguinte -> marcado como mitigado. Exceções (risco aceito) precisam de justificativa e prazo.

## 4. Transversal: pessoas e processo

- **Treinamento contínuo** em codificação segura.
- **Cultura sem culpa:** quem reporta um vazamento rapidamente deve ser reconhecido, não punido.
- **Segurança como habilitador:** ferramentas com poucos falsos positivos e mensagens claras são adotadas; ferramentas ruidosas são ignoradas.
- **Métricas úteis:** tempo médio de correção, quantidade de vulnerabilidades abertas por severidade, percentual de repositórios com os scans ativos, idade dos achados.
- **Política de bloqueio gradual:** começar em modo informativo (`allow_failure: true`), corrigir o estoque de problemas e só então bloquear. É exatamente a progressão dos branches deste projeto.

## 5. Como cada branch do projeto demonstra isso

| Branch | Etapa demonstrada | Resultado no pipeline |
|--------|-------------------|-----------------------|
| `main` | Ponto de partida: tudo vulnerável, scans informativos | Pipeline passa, mas todos os scanners reportam problemas |
| `fix/sast` | Codificação segura | Semgrep e Bandit passam e bloqueiam |
| `fix/sca` | Cadeia de suprimentos | Trivy fs, pip-audit e npm audit passam e bloqueiam |
| `fix/secrets` | Repositório e credenciais | Gitleaks passa (com baseline) e bloqueia |
| `fix/image` | Empacotamento e IaC | Trivy image, Hadolint e Checkov passam e bloqueiam |
| `fixed` | Defesa em profundidade e operação | Tudo bloqueante, com validação, headers e hardening do ambiente. O DAST continua informativo e reporta bem menos alertas |

O job `zap-dast` roda em todos os branches e nunca bloqueia: no `main` ele reporta injeções, headers ausentes e vazamentos; no `fixed`, restam apenas avisos de menor risco.

## 6. Checklist rápido para um projeto novo

- [ ] Requisitos de segurança e modelo de ameaças definidos
- [ ] `.gitignore` cobre `.env`, chaves e artefatos locais
- [ ] Gitleaks no pre-commit e no pipeline
- [ ] Branch principal protegida, merge só com pipeline verde e revisão
- [ ] SAST bloqueando o merge
- [ ] SCA com lockfile e atualização automática de dependências
- [ ] Imagem base atual e mínima, usuário não-root, `HEALTHCHECK`
- [ ] Image scanning e lint de Dockerfile no pipeline
- [ ] IaC verificado e ambiente com mínimo privilégio
- [ ] DAST em ambiente de teste descartável (nunca em produção)
- [ ] Segredos em cofre ou variáveis protegidas, com rotação
- [ ] Logs sem dados sensíveis e alertas configurados
- [ ] Achados centralizados e com responsável e prazo (DefectDojo)

## 7. Para ir além

- OWASP Top 10, OWASP ASVS, OWASP SAMM e OWASP Cheat Sheet Series
- NIST SSDF (SP 800-218) e SLSA (cadeia de suprimentos)
- CIS Benchmarks para Docker e Kubernetes
- CWE e CVE, para entender a classificação dos achados
