# github-oidc

Provider OIDC do GitHub Actions, as roles de deploy por ambiente e a permission boundary compartilhada.

| Role | Confia em (`sub`) | Uso |
| --- | --- | --- |
| `<product>-GitHubInfraDeployerRole` | `repo:<org>/aws-<product>-infra:environment:<env>` e `aws-<product>-infra-*` | fundação e plataforma |
| `<product>-GitHubAppDeployerRole` | `repo:<org>/aws-<product>-app-*:environment:<env>` | serviços e frontends |

`<product>-SharedPolicyBoundary` é o teto de permissões das roles criadas pelos deployers (Lambdas, state machines). A permissão efetiva de cada função vem da policy dela; a boundary só limita.

## Uso

```hcl
module "github_oidc" {
  source = "git::https://github.com/MegaMixDistribuidora/shd-terraform-aws-modules.git//modules/github-oidc?ref=vX.Y.Z"

  github_org  = "MegaMixDistribuidora"
  product     = "megamix"
  environment = var.environment
  repository  = local.repository
  tags        = local.tags
}
```

## Inputs

| Nome | Tipo | Descrição |
| --- | --- | --- |
| `github_org` | string | Organização do GitHub |
| `product` | string | Prefixo dos nomes e dos repositórios confiáveis |
| `environment` | string | Nome do GitHub Environment aceito no `sub` |
| `repository` | string | Repositório que gerencia o módulo (tag `Repository`) |
| `tags` | map(string) | Tags mescladas às do módulo |

## Outputs

`oidc_provider_arn`, `oidc_provider_url`, `shared_boundary_policy_arn`, `infra_deployer_role_arn`, `infra_deployer_role_name`, `app_deployer_role_arn`, `app_deployer_role_name`, `infra_deploy_policy_id`, `app_deploy_policy_id`.

## Compatibilidade de state

Os endereços (`aws_iam_openid_connect_provider.github`, `aws_iam_policy.shared_boundary`, `aws_iam_role.infra_role`, `aws_iam_role_policy.infra_deploy_policy`, `aws_iam_role.app_role`, `aws_iam_role_policy.app_deploy_policy`) são os mesmos de `danhenrique/aws-modules//modules/github-oidc`. Trocar o `source` não recria nada.

## Limites

- A boundary é managed policy: **máximo de 6.144 caracteres** sem espaços. Em 2026-09-25 ela renderiza ~5.955 — folga de ~190. O teste `boundary_allows_runtime_needs_and_fits_managed_policy_limit` falha antes de estourar.
- A policy da role `infra` é inline (máximo 10.240 caracteres por role): ~9.560 em 2026-09-26 (inclui `logs:*LogDelivery`, exigido pelo access log da API HTTP da plataforma).
