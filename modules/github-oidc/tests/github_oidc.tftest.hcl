mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/megamix-SharedPolicyBoundary"
    }
  }
}

variables {
  github_org  = "MegaMixDistribuidora"
  product     = "megamix"
  environment = "dev"
  repository  = "github.com/MegaMixDistribuidora/aws-megamix-infra"
  tags        = {}
}

run "infra_trust_accepts_only_infra_repositories" {
  command = apply # mock_provider: nada é criado na AWS

  assert {
    condition     = strcontains(aws_iam_role.infra_role.assume_role_policy, "repo:MegaMixDistribuidora/aws-megamix-infra:environment:dev")
    error_message = "A role infra deve confiar em aws-megamix-infra."
  }
  assert {
    condition     = strcontains(aws_iam_role.infra_role.assume_role_policy, "repo:MegaMixDistribuidora/aws-megamix-infra-*:environment:dev")
    error_message = "A role infra deve confiar em aws-megamix-infra-* (plataforma)."
  }
  assert {
    condition     = !strcontains(aws_iam_role.infra_role.assume_role_policy, "aws-megamix-app-")
    error_message = "A role infra não pode confiar em repositórios de app."
  }
  assert {
    condition     = strcontains(aws_iam_role.app_role.assume_role_policy, "repo:MegaMixDistribuidora/aws-megamix-app-*:environment:dev")
    error_message = "A role app deve confiar em aws-megamix-app-*."
  }
}

run "infra_policy_covers_platform_services" {
  command = apply # mock_provider: nada é criado na AWS

  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement : s
      if contains(["AllowCognitoUserPools", "AllowCognitoAccountLevel", "AllowSESIdentitiesAndConfigSets", "AllowSESAccountLevel", "AllowAPIGateway", "AllowBudgetsAndOrgRead"], s.Sid)
    ]) == 6
    error_message = "A role infra precisa de Cognito, SES, API Gateway e Budgets (falha do Deploy Dev de 2026-09-24)."
  }
}

run "infra_policy_allows_api_gateway_access_logging" {
  command = apply # mock_provider: nada é criado na AWS

  # Exigido pela AWS para ativar access log de HTTP API (stage da plataforma).
  assert {
    condition = alltrue([
      for a in ["logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery", "logs:ListLogDeliveries"] :
      anytrue([for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement : contains(flatten([s.Action]), a)])
    ])
    error_message = "A role infra precisa das ações logs:*LogDelivery para a stage da API com access log."
  }
}

run "boundary_allows_runtime_needs_and_fits_managed_policy_limit" {
  command = apply # mock_provider: nada é criado na AWS

  assert {
    condition = alltrue([
      for a in ["ses:Send*", "cognito-idp:Admin*", "aoss:APIAccessAll", "xray:Put*"] :
      contains(one([for s in jsondecode(aws_iam_policy.shared_boundary.policy).Statement : s.Action if s.Sid == "AllowAppServices"]), a)
    ])
    error_message = "A boundary precisa permitir e-mail, Cognito admin, OpenSearch Serverless e X-Ray."
  }
  assert {
    condition     = length(jsonencode(jsondecode(aws_iam_policy.shared_boundary.policy))) < 6144
    error_message = "A boundary é managed policy: o documento precisa ter menos de 6144 caracteres."
  }
}

run "app_policy_allows_opensearch_serverless" {
  command = apply # mock_provider: nada é criado na AWS

  assert {
    condition     = contains([for s in jsondecode(aws_iam_role_policy.app_deploy_policy.policy).Statement : s.Sid], "AllowOpenSearchServerless")
    error_message = "A role app precisa gerenciar coleções do OpenSearch Serverless."
  }
}
