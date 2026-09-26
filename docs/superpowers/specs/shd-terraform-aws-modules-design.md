# shd-terraform-aws-modules — Módulos Terraform compartilhados (Design)

**Estado-alvo** deste repositório. Contexto: [PRD](../../../../docs/prd.md) · [Arquitetura](../../../../docs/arquitetura.md) (ADR-11, ADR-14, ADR-15) · [Fundação](../../../../aws-megamix-infra/docs/superpowers/specs/megamix-infra-foundation-design.md)

## 1. Objetivo

Um único repositório, `MegaMixDistribuidora/shd-terraform-aws-modules`, com os
módulos Terraform genéricos usados pelos repositórios de infra e de serviço da
Mega Mix. Substitui o uso de `danhenrique/aws-modules` e
`SthoreH/shd-terraform-aws-*`, que passam a ser **apenas referência** de código.

Sucesso: a fundação e a plataforma consomem `github-oidc`, `iam-role` e
`apigw-http-api` por tag (`?ref=vX.Y.Z`), sem nenhuma referência a `main` nem a
repositórios fora da organização.

## 2. Decisões

| Decisão | Motivo |
|---|---|
| Um repositório, vários módulos em `modules/<nome>` | Um CI, um release e um lugar para manter — o projeto é mantido por uma pessoa |
| Uma tag semver para o conjunto | Simplicidade; o custo aceito é que subir um módulo sobe a versão de todos |
| Consumo por `git::https://github.com/MegaMixDistribuidora/shd-terraform-aws-modules.git//modules/<nome>?ref=vX.Y.Z` | Versão fixa, nunca `main` |
| Repositório **público** | Workflows e `terraform init` de outros repos baixam sem credencial; não contém segredo nem dado de negócio |
| Módulo é implementado quando o primeiro consumidor precisa dele | YAGNI; a lista da §5 é o contrato planejado, não escopo desta fase |

## 3. Convenções de todo módulo

