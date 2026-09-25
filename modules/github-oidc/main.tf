data "aws_caller_identity" "current" {}

# --- OIDC Provider for GitHub Actions ---
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = merge(var.tags, local.tags)
}

# --- 1. PERMISSION BOUNDARIES (The Guardrails) ---

resource "aws_iam_policy" "shared_boundary" {
  name        = "${var.product}-SharedPolicyBoundary"
  description = "Maximum permissions for all roles created by infra and app deployers"

  policy = templatefile("${path.module}/boundary_templates/policies/shared_boundary_policy.tftpl", local.base_template_variables)

  tags = merge(var.tags, local.tags)
}

# --- 2. IAM ROLES (Segregated by Repository Prefix) ---

# Infra Deployer Role: Restricted by Infra Boundary
resource "aws_iam_role" "infra_role" {
  name = "${var.product}-GitHubInfraDeployerRole"

  assume_role_policy = templatefile("${path.module}/iam_templates/roles/infra_deployer_role.tftpl", local.template_variables)

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_role_policy" "infra_deploy_policy" {
  name = "${var.product}-InfraDeployPolicy"
  role = aws_iam_role.infra_role.id

  policy = templatefile("${path.module}/iam_templates/policies/infra_deploy_policy.tftpl", local.template_variables)
}

# App Deployer Role: Restricted by App Boundary
resource "aws_iam_role" "app_role" {
  name = "${var.product}-GitHubAppDeployerRole"

  assume_role_policy = templatefile("${path.module}/iam_templates/roles/app_deployer_role.tftpl", local.template_variables)

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_role_policy" "app_deploy_policy" {
  name = "${var.product}-AppDeployPolicy"
  role = aws_iam_role.app_role.id

  policy = templatefile("${path.module}/iam_templates/policies/app_deploy_policy.tftpl", local.template_variables)
}
