output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider created for GitHub Actions federation."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "oidc_provider_url" {
  description = "URL of the GitHub OIDC provider."
  value       = aws_iam_openid_connect_provider.github.url
}

output "shared_boundary_policy_arn" {
  description = "ARN of the IAM permission boundary policy used by deployed roles."
  value       = aws_iam_policy.shared_boundary.arn
}

output "infra_deployer_role_arn" {
  description = "ARN of the IAM role for GitHub infrastructure deployment."
  value       = aws_iam_role.infra_role.arn
}

output "infra_deployer_role_name" {
  description = "Name of the IAM role for GitHub infrastructure deployment."
  value       = aws_iam_role.infra_role.name
}

output "app_deployer_role_arn" {
  description = "ARN of the IAM role for GitHub application deployment."
  value       = aws_iam_role.app_role.arn
}

output "app_deployer_role_name" {
  description = "Name of the IAM role for GitHub application deployment."
  value       = aws_iam_role.app_role.name
}

output "infra_deploy_policy_id" {
  description = "ID of the inline policy attached to the infra deployer role."
  value       = aws_iam_role_policy.infra_deploy_policy.id
}

output "app_deploy_policy_id" {
  description = "ID of the inline policy attached to the app deployer role."
  value       = aws_iam_role_policy.app_deploy_policy.id
}
