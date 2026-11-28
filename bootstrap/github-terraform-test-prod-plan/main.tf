provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Project   = var.project_name
    Owner     = var.owner
    ManagedBy = "Terraform"
  }

  environments = {
    test = {
      github_environment = "test-plan"
      name_prefix        = "cloud5-infra-test"
      state_key          = "cloud5/infrastructure/test/terraform.tfstate"
    }
    prod = {
      github_environment = "prod-plan"
      name_prefix        = "cloud5-infra-prod"
      state_key          = "cloud5/infrastructure/prod/terraform.tfstate"
    }
  }
}

module "github_terraform_plan" {
  for_each = local.environments
  source   = "../../modules/github-terraform-plan"

  name_prefix = each.value.name_prefix
  common_tags = merge(local.common_tags, {
    Environment = each.key
    Component   = "github-terraform-${each.key}-plan"
  })

  github_environment   = each.value.github_environment
  github_ref_patterns  = ["refs/heads/main", "refs/pull/*/merge"]
  oidc_provider_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
  github_repository    = var.github_repository
  aws_region           = var.aws_region
  aws_account_id       = data.aws_caller_identity.current.account_id
  state_bucket_arn     = "arn:aws:s3:::${var.state_bucket_name}"
  state_key            = each.value.state_key
}

# PROD remains intentionally outside this refactoring. These extensions are
# created only for the existing TEST role in the shared bootstrap state.
module "test_extensions" {
  source = "../../modules/github-terraform-extensions"

  environment       = "test"
  role_type         = "plan"
  role_name         = module.github_terraform_plan["test"].role_name
  name_prefix       = local.environments.test.name_prefix
  aws_region        = var.aws_region
  aws_account_id    = data.aws_caller_identity.current.account_id
  state_bucket_name = var.state_bucket_name
  common_tags = merge(local.common_tags, {
    Environment = "test"
    Component   = "github-terraform-test-plan"
  })
}
