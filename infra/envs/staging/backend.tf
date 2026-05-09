terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "urlshort-tfstate-dsolanki-8492"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "urlshort-tflock"
    encrypt        = true
  }
}
