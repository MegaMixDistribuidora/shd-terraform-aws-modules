locals {

  base_template_variables = {
    account_id      = data.aws_caller_identity.current.account_id
    product         = var.product
    environment     = var.environment
    github_org      = var.github_org
    github_oidc_arn = aws_iam_openid_connect_provider.github.arn
    repository      = var.repository
  }

  template_variables = merge(local.base_template_variables, {
    boundary_arn = aws_iam_policy.shared_boundary.arn
  })

  tags = {
    ManagedBy  = "terraform"
    Repository = var.repository
  }
}
