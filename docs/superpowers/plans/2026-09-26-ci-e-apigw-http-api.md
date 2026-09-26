# CI, release reutilizável e módulo apigw-http-api — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Colocar o `shd-terraform-aws-modules` na esteira compartilhada (CI de módulos e release do `shd-github-actions-workflows@v1.1.0`), entregar o módulo `apigw-http-api` testado e proteger `dev`/`main` com rulesets.

**Architecture:** O repositório troca o release local por chamadores finos dos workflows reutilizáveis. O módulo `apigw-http-api` nasce por TDD com `terraform test` e `mock_provider` (sem conta AWS): primeiro os `run` com asserts e `expect_failures`, depois os recursos. A publicação segue o fluxo `feature/*` → `dev` → `main`, e a tag gerada (`v1.1.0` deste repositório) é a que a plataforma vai consumir.

**Tech Stack:** Terraform 1.14.9, provider AWS `~> 6.40`, `terraform test` com `mock_provider`, tflint, GitHub Actions (`shd-github-actions-workflows@v1.1.0`).

**Spec:** [`docs/superpowers/specs/shd-terraform-aws-modules-design.md`](../specs/shd-terraform-aws-modules-design.md) (§3 convenções, §5.1 `apigw-http-api`, §6 CI e release) · contexto: `megamix-workspace/docs/arquitetura.md` (ADR-03, ADR-11, ADR-14)

## Global Constraints

- Branch: `feature/apigw-http-api` (de `dev`); PR para `dev`; merge em `dev` só com checks verdes **e** autorização do usuário; promoção `dev` → `main` aberta em seguida; merge em `main` é do usuário
- Commits e títulos em Conventional Commits, em português
- Workflows consumidos por tag exata: `MegaMixDistribuidora/shd-github-actions-workflows/.github/workflows/<arquivo>.yml@v1.1.0`
- Módulo (spec §3): `versions.tf` com Terraform `>= 1.14` e AWS `~> 6.40`; arquivos `variables.tf`, `main.tf`, `outputs.tf`, `locals.tf`, `README.md`; `examples/<módulo>/`; `tests/*.tftest.hcl` com `mock_provider "aws"`; nenhum bloco `provider` no módulo; `tags` recebidas sempre mescladas
- Código, variáveis e comentários em inglês; READMEs em português
- Nenhum recurso real é criado neste plano (só `terraform test` com mock)

## Review Focus

1. **`cors_allowed_origins` com `*` entre outras origens** (`["https://x", "*"]`): tem de ser recusado, não só a lista `["*"]` — teste em Task 2.
2. **`jwt_authorizers` vazio** (`{}`): recusado na validação, porque a API sem authorizer deixaria rotas privadas sem porta — teste em Task 2.
3. **Access log com cabeçalho `Authorization` ou corpo**: o formato não pode incluir token nem corpo (LGPD, RNF-07) — teste em Task 2.
4. **Stage com nome literal `$default`** (o `$` em HCL): o stage precisa se chamar exatamente `$default`, senão o domínio mapeia uma stage que não recebe tráfego — teste em Task 2.
5. **Primeiro PR com o CI novo**: mudança em `.github/` valida **todos** os módulos, inclusive o `github-oidc` já existente — verificação no PR (Task 4).

---

## Estrutura de arquivos

```
.github/workflows/
  ci.yml                    chamador: pr-validation + ci-terraform-module (@v1.1.0)
  release.yml               chamador: release-semantic (@v1.1.0) — substitui o release local
.releaserc.json             removido (a configuração é gravada pelo release-semantic)
modules/apigw-http-api/
  versions.tf · variables.tf · locals.tf · main.tf · outputs.tf · README.md
  tests/apigw_http_api.tftest.hcl
examples/apigw-http-api/
  main.tf · versions.tf
README.md                   índice dos módulos
```

---

### Task 1: CI e release pelos workflows compartilhados

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `.github/workflows/release.yml` (substituir o conteúdo)
- Delete: `.releaserc.json`

**Interfaces:**
- Consumes: `pr-validation.yml`, `ci-terraform-module.yml` e `release-semantic.yml` do `shd-github-actions-workflows@v1.1.0`
- Produces: checks de PR com os nomes `pr / Validate Pull Request` e `modules / Validate Modules` (usados nos rulesets da Task 4)

- [ ] **Step 1: Chamador de CI**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [dev, main]
    types: [opened, edited, synchronize, reopened]

permissions:
  contents: read

