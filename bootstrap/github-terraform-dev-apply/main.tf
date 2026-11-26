terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Component   = "github-terraform-dev-apply"
  }
  oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

module "github_terraform_dev_apply" {
  source = "../../modules/github-terraform-apply"

  name_prefix          = var.name_prefix
  common_tags          = local.common_tags
  project_name         = var.project_name
  environment          = var.environment
  github_environment   = var.github_environment
  oidc_provider_arn    = local.oidc_provider_arn
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
  github_repository    = var.github_repository
  aws_region           = var.aws_region
  aws_account_id       = data.aws_caller_identity.current.account_id
  state_bucket_arn     = "arn:aws:s3:::${var.state_bucket_name}"
  state_key            = var.state_key
}
