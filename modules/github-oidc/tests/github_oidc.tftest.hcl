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

run "infra_policy_allows_cognito_email_service_linked_role" {
  command = apply # mock_provider: nada é criado na AWS

  # Exigido pela AWS quando uma user pool passa a enviar e-mail pelo SES (plataforma, §5.2c).
  assert {
    # O `if` filtra antes de avaliar: statements sem Condition nunca são lidos (HCL não faz curto-circuito).
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement :
      contains(flatten([s.Resource]), "arn:aws:iam::*:role/aws-service-role/email.cognito-idp.amazonaws.com/*")
      && contains(flatten([s.Condition.StringLike["iam:AWSServiceName"]]), "email.cognito-idp.amazonaws.com")
      if s.Sid == "AllowCreateServiceLinkedRole"
    ])
    error_message = "A role infra precisa criar o SLR email.cognito-idp.amazonaws.com para ligar o Cognito ao SES."
  }
  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement :
      contains(flatten([s.Condition.StringLike["iam:AWSServiceName"]]), "ops.apigateway.amazonaws.com")
      if s.Sid == "AllowCreateServiceLinkedRole"
    ])
    error_message = "O SLR do API Gateway continua permitido."
  }
  assert {
    condition     = length(jsonencode(jsondecode(aws_iam_role_policy.infra_deploy_policy.policy))) < 10240
    error_message = "A policy inline da role infra precisa ter menos de 10240 caracteres."
  }
}

run "infra_policy_allows_budget_tagging" {
  command = apply # mock_provider: nada é criado na AWS

  # O provider AWS lê e grava as tags do aws_budgets_budget (budget da fundação).
  assert {
    condition = alltrue([
      for a in ["budgets:ListTagsForResource", "budgets:TagResource", "budgets:UntagResource"] :
      anytrue([for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement : contains(flatten([s.Action]), a)])
    ])
    error_message = "A role infra precisa das ações de tag do Budgets para gerenciar o budget com tags."
  }
}

run "infra_policy_allows_scoped_kms_key_management" {
  command = apply # mock_provider: nada é criado na AWS

  # A plataforma cria a chave KMS gerenciada pelo cliente (alias/<product>-default).
  assert {
    condition = length([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement : s
      if contains(["AllowKMSKeyCreation", "AllowKMSKeyManagement", "AllowKMSAliasManagement"], s.Sid)
    ]) == 3
    error_message = "A role infra precisa criar e gerenciar chaves KMS e aliases do produto."
  }
  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement :
      contains(flatten([s.Action]), "kms:CreateKey") && s.Condition.StringEquals["aws:RequestTag/Product"] == var.product
      if s.Sid == "AllowKMSKeyCreation"
    ])
    error_message = "kms:CreateKey só com a tag Product do produto na requisição."
  }
  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement :
      contains(flatten([s.Action]), "kms:PutKeyPolicy") && s.Condition.StringEquals["aws:ResourceTag/Product"] == var.product
      if s.Sid == "AllowKMSKeyManagement"
    ])
    error_message = "A gestão de chaves KMS vale só para chaves com a tag Product do produto."
  }
  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement :
      alltrue([for r in flatten([s.Resource]) : endswith(r, "alias/${var.product}-*")])
      if s.Sid == "AllowKMSAliasManagement"
    ])
    error_message = "A gestão de aliases vale só para alias/<product>-*."
  }
  assert {
    # Qualquer ação kms: fora dos statements de uso/leitura precisa de Condition
    # ou, no caso do alias, de resource restrito a alias/<product>-*.
    condition = length([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement : s
      if !contains(["AllowKMSUsage", "AllowKMSCreateGrantForAWSServices"], s.Sid)
      && anytrue([for a in flatten([s.Action]) : startswith(a, "kms:")])
      && !can(s.Condition)
      && !alltrue([for r in flatten([s.Resource]) : endswith(r, "alias/${var.product}-*")])
    ]) == 0
    error_message = "Nenhum statement pode conceder gestão de KMS sem condição (exceto aliases do produto)."
  }
  assert {
    # Impede marcar com Product=<product> uma chave já etiquetada por outro produto.
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.infra_deploy_policy.policy).Statement :
      try(s.Condition.Null["aws:ResourceTag/Product"], "") == "true"
      if s.Sid == "AllowKMSKeyCreation"
    ])
    error_message = "A criação de chave KMS só pode etiquetar chaves sem a tag Product."
  }
}
