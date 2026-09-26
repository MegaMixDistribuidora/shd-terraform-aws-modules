locals {
  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Product   = var.product
  })

  # No headers and no request/response body: tokens and personal data stay out of logs (RNF-07).
  access_log_format = {
    requestId               = "$context.requestId"
    ip                      = "$context.identity.sourceIp"
    requestTime             = "$context.requestTime"
    httpMethod              = "$context.httpMethod"
    routeKey                = "$context.routeKey"
    status                  = "$context.status"
    protocol                = "$context.protocol"
    responseLength          = "$context.responseLength"
    integrationErrorMessage = "$context.integrationErrorMessage"
    authorizerError         = "$context.authorizer.error"
  }
}
