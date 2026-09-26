provider "aws" {
  region = "sa-east-1"
}

module "api" {
  source = "../../modules/apigw-http-api"

  name        = "megamix-api"
  product     = "megamix"
  environment = "dev"

  cors_allowed_origins = ["https://dev.example.com", "http://localhost:3000"]

  jwt_authorizers = {
    customers = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_AAAAAAAAA", audience = ["client-loja"] }
    staff     = { issuer = "https://cognito-idp.sa-east-1.amazonaws.com/sa-east-1_BBBBBBBBB", audience = ["client-painel"] }
  }

  domain_name     = "api.dev.example.com"
  certificate_arn = "arn:aws:acm:sa-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  zone_id         = "Z0123456789ABCDEFGHIJ"

  tags = { ManagedBy = "terraform" }
}
