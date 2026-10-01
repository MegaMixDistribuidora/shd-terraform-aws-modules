# apigw-http-api com domínio, CORS e authorizers opcionais — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** permitir instanciar o `apigw-http-api` sem domínio, sem CORS e sem authorizer JWT, para a API interna entre serviços (ADR-29), sem mudar o plan das APIs existentes.

**Architecture:** `count` condicional nos recursos de domínio, bloco `dynamic` no `cors_configuration`, validações cruzadas entre `domain_name`, `certificate_arn` e `zone_id`. Release minor (`feat:`) gera a tag `v1.5.0` pelo semantic-release quando o usuário fizer o merge na `main`.

**Tech Stack:** Terraform ≥ 1.14, provider aws `~> 6.40`, `terraform test` com `mock_provider`.

**Spec:** `docs/superpowers/specs/shd-terraform-aws-modules-design.md` §`apigw-http-api` e §7.

## Global Constraints

- Repositório público: nada de nome, regra ou dado da Mega Mix (exemplos usam `example.com`)
- `cors_allowed_origins` nunca aceita `"*"`
- `domain_name`, `certificate_arn` e `zone_id`: os três juntos ou nenhum
- Chamadores atuais (loja e portal, que passam tudo) não podem ter diff no plan
- Branch `feature/pedidos` a partir de `dev`; commits em Conventional Commits em português

## Review Focus

- Chamador com `cors_allowed_origins = []` e domínio informado: API sem CORS, domínio criado normalmente
- `domain_name` informado sem `zone_id` (ou sem certificado): plan falha com mensagem clara, nunca cria domínio sem alias
- Endereço dos recursos de domínio com `count`: chamadores existentes precisam de `moved` para `[0]`, senão o plan recria domínio e alias da loja e do portal
- Output `domain_name` sem domínio: `null`, não erro de índice
- `jwt_authorizers` vazio: `authorizer_ids` vira `{}`

---

### Task 1: Recursos opcionais no módulo

**Files:**
- Modify: `modules/apigw-http-api/main.tf`
- Modify: `modules/apigw-http-api/variables.tf`
- Modify: `modules/apigw-http-api/outputs.tf`
- Modify: `modules/apigw-http-api/README.md`
- Test: `modules/apigw-http-api/tests/apigw_http_api.tftest.hcl`

**Interfaces:**
- Produces: variáveis `cors_allowed_origins` (padrão `[]`), `jwt_authorizers` (padrão `{}`), `domain_name`/`certificate_arn`/`zone_id` (padrão `null`); output `domain_name` (`string` ou `null`); recursos `aws_apigatewayv2_domain_name.this[0]`, `aws_apigatewayv2_api_mapping.this[0]`, `aws_route53_record.alias[0]`

- [ ] **Step 1: Testes que falham**

No `tftest.hcl`: remover `rejects_empty_origin_list` e `rejects_empty_authorizers`; ajustar as asserções do run `custom_domain_mapped_to_default_stage` para os endereços `[0]`; acrescentar:

```hcl
run "internal_api_without_domain_cors_or_authorizers" {
  command = apply
  variables {
    cors_allowed_origins = []
    jwt_authorizers      = {}
    domain_name          = null
    certificate_arn      = null
    zone_id              = null
  }
  assert {
    condition     = length(aws_apigatewayv2_domain_name.this) == 0 && length(aws_apigatewayv2_api_mapping.this) == 0 && length(aws_route53_record.alias) == 0
    error_message = "Sem domínio, o módulo não cria domínio, mapping nem alias."
  }
  assert {
    condition     = length(aws_apigatewayv2_api.this.cors_configuration) == 0
    error_message = "Sem origens, a API não tem CORS."
  }
  assert {
    condition     = output.authorizer_ids == {} && output.domain_name == null
    error_message = "Sem authorizer e sem domínio, os outputs ficam vazios."
  }
}

run "rejects_domain_without_certificate" {
  command = plan
  variables { certificate_arn = null }
  expect_failures = [var.domain_name]
}

run "rejects_domain_without_zone" {
  command = plan
  variables { zone_id = null }
  expect_failures = [var.domain_name]
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd modules/apigw-http-api && terraform init -backend=false && terraform test`
Expected: FAIL nos três runs novos (variáveis obrigatórias / validação de lista vazia)

- [ ] **Step 3: Implementar**

- `variables.tf`: padrões acima; validação de `cors_allowed_origins` só proíbe `"*"`; remover a validação de `jwt_authorizers`; validação em `domain_name`: `(var.domain_name == null) == (var.certificate_arn == null) && (var.domain_name == null) == (var.zone_id == null)`, mensagem "domain_name, certificate_arn e zone_id devem ser informados juntos ou omitidos."
- `main.tf`: `cors_configuration` como `dynamic` com `for_each = length(var.cors_allowed_origins) > 0 ? [1] : []`; `count = var.domain_name == null ? 0 : 1` nos três recursos de domínio, referências com `[0]`
- `outputs.tf`: `domain_name = one(aws_apigatewayv2_domain_name.this[*].domain_name)`
- `README.md`: inputs opcionais e um exemplo de API interna (sem domínio, sem CORS, sem authorizer)

- [ ] **Step 4: Rodar e ver passar**

Run: `terraform fmt -check -recursive && terraform validate && terraform test`
Expected: PASS em todos os runs

- [ ] **Step 5: Commit**

```bash
git add modules/apigw-http-api
git commit -m "feat: dominio, CORS e authorizers opcionais no apigw-http-api"
```

### Task 2: `moved` para chamadores existentes e exemplo

**Files:**
- Modify: `modules/apigw-http-api/main.tf` (blocos `moved`)
- Modify: `examples/apigw-http-api/main.tf`

**Interfaces:**
- Consumes: endereços `[0]` da Task 1

- [ ] **Step 1: Acrescentar no módulo**

```hcl
moved {
  from = aws_apigatewayv2_domain_name.this
  to   = aws_apigatewayv2_domain_name.this[0]
}
```

e o mesmo para `aws_apigatewayv2_api_mapping.this` e `aws_route53_record.alias`. Assim a plataforma (loja e portal) não recria domínio nem alias.

- [ ] **Step 2: Exemplo**

Em `examples/apigw-http-api/main.tf`, acrescentar `module "internal_api"` sem `cors_allowed_origins`, `jwt_authorizers` e domínio.

- [ ] **Step 3: Verificar**

Run: `terraform fmt -check -recursive && (cd examples/apigw-http-api && terraform init -backend=false && terraform validate) && (cd modules/apigw-http-api && terraform test)`
Expected: sem erro

- [ ] **Step 4: Commit**

```bash
git add modules/apigw-http-api/main.tf examples/apigw-http-api
git commit -m "feat: moved dos recursos de dominio e exemplo de API interna"
```

### Task 3: PR

- [ ] Dispatch do agente `revisor-pr`; corrigir apontamentos
- [ ] `git push -u origin feature/pedidos` e `gh pr create --base dev --title "feat: dominio, CORS e authorizers opcionais no apigw-http-api"`
- [ ] Acompanhar o CI até verde. Merge em `dev` só com autorização do usuário; o `dev` → `main` e a tag `v1.5.0` saem antes do plano da plataforma usar o módulo