jobs:
  pr:
    uses: MegaMixDistribuidora/shd-github-actions-workflows/.github/workflows/pr-validation.yml@v1.1.0

  modules:
    needs: pr
    uses: MegaMixDistribuidora/shd-github-actions-workflows/.github/workflows/ci-terraform-module.yml@v1.1.0
```

- [ ] **Step 2: Release pelo workflow compartilhado**

Replace `.github/workflows/release.yml` with:

```yaml
# ADR-14: todo commit na main gera tag vX.Y.Z e GitHub Release.
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  release:
    uses: MegaMixDistribuidora/shd-github-actions-workflows/.github/workflows/release-semantic.yml@v1.1.0
    permissions:
      contents: write
      issues: write
      pull-requests: write
```

Run: `git rm -q .releaserc.json`

- [ ] **Step 2b: Verificar os chamadores**

Run: `export PATH=$HOME/.local/bin:$PATH && actionlint .github/workflows/*.yml`
Expected: sem saída (o actionlint baixa e confere os workflows reutilizáveis remotos na `v1.1.0`)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml .releaserc.json
git commit -m "ci: ci de módulos e release pelos workflows compartilhados v1.1.0"
```

(A verificação real é o primeiro PR — Task 4.)

---

### Task 2: Módulo `apigw-http-api`

**Files:**
- Create: `modules/apigw-http-api/versions.tf`, `variables.tf`, `locals.tf`, `main.tf`, `outputs.tf`, `README.md`, `tests/apigw_http_api.tftest.hcl`
- Create: `examples/apigw-http-api/main.tf`, `examples/apigw-http-api/versions.tf`

**Interfaces:**
- Produces (spec §5.1), consumido pela plataforma:
  - inputs: `name`, `product`, `environment`, `tags`, `cors_allowed_origins` (list(string)), `cors_allowed_headers` (list(string), padrão `["authorization", "content-type"]`), `cors_allowed_methods` (list(string), padrão `["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]`), `throttling_burst_limit` (number, 200), `throttling_rate_limit` (number, 100), `jwt_authorizers` (map(object({ issuer = string, audience = list(string) }))), `domain_name`, `certificate_arn`, `zone_id`, `access_log_retention_days` (number, 30)
  - outputs: `api_id`, `api_endpoint`, `execution_arn`, `stage_name`, `authorizer_ids` (map nome → id), `domain_name`
  - endereços: `aws_apigatewayv2_api.this`, `aws_cloudwatch_log_group.access`, `aws_apigatewayv2_stage.default`, `aws_apigatewayv2_authorizer.jwt["<nome>"]`, `aws_apigatewayv2_domain_name.this`, `aws_apigatewayv2_api_mapping.this`, `aws_route53_record.alias`

- [ ] **Step 1: Escrever os testes (falham: o módulo não existe)**

Create `modules/apigw-http-api/tests/apigw_http_api.tftest.hcl`:

```hcl
mock_provider "aws" {}

variables {
  name        = "megamix-api"
  product     = "megamix"
  environment = "dev"
  tags        = { Repository = "github.com/MegaMixDistribuidora/aws-megamix-infra-platform" }

  cors_allowed_origins = ["https://dev.danhenrique.com.br", "http://localhost:3000"]

  jwt_authorizers = {
    customers = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_AAAAAAAAA", audience = ["client-loja"] }
    staff     = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_BBBBBBBBB", audience = ["client-painel"] }
  }

  domain_name     = "api.dev.danhenrique.com.br"
  certificate_arn = "arn:aws:acm:sa-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  zone_id         = "Z0123456789ABCDEFGHIJ"
}

run "creates_http_api_with_default_stage" {
  command = apply # mock_provider: nada é criado na AWS

  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP"
    error_message = "A API deve ser HTTP (ADR-03)."
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.name == "$default" && aws_apigatewayv2_stage.default.auto_deploy
    error_message = "A stage deve ser $default com auto_deploy, para as rotas dos serviços entrarem no ar sem deploy."
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.default_route_settings[0].throttling_burst_limit == 200 && aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit == 100
    error_message = "Throttling padrão deve ser burst 200 e 100 req/s."
  }
  assert {
    condition     = aws_cloudwatch_log_group.access.retention_in_days == 30
    error_message = "Retenção padrão do access log deve ser 30 dias."
  }
  assert {
    condition     = aws_apigatewayv2_api.this.tags["Repository"] == "github.com/MegaMixDistribuidora/aws-megamix-infra-platform" && aws_apigatewayv2_api.this.tags["ManagedBy"] == "terraform"
    error_message = "As tags recebidas devem ser mescladas às do módulo."
  }
}

run "one_jwt_authorizer_per_map_entry" {
  command = apply # mock_provider

  assert {
    condition     = length(aws_apigatewayv2_authorizer.jwt) == 2
    error_message = "Deve existir um authorizer por item de jwt_authorizers."
  }
  assert {
    condition     = aws_apigatewayv2_authorizer.jwt["staff"].authorizer_type == "JWT" && aws_apigatewayv2_authorizer.jwt["staff"].jwt_configuration[0].issuer == "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_BBBBBBBBB"
    error_message = "O authorizer staff deve ser JWT com o issuer da pool de staff."
  }
  assert {
    condition     = toset(keys(output.authorizer_ids)) == toset(["customers", "staff"])
    error_message = "authorizer_ids deve ter uma chave por authorizer."
  }
}

run "custom_domain_mapped_to_default_stage" {
  command = apply # mock_provider

  assert {
    condition     = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].endpoint_type == "REGIONAL" && aws_apigatewayv2_domain_name.this.domain_name_configuration[0].security_policy == "TLS_1_2"
    error_message = "Domínio deve ser regional com TLS 1.2."
  }
  assert {
    condition     = aws_apigatewayv2_api_mapping.this.stage == aws_apigatewayv2_stage.default.id
    error_message = "O domínio deve mapear para a stage $default."
  }
  assert {
    condition     = aws_route53_record.alias.name == "api.dev.danhenrique.com.br" && aws_route53_record.alias.type == "A"
    error_message = "Alias A no Route53 com o nome do domínio."
  }
  assert {
    condition     = output.domain_name == "api.dev.danhenrique.com.br"
    error_message = "Output domain_name deve devolver o domínio."
  }
}

run "access_log_without_token_or_body" {
  command = apply # mock_provider

  assert {
    condition     = contains(keys(jsondecode(aws_apigatewayv2_stage.default.access_log_settings[0].format)), "requestId")
    error_message = "O access log deve ser JSON com requestId."
  }
  assert {
    condition     = !strcontains(lower(aws_apigatewayv2_stage.default.access_log_settings[0].format), "authorization") && !strcontains(lower(aws_apigatewayv2_stage.default.access_log_settings[0].format), "body")
    error_message = "O access log não pode conter cabeçalho Authorization nem corpo (RNF-07)."
  }
}

run "rejects_wildcard_origin_among_others" {
  command = plan

  variables {
    cors_allowed_origins = ["https://dev.danhenrique.com.br", "*"]
  }

  expect_failures = [var.cors_allowed_origins]
}

run "rejects_empty_origin_list" {
  command = plan

  variables {
    cors_allowed_origins = []
  }

  expect_failures = [var.cors_allowed_origins]
}

run "rejects_empty_authorizers" {
  command = plan

  variables {
    jwt_authorizers = {}
  }

  expect_failures = [var.jwt_authorizers]
}
```

Create `modules/apigw-http-api/versions.tf` (needed so `terraform init` downloads the mocked provider):

```hcl
terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.40"
    }
  }
}
```

Run: `cd modules/apigw-http-api && terraform init -backend=false -input=false >/dev/null && terraform test -no-color 2>&1 | tail -5; cd ../..`
Expected: FAIL — referências a `aws_apigatewayv2_api.this`, `var.cors_allowed_origins` etc. não declaradas

- [ ] **Step 2: Variáveis com validação**

Create `modules/apigw-http-api/variables.tf`:

```hcl
variable "name" {
  description = "API name (e.g. megamix-api)."
  type        = string
}

variable "product" {
  description = "Product name, used in descriptions and default tags."
  type        = string
}

variable "environment" {
  description = "Environment (dev or prod)."
  type        = string
}

variable "tags" {
  description = "Tags merged into the module defaults."
  type        = map(string)
  default     = {}
}

variable "cors_allowed_origins" {
  description = "Allowed CORS origins. Wildcard is not allowed."
  type        = list(string)

  validation {
    condition     = length(var.cors_allowed_origins) > 0 && alltrue([for o in var.cors_allowed_origins : o != "*"])
    error_message = "cors_allowed_origins must list explicit origins and cannot contain \"*\"."
  }
}

variable "cors_allowed_headers" {
  description = "Allowed CORS request headers."
  type        = list(string)
  default     = ["authorization", "content-type"]
}

variable "cors_allowed_methods" {
  description = "Allowed CORS methods."
  type        = list(string)
  default     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
}

variable "throttling_burst_limit" {
  description = "Default stage burst limit."
  type        = number
  default     = 200
}

variable "throttling_rate_limit" {
  description = "Default stage rate limit (requests per second)."
  type        = number
  default     = 100
}

variable "jwt_authorizers" {
  description = "JWT authorizers keyed by name (e.g. customers, staff)."
  type = map(object({
    issuer   = string
    audience = list(string)
  }))

  validation {
    condition     = length(var.jwt_authorizers) > 0
    error_message = "jwt_authorizers must contain at least one authorizer."
  }
}

variable "domain_name" {
  description = "Custom domain for the API (e.g. api.example.com)."
  type        = string
}

variable "certificate_arn" {
  description = "Regional ACM certificate ARN covering domain_name."
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone id where the alias record is created."
  type        = string
}

variable "access_log_retention_days" {
  description = "CloudWatch retention for the access log."
  type        = number
  default     = 30
}
```

- [ ] **Step 3: Recursos**

Create `modules/apigw-http-api/locals.tf`:

```hcl
locals {
  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Product   = var.product
  })

  # No headers and no request/response body: tokens and personal data stay out of logs (RNF-07).
  access_log_format = {
    requestId               = "$context.requestId"
    ip                      = "$context.identity.sourceIp"
    requestTime             = "$context.requestTime"
    httpMethod              = "$context.httpMethod"
    routeKey                = "$context.routeKey"
    status                  = "$context.status"
    protocol                = "$context.protocol"
    responseLength          = "$context.responseLength"
    integrationErrorMessage = "$context.integrationErrorMessage"
    authorizerError         = "$context.authorizer.error"
  }
}
```

Create `modules/apigw-http-api/main.tf`:

```hcl
resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"
  description   = "Shared HTTP API - ${var.product} ${var.environment}"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = var.cors_allowed_methods
    allow_headers = var.cors_allowed_headers
    max_age       = 3600
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.access_log_retention_days

  tags = local.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format          = jsonencode(local.access_log_format)
  }

  tags = local.tags
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  for_each = var.jwt_authorizers

  api_id           = aws_apigatewayv2_api.this.id
  name             = each.key
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = each.value.issuer
    audience = each.value.audience
  }
}

resource "aws_apigatewayv2_domain_name" "this" {
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = local.tags
}

resource "aws_apigatewayv2_api_mapping" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this.id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "alias" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
```

Create `modules/apigw-http-api/outputs.tf`:

```hcl
output "api_id" {
  description = "HTTP API id."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Default execute-api endpoint."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "execution_arn" {
  description = "Execution ARN, used in lambda:InvokeFunction permissions."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_name" {
  description = "Stage name ($default)."
  value       = aws_apigatewayv2_stage.default.name
}

output "authorizer_ids" {
  description = "Authorizer ids keyed by name."
  value       = { for name, authorizer in aws_apigatewayv2_authorizer.jwt : name => authorizer.id }
}

output "domain_name" {
  description = "Custom domain of the API."
  value       = aws_apigatewayv2_domain_name.this.domain_name
}
```

- [ ] **Step 4: Rodar os testes**

Run: `cd modules/apigw-http-api && terraform fmt -check -recursive && terraform validate -no-color && terraform test -no-color 2>&1 | tail -3; cd ../..`
Expected: `Success! 7 passed, 0 failed.`

- [ ] **Step 5: Provar que os testes pegam regressões**

Mutação 1 — trocar `name = "$default"` por `name = "default"` no stage e rodar `terraform test`.
Expected: `creates_http_api_with_default_stage` falha. Restaurar.

Mutação 2 — acrescentar `authorization = "$context.authorizer.claims"` ao `access_log_format` e rodar `terraform test`.
Expected: `access_log_without_token_or_body` falha. Restaurar e confirmar `7 passed`.

- [ ] **Step 6: tflint e exemplo**

Create `examples/apigw-http-api/versions.tf` with the same content as `modules/apigw-http-api/versions.tf`.

Create `examples/apigw-http-api/main.tf`:

```hcl
provider "aws" {
  region = "sa-east-1"
}

module "api" {
  source = "../../modules/apigw-http-api"

  name        = "megamix-api"
  product     = "megamix"
  environment = "dev"

  cors_allowed_origins = ["https://dev.example.com", "http://localhost:3000"]

  jwt_authorizers = {
    customers = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_AAAAAAAAA", audience = ["client-loja"] }
    staff     = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_BBBBBBBBB", audience = ["client-painel"] }
  }

  domain_name     = "api.dev.example.com"
  certificate_arn = "arn:aws:acm:sa-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  zone_id         = "Z0123456789ABCDEFGHIJ"

  tags = { ManagedBy = "terraform" }
}
```

Run: `cd modules/apigw-http-api && tflint --init >/dev/null && tflint --format compact; cd ../../examples/apigw-http-api && terraform init -backend=false -input=false >/dev/null && terraform validate -no-color; cd ../..`
Expected: tflint sem achados; `Success! The configuration is valid.`

- [ ] **Step 7: README do módulo**

Create `modules/apigw-http-api/README.md`:

````markdown
# apigw-http-api

API HTTP compartilhada da plataforma (ADR-03): stage `$default` com auto-deploy, CORS, throttling, access log em JSON (sem cabeçalhos nem corpo), JWT authorizers por nome, domínio customizado regional (TLS 1.2), mapeamento para a stage e alias A no Route53. Usado **uma vez**, pela plataforma; os serviços criam as próprias rotas na API.

## Uso

```hcl
module "api" {
  source = "git::https://github.com/MegaMixDistribuidora/shd-terraform-aws-modules.git//modules/apigw-http-api?ref=vX.Y.Z"

  name        = "megamix-api"
  product     = "megamix"
  environment = var.environment

  cors_allowed_origins = var.cors_allowed_origins
  jwt_authorizers = {
    customers = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/<pool-clientes>", audience = [<client-loja>] }
    staff     = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/<pool-staff>", audience = [<client-painel>] }
  }

  domain_name     = "api.${local.zone_name}"
  certificate_arn = local.certificate_arn
  zone_id         = local.zone_id
  tags            = local.tags
}
```

## Inputs

| Nome | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `name` | string | — | nome da API |
| `product` · `environment` | string | — | usados na descrição e nas tags |
| `tags` | map(string) | `{}` | mescladas às tags do módulo |
| `cors_allowed_origins` | list(string) | — | origens explícitas; `*` é recusado |
| `cors_allowed_headers` | list(string) | `["authorization", "content-type"]` | |
| `cors_allowed_methods` | list(string) | GET, POST, PUT, PATCH, DELETE, OPTIONS | |
| `throttling_burst_limit` · `throttling_rate_limit` | number | 200 · 100 | padrão da stage |
| `jwt_authorizers` | map(object({ issuer, audience })) | — | ao menos um |
| `domain_name` · `certificate_arn` · `zone_id` | string | — | domínio, certificado regional e zona |
| `access_log_retention_days` | number | 30 | retenção do access log |

## Outputs

`api_id`, `api_endpoint`, `execution_arn`, `stage_name`, `authorizer_ids` (nome → id), `domain_name`.
````

- [ ] **Step 8: Commit**

```bash
git add modules/apigw-http-api examples/apigw-http-api
git commit -m "feat(apigw-http-api): api http compartilhada com authorizers jwt e domínio customizado"
```

---

### Task 3: Índice do repositório e spec

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/shd-terraform-aws-modules-design.md`

- [ ] **Step 1: README com o índice**

Replace `README.md` with:

```markdown
# shd-terraform-aws-modules

Módulos Terraform compartilhados da Mega Mix. Consumo **sempre por tag**:

`git::https://github.com/MegaMixDistribuidora/shd-terraform-aws-modules.git//modules/<nome>?ref=vX.Y.Z`

| Módulo | Faz | Desde |
| --- | --- | --- |
| [`github-oidc`](modules/github-oidc) | provider OIDC, roles `infra`/`app` e boundary compartilhada | v1.0.0 |
| [`apigw-http-api`](modules/apigw-http-api) | API HTTP compartilhada com JWT authorizers e domínio customizado | v1.1.0 |

Cada módulo tem `README.md`, exemplo em `examples/<nome>` e testes em `modules/<nome>/tests` (`terraform test` com provider mockado). O CI valida só os módulos alterados; todo commit na `main` gera tag e release (ADR-14).
```

- [ ] **Step 2: Spec §6 sem a nota de bootstrap**

In `docs/superpowers/specs/shd-terraform-aws-modules-design.md`, replace the paragraph that starts with `**Ordem de bootstrap:**` by:

```markdown
**CI e release:** `.github/workflows/ci.yml` chama `pr-validation` e `ci-terraform-module`, e `release.yml` chama `release-semantic`, todos do `shd-github-actions-workflows@v1.1.0`. O repositório não mantém `.releaserc.json`.
```

Run: `grep -n 'Ordem de bootstrap' docs/superpowers/specs/shd-terraform-aws-modules-design.md || echo "nota de bootstrap removida"`
Expected: `nota de bootstrap removida`

- [ ] **Step 3: Commit**

```bash
git add README.md docs/superpowers/specs/shd-terraform-aws-modules-design.md
git commit -m "docs: índice de módulos e ci pelos workflows compartilhados"
```

---

### Task 4: Publicar, verificar e proteger

**Files:** apaga este plano; ações no GitHub.

- [ ] **Step 1: Apagar o plano executado e abrir o PR**

```bash
git rm -q docs/superpowers/plans/2026-09-26-ci-e-apigw-http-api.md
git commit -m "docs: remove o plano executado do ci e do apigw-http-api"
git push -u origin feature/apigw-http-api
gh pr create --base dev --title "feat: ci compartilhado e módulo apigw-http-api" --body "$(cat <<'EOF'
## O que entra
- CI (`pr-validation` + `ci-terraform-module`) e release (`release-semantic`) pelos workflows do `shd-github-actions-workflows@v1.1.0`; `.releaserc.json` removido
- Módulo `apigw-http-api` (spec §5.1): API HTTP, stage `$default` com auto-deploy, CORS sem curinga, throttling, access log sem cabeçalhos nem corpo, JWT authorizers por nome, domínio regional TLS 1.2, mapeamento e alias no Route53
- Exemplo, README do módulo e índice do repositório

## Como foi validado
- `terraform test` com provider mockado: 7 cenários, incluindo curinga entre outras origens, lista vazia, authorizers vazios e access log sem token
- Mutações conferidas: stage fora de `$default` e log com `authorization` fazem os testes falharem
- tflint sem achados; exemplo com `terraform validate`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Conferir o primeiro CI**

Run: `gh pr checks feature/apigw-http-api --watch --interval 15; gh pr checks feature/apigw-http-api`
Expected: `pr / Validate Pull Request` e `modules / Validate Modules` verdes. No log de `Validate Modules`: módulos afetados `["apigw-http-api","github-oidc"]` (mudança em `.github/` valida todos) e `terraform test` passando nos dois.

- [ ] **Step 3: Merge em `dev` e promoção**

Com checks verdes **e** autorização do usuário: `gh pr merge <n> --merge --delete-branch`. Sem deploy neste repositório: abrir `gh pr create --base main --head dev --title "feat: ci compartilhado e módulo apigw-http-api"` e conferir os checks. **Merge em `main` é do usuário.**

- [ ] **Step 4: Conferir o release (após o merge em `main`)**

Run:
```bash
gh run list --workflow Release --branch main --limit 1
git fetch -q --tags && git tag --list 'v*' --sort=-v:refname | head -2
git ls-tree -r --name-only v1.1.0 -- modules/apigw-http-api | head -3
```
Expected: run `success`; `v1.1.0` acima de `v1.0.0`; arquivos do `apigw-http-api` presentes na tag

- [ ] **Step 5: Rulesets (repositório público)**

Branches — create `/tmp/ruleset-branches.json`:

```json
{
  "name": "dev-e-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/dev", "refs/heads/main"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": true, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false, "required_status_checks": [
      { "context": "pr / Validate Pull Request" }, { "context": "modules / Validate Modules" } ] } }
  ],
  "bypass_actors": []
}
```

Tags `v*` imutáveis (spec §6) — create `/tmp/ruleset-tags.json`:

```json
{
  "name": "tags-imutaveis",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "update" } ],
  "bypass_actors": []
}
```

Run:
```bash
R=MegaMixDistribuidora/shd-terraform-aws-modules
gh api -X POST repos/$R/rulesets --input /tmp/ruleset-branches.json --jq '.name + " " + .enforcement'
gh api -X POST repos/$R/rulesets --input /tmp/ruleset-tags.json --jq '.name + " " + .enforcement'
gh api repos/$R/rules/branches/main --jq '[.[].type] | join(", ")'
rm -f /tmp/ruleset-*.json
```
Expected: `dev-e-main active`, `tags-imutaveis active`, e em `main`: `deletion, non_fast_forward, pull_request, required_status_checks`

Nota: os nomes dos checks do Step 2 são os que entram no ruleset; se o GitHub exibir nomes diferentes, usar os exibidos (Ruling no ledger).