- Terraform `>= 1.14`, provider AWS `~> 6.40`, declarados em `versions.tf`
- Arquivos: `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `locals.tf` (se houver), `README.md`
- `README.md` com descrição, exemplo mínimo de uso, tabela de inputs e outputs
- `examples/basic/` com um uso mínimo que passa em `terraform validate`
- `tests/*.tftest.hcl` com `command = plan` e provider mockado (`mock_provider "aws"`), sem conta AWS
- Variáveis com `description`, `type` e `validation` quando o valor tem domínio fechado
- Toda variável `tags` é mesclada às tags do módulo; o módulo nunca descarta as tags recebidas
- Nomes de recurso recebem `product` e `environment` como prefixo quando o recurso tem nome global ou por conta
- Código, variáveis e comentários em inglês; READMEs em português
- Nenhum `provider` declarado dentro de módulo

## 4. Estrutura do repositório

```
modules/
  github-oidc/
  iam-role/
  apigw-http-api/
docs/superpowers/specs/
.github/workflows/      ci.yml (chama ci-terraform-module) · release.yml
.releaserc.json         semantic-release, tagFormat v${version}
README.md               índice dos módulos com a versão em que cada um entrou
```

## 5. Catálogo de módulos

### 5.1 Fase 0 (escopo desta spec)

#### `github-oidc`

Provider OIDC do GitHub e as duas roles de deploy por ambiente, com a mesma
separação do módulo de referência:

| Role | Confia em (`sub`) | Uso |
|---|---|---|
| `infra` | `repo:<org>/aws-<product>-infra:environment:<env>` e `repo:<org>/aws-<product>-infra-*:environment:<env>` | fundação e plataforma |
| `app` | `repo:<org>/aws-<product>-app-*:environment:<env>` | serviços e frontends |

- `aud` fixo em `sts.amazonaws.com`
- Permission boundary compartilhada aplicada às roles criadas pelos deployers
- **Compatibilidade de state:** os endereços dos recursos (`aws_iam_openid_connect_provider.github`,
  `aws_iam_role.infra_role`, `aws_iam_role.app_role`, `aws_iam_policy.shared_boundary` e as
  `aws_iam_role_policy`) são **idênticos** aos do módulo de referência. A troca de `source` na
  fundação não pode gerar destroy/create; se algum endereço mudar, o módulo traz o bloco `moved`.
- **Correção de permissões da role `infra`** — a policy de referência não cobre serviços que a
  fundação e a plataforma já usam. A role `infra` passa a permitir, restrito a recursos com
  prefixo do produto quando o serviço suporta:
  - `cognito-idp:*` sobre user pools da conta
  - `ses:*` de identidade, DKIM e configuration set
  - `apigateway:*` sobre `/apis`, `/domainnames` e `/apimappings` (HTTP API v2)
  - `budgets:*` (já presente)
- A role `app` ganha as permissões de que os serviços precisam para criar os próprios recursos:
  Lambda, IAM (roles com a boundary), DynamoDB, SQS, EventBridge (rules no bus), Scheduler,
  Step Functions, CloudWatch Logs e alarms, OpenSearch Serverless (`aoss:*` com prefixo do
  produto), rotas e integrações do API Gateway (sem criar APIs nem domínios), e leitura de SSM
  em `/<product>/*`
- Outputs: `oidc_provider_arn`, `infra_role_arn`, `app_role_arn`, `boundary_policy_arn`

#### `iam-role`

Role genérica com trust e policies vindas de templates, usada pelas Lambdas e state machines.

- Inputs: `name`, `trust_policy_json`, `inline_policies` (map nome → JSON), `managed_policy_arns`,
  `permissions_boundary_arn` (obrigatório), `tags`
- Outputs: `role_arn`, `role_name`
- Validação: `permissions_boundary_arn` não pode ser vazio — toda role criada por pipeline de app
  carrega a boundary

#### `apigw-http-api`

A API HTTP compartilhada da plataforma. Usado **uma vez**, pela plataforma.

- Cria: `aws_apigatewayv2_api` (HTTP), stage `$default` com `auto_deploy = true`, access log em
  CloudWatch (retenção configurável, padrão 30 dias, formato JSON sem corpo de requisição),
  throttling padrão da stage, CORS, JWT authorizers a partir de um map, domínio customizado com
  certificado ACM regional, `api_mapping` do domínio para a stage `$default` e registro alias no
  Route53
- Inputs:
  - `name`, `product`, `environment`, `tags`
  - `cors_allowed_origins` (list, sem `*`), `cors_allowed_headers`, `cors_allowed_methods`
  - `throttling_burst_limit` (padrão 200), `throttling_rate_limit` (padrão 100 req/s)
  - `jwt_authorizers` — map `nome → { issuer, audience }`
  - `domain_name`, `certificate_arn`, `zone_id`
  - `access_log_retention_days` (padrão 30)
- Outputs: `api_id`, `api_endpoint`, `execution_arn`, `stage_name`, `authorizer_ids` (map),
  `domain_name`
- Validação: `cors_allowed_origins` não aceita `*`; `jwt_authorizers` exige ao menos um item

### 5.2 Fases seguintes (contrato planejado, fora do escopo desta spec)

| Módulo | Cria | Primeiro consumidor |
|---|---|---|
| `lambda` | função + alias + log group com retenção; suporte a layers e arm64 | catalog service |
| `apigw-http-routes` | rotas + integração Lambda (payload 2.0) + `lambda:InvokeFunction` na API compartilhada, com authorizer por rota | catalog service |
| `dynamodb` | tabela on-demand, PITR, SSE, TTL, streams e GSIs opcionais | catalog service |
| `sqs` | fila + DLQ + redrive + alarme de mensagens na DLQ | catalog service |
| `eventbridge-rule` | rule no bus + target SQS/Lambda + permissões | orders service |
| `sfn` | state machine + role + logs + schedule opcional do EventBridge Scheduler | catalog service |
| `opensearch-serverless` | coleção + políticas de criptografia, rede e acesso a dados | catalog service |

Cada um recebe sua própria seção de design na spec do primeiro serviço que o
consome, e entra neste repositório em um minor release.

## 6. CI e release

- PR para `dev` e para `main`: workflow `ci-terraform-module` do `shd-github-actions-workflows` — `fmt -check`,
  `validate` de cada módulo e de cada `examples/*`, `tflint`, `checkov` e `terraform test`
  apenas nos módulos alterados
- Push em `main`: semantic-release gera a tag `vX.Y.Z` e o release a partir de Conventional Commits
  (`feat(lambda): ...` → minor, `fix(...)` → patch, `BREAKING CHANGE` → major)
- Fluxo `feature/*` → `dev` → `main`, sem commit direto em `dev`/`main` (regra do workspace). Por ser público, o repositório tem rulesets no plano Free: `dev` e `main` exigem PR e CI verde, sem force push nem deleção; tags `v*` imutáveis
- O release só cria tag e GitHub Release — nenhum commit do bot na `main`

**CI e release:** `.github/workflows/ci.yml` chama `pr-validation` e `ci-terraform-module`, e `release.yml` chama `release-semantic`, todos do `shd-github-actions-workflows@v1.1.0`. O repositório não mantém `.releaserc.json`.

## 7. Verificação

1. `terraform fmt -check -recursive`
2. `terraform validate` em cada `modules/*` e `examples/*`
3. `terraform test` em cada módulo — prova, sem conta AWS, que:
   - `github-oidc`: a trust da role `infra` aceita `aws-megamix-infra` e `aws-megamix-infra-platform` e recusa `aws-megamix-app-x`
   - `iam-role`: o plan falha sem `permissions_boundary_arn`
   - `apigw-http-api`: o plan falha com `*` em CORS; cria um authorizer por item do map
4. Prova de compatibilidade do `github-oidc`: `terraform plan` da fundação em dev, após a troca de
   `source`, mostra **zero destroy** nos recursos de OIDC (verificado na migração da fundação, §5 da spec dela)

## 8. Riscos aceitos

| Risco | Mitigação |
|---|---|
| Tag única versiona módulos sem relação entre si | Changelog por módulo via escopo do commit; consumidores sobem de versão quando querem |
| Ampliar a role `infra` aumenta o raio de dano de um workflow comprometido | Trust restrita aos repositórios `aws-megamix-infra*` e ao GitHub Environment; prod exige aprovação manual |
| Dependência circular com o repositório de workflows no bootstrap | CI local na primeira versão (§6) |
