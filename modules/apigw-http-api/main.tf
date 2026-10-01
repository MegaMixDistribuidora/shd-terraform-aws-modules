resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"
  description   = "Shared HTTP API - ${var.product} ${var.environment}"

  dynamic "cors_configuration" {
    for_each = length(var.cors_allowed_origins) > 0 ? [1] : []

    content {
      allow_origins = var.cors_allowed_origins
      allow_methods = var.cors_allowed_methods
      allow_headers = var.cors_allowed_headers
      max_age       = 3600
    }
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
  count = var.domain_name == null ? 0 : 1

  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = local.tags
}

resource "aws_apigatewayv2_api_mapping" "this" {
  count = var.domain_name == null ? 0 : 1

  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "alias" {
  count = var.domain_name == null ? 0 : 1

  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

moved {
  from = aws_apigatewayv2_domain_name.this
  to   = aws_apigatewayv2_domain_name.this[0]
}

moved {
  from = aws_apigatewayv2_api_mapping.this
  to   = aws_apigatewayv2_api_mapping.this[0]
}

moved {
  from = aws_route53_record.alias
  to   = aws_route53_record.alias[0]
}
