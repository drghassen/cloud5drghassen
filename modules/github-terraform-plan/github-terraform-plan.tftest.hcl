mock_provider "aws" {}

run "role_is_restricted_to_main_and_pr_plans" {
  command = plan

  variables {
    name_prefix          = "cloud5-infra-dev"
    common_tags          = { Project = "terraform-cloud-project", Environment = "dev", Owner = "drghassen", ManagedBy = "Terraform" }
    github_environment   = "dev-plan"
    github_ref_patterns  = ["refs/heads/main", "refs/pull/*/merge"]
    oidc_provider_arn    = "arn:aws:iam::326553917564:oidc-provider/token.actions.githubusercontent.com"
    github_owner_id      = "128297499"
    github_repository_id = "1473229803"
    github_repository    = "drghassen/cloud5drghassen"
    aws_region           = "eu-west-1"
    aws_account_id       = "326553917564"
    state_bucket_arn     = "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564"
    state_key            = "cloud5/infrastructure/dev/terraform.tfstate"
  }

  assert {
    condition = (
      strcontains(aws_iam_role.this.assume_role_policy, "repo:drghassen/cloud5drghassen:environment:dev-plan") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/pull/*/merge") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/heads/main") &&
      strcontains(aws_iam_role.this.assume_role_policy, "1473229803") &&
      strcontains(aws_iam_role.this.assume_role_policy, "128297499")
    )
    error_message = "The role must trust only this repository's dev-plan jobs from main and pull requests."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role.this.assume_role_policy).Statement : statement if statement.Effect == "Allow"]).Condition.StringLike["token.actions.githubusercontent.com:ref"] ==
      ["refs/heads/main", "refs/pull/*/merge"]
    )
    error_message = "The read-only plan role must not trust arbitrary branches."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadTerraformState"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/dev/terraform.tfstate" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageOnlyTerraformLock"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/dev/terraform.tfstate.tflock"
    )
    error_message = "State reads and lock-file writes must be restricted to the exact DEV state key."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadRegionalInfrastructure"]).Resource == "*" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadRegionalInfrastructure"]).Condition.StringEquals["aws:RequestedRegion"] == "eu-west-1" &&
      alltrue([
        for action in one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadRegionalInfrastructure"]).Action :
        can(regex("^(autoscaling|ec2|elasticloadbalancing|rds):Describe", action))
      ])
    )
    error_message = "Wildcard resources are limited to read-only regional Describe actions because these APIs do not support resource-level permissions."
  }

  assert {
    condition = (
      !strcontains(aws_iam_role_policy.this.policy, "secretsmanager:GetSecretValue") &&
      !strcontains(aws_iam_role_policy.this.policy, "iam:PassRole") &&
      !strcontains(aws_iam_role_policy.this.policy, "\"Action\":\"*\"") &&
      !strcontains(aws_iam_role_policy.this.policy, "codebuild:")
    )
    error_message = "The plan role must not read secrets, pass roles, use wildcard actions, or access workload release services."
  }
}

run "role_is_scoped_to_test_environment" {
  command = plan

  variables {
    name_prefix          = "cloud5-infra-test"
    common_tags          = { Project = "terraform-cloud-project", Environment = "test", Owner = "drghassen", ManagedBy = "Terraform" }
    github_environment   = "test-plan"
    github_ref_patterns  = ["refs/heads/main", "refs/pull/*/merge"]
    oidc_provider_arn    = "arn:aws:iam::326553917564:oidc-provider/token.actions.githubusercontent.com"
    github_owner_id      = "128297499"
    github_repository_id = "1473229803"
    github_repository    = "drghassen/cloud5drghassen"
    aws_region           = "eu-west-1"
    aws_account_id       = "326553917564"
    state_bucket_arn     = "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564"
    state_key            = "cloud5/infrastructure/test/terraform.tfstate"
  }

  assert {
    condition = (
      strcontains(aws_iam_role.this.assume_role_policy, "repo:drghassen/cloud5drghassen:environment:test-plan") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/heads/main") &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadTerraformState"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/test/terraform.tfstate" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageOnlyTerraformLock"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/test/terraform.tfstate.tflock"
    )
    error_message = "The TEST plan role must trust only test-plan on main and read only TEST state."
  }
}

run "role_is_scoped_to_prod_environment" {
  command = plan

  variables {
    name_prefix          = "cloud5-infra-prod"
    common_tags          = { Project = "terraform-cloud-project", Environment = "prod", Owner = "drghassen", ManagedBy = "Terraform" }
    github_environment   = "prod-plan"
    github_ref_patterns  = ["refs/heads/main", "refs/pull/*/merge"]
    oidc_provider_arn    = "arn:aws:iam::326553917564:oidc-provider/token.actions.githubusercontent.com"
    github_owner_id      = "128297499"
    github_repository_id = "1473229803"
    github_repository    = "drghassen/cloud5drghassen"
    aws_region           = "eu-west-1"
    aws_account_id       = "326553917564"
    state_bucket_arn     = "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564"
    state_key            = "cloud5/infrastructure/prod/terraform.tfstate"
  }

  assert {
    condition = (
      strcontains(aws_iam_role.this.assume_role_policy, "repo:drghassen/cloud5drghassen:environment:prod-plan") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/heads/main") &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadTerraformState"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/prod/terraform.tfstate" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageOnlyTerraformLock"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/prod/terraform.tfstate.tflock"
    )
    error_message = "The PROD plan role must trust only prod-plan on main and read only PROD state."
  }
}
