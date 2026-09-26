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
