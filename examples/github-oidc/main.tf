provider "aws" {
  region = "sa-east-1"
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  github_org  = "MegaMixDistribuidora"
  product     = "megamix"
  environment = "dev"
  repository  = "github.com/MegaMixDistribuidora/aws-megamix-infra"
  tags        = { ManagedBy = "terraform" }
}
