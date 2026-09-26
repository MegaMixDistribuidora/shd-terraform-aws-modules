mock_provider "aws" {
  # O mock gera strings aleatórias; o provider valida o formato do ARN usado no access log.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:sa-east-1:123456789012:log-group:/aws/apigateway/megamix-api"
    }
  }
}

variables {
  name        = "megamix-api"
  product     = "megamix"
  environment = "dev"
  tags        = { Repository = "github.com/MegaMixDistribuidora/aws-megamix-infra-platform" }

  cors_allowed_origins = ["https://dev.danhenrique.com.br", "http://localhost:3000"]

  jwt_authorizers = {
    customers = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_AAAAAAAAA", audience = ["client-loja"] }
    staff     = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_BBBBBBBBB", audience = ["client-painel"] }
  }

  domain_name     = "api.dev.danhenrique.com.br"
  certificate_arn = "arn:aws:acm:sa-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  zone_id         = "Z0123456789ABCDEFGHIJ"
}

run "creates_http_api_with_default_stage" {
  command = apply # mock_provider: nada é criado na AWS

  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP"
    error_message = "A API deve ser HTTP (ADR-03)."
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.name == "$default" && aws_apigatewayv2_stage.default.auto_deploy
    error_message = "A stage deve ser $default com auto_deploy, para as rotas dos serviços entrarem no ar sem deploy."
  }
  assert {
    condition     = aws_apigatewayv2_stage.default.default_route_settings[0].throttling_burst_limit == 200 && aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit == 100
    error_message = "Throttling padrão deve ser burst 200 e 100 req/s."
  }
  assert {
    condition     = aws_cloudwatch_log_group.access.retention_in_days == 30
    error_message = "Retenção padrão do access log deve ser 30 dias."
  }
  assert {
    condition     = aws_apigatewayv2_api.this.tags["Repository"] == "github.com/MegaMixDistribuidora/aws-megamix-infra-platform" && aws_apigatewayv2_api.this.tags["ManagedBy"] == "terraform"
    error_message = "As tags recebidas devem ser mescladas às do módulo."
  }
}

run "one_jwt_authorizer_per_map_entry" {
  command = apply # mock_provider

  assert {
    condition     = length(aws_apigatewayv2_authorizer.jwt) == 2
    error_message = "Deve existir um authorizer por item de jwt_authorizers."
  }
  assert {
    condition     = aws_apigatewayv2_authorizer.jwt["staff"].authorizer_type == "JWT" && aws_apigatewayv2_authorizer.jwt["staff"].jwt_configuration[0].issuer == "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_BBBBBBBBB"
    error_message = "O authorizer staff deve ser JWT com o issuer da pool de staff."
  }
  assert {
    condition     = toset(keys(output.authorizer_ids)) == toset(["customers", "staff"])
    error_message = "authorizer_ids deve ter uma chave por authorizer."
  }
}

run "custom_domain_mapped_to_default_stage" {
  command = apply # mock_provider

  assert {
    condition     = aws_apigatewayv2_domain_name.this.domain_name_configuration[0].endpoint_type == "REGIONAL" && aws_apigatewayv2_domain_name.this.domain_name_configuration[0].security_policy == "TLS_1_2"
    error_message = "Domínio deve ser regional com TLS 1.2."
  }
  assert {
    condition     = aws_apigatewayv2_api_mapping.this.stage == aws_apigatewayv2_stage.default.id
    error_message = "O domínio deve mapear para a stage $default."
  }
  assert {
    condition     = aws_route53_record.alias.name == "api.dev.danhenrique.com.br" && aws_route53_record.alias.type == "A"
    error_message = "Alias A no Route53 com o nome do domínio."
  }
  assert {
    condition     = output.domain_name == "api.dev.danhenrique.com.br"
    error_message = "Output domain_name deve devolver o domínio."
  }
}

run "access_log_without_token_or_body" {
  command = apply # mock_provider

  assert {
    condition     = contains(keys(jsondecode(aws_apigatewayv2_stage.default.access_log_settings[0].format)), "requestId")
    error_message = "O access log deve ser JSON com requestId."
  }
  assert {
    condition     = !strcontains(lower(aws_apigatewayv2_stage.default.access_log_settings[0].format), "authorization") && !strcontains(lower(aws_apigatewayv2_stage.default.access_log_settings[0].format), "body")
    error_message = "O access log não pode conter cabeçalho Authorization nem corpo (RNF-07)."
  }
}

run "rejects_wildcard_origin_among_others" {
  command = plan

  variables {
    cors_allowed_origins = ["https://dev.danhenrique.com.br", "*"]
  }

  expect_failures = [var.cors_allowed_origins]
}

run "rejects_empty_origin_list" {
  command = plan

  variables {
    cors_allowed_origins = []
  }

  expect_failures = [var.cors_allowed_origins]
}

run "rejects_empty_authorizers" {
  command = plan

  variables {
    jwt_authorizers = {}
  }

  expect_failures = [var.jwt_authorizers]
}
