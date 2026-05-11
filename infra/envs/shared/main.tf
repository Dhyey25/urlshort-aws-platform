terraform {
  backend "s3" {
    bucket         = "urlshort-tfstate-dsolanki-8492"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "urlshort-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  github_org  = "Dhyey25"
  github_repo = "urlshort-aws-platform"
}

output "github_role_arn" {
  value = module.github_oidc.role_arn
}
