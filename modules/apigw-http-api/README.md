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

### API interna (serviço a serviço)

Sem domínio, CORS nem authorizers: a API fica só com o endpoint `execute-api`.

```hcl
module "internal_api" {
  source = "git::https://github.com/MegaMixDistribuidora/shd-terraform-aws-modules.git//modules/apigw-http-api?ref=vX.Y.Z"

  name        = "example-internal-api"
  product     = "example"
  environment = var.environment
  tags        = local.tags
}
```

## Inputs

| Nome | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `name` | string | — | nome da API |
| `product` · `environment` | string | — | usados na descrição e nas tags |
| `tags` | map(string) | `{}` | mescladas às tags do módulo |
| `cors_allowed_origins` | list(string) | `[]` | origens explícitas; vazio desliga o CORS; `*` é recusado |
| `cors_allowed_headers` | list(string) | `["authorization", "content-type"]` | |
| `cors_allowed_methods` | list(string) | GET, POST, PUT, PATCH, DELETE, OPTIONS | |
| `throttling_burst_limit` · `throttling_rate_limit` | number | 200 · 100 | padrão da stage |
| `jwt_authorizers` | map(object({ issuer, audience })) | `{}` | vazio não cria authorizer |
| `domain_name` · `certificate_arn` · `zone_id` | string | `null` | domínio, certificado regional e zona; informados juntos ou omitidos (sem eles, não há domínio, mapping nem alias) |
| `access_log_retention_days` | number | 30 | retenção do access log |

## Outputs

`api_id`, `api_endpoint`, `execution_arn`, `stage_name`, `authorizer_ids` (nome → id), `domain_name` (`null` sem domínio).
