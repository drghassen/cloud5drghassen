mock_provider "aws" {}

run "role_is_restricted_to_dev_main" {
  command = plan

  variables {
    name_prefix          = "cloud5-infra-dev"
    common_tags          = { Project = "terraform-cloud-project", Environment = "dev", Owner = "drghassen", ManagedBy = "Terraform" }
    project_name         = "terraform-cloud-project"
    environment          = "dev"
    github_environment   = "dev"
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
      strcontains(aws_iam_role.this.assume_role_policy, "repo:drghassen/cloud5drghassen:environment:dev") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/heads/main") &&
      strcontains(aws_iam_role.this.assume_role_policy, "1473229803") &&
      strcontains(aws_iam_role.this.assume_role_policy, "128297499") &&
      !strcontains(aws_iam_role.this.assume_role_policy, "dev-plan")
    )
    error_message = "The role must trust only the new repository's DEV environment on main."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadAndWriteOnlyDevState"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/dev/terraform.tfstate" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageOnlyDevStateLock"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/dev/terraform.tfstate.tflock"
    )
    error_message = "State access must be limited to the exact DEV state object and lock."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "PassOnlyProjectInstanceRoleToEc2"]).Resource ==
      "arn:aws:iam::326553917564:role/cloud5-infra-dev-web-instance-role" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "PassOnlyProjectInstanceRoleToEc2"]).Condition.StringEquals["iam:PassedToService"] ==
      "ec2.amazonaws.com"
    )
    error_message = "iam:PassRole must be limited to the DEV EC2 instance role."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadRegionalInfrastructure"]).Resource == "*" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadRegionalInfrastructure"]).Condition.StringEquals["aws:RequestedRegion"] == "eu-west-1" &&
      alltrue([
        for action in one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadRegionalInfrastructure"]).Action :
        can(regex("^(autoscaling|ec2|elasticloadbalancing|rds):Describe", action))
      ]) &&
      alltrue([
        for statement in jsondecode(aws_iam_role_policy.this.policy).Statement :
        try(statement.Resource != "*" || contains(["ReadRegionalInfrastructure", "ReadCallerIdentity"], statement.Sid), true)
      ])
    )
    error_message = "Wildcard resources are permitted only for regional, read-only Describe APIs."
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "CreateTaggedEc2Resources"]).Condition.StringEquals["aws:RequestTag/Environment"] == "dev" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageTaggedEc2Resources"]).Condition.StringEquals["aws:ResourceTag/Environment"] == "dev"
    )
    error_message = "EC2 create and mutation permissions must be restricted to DEV-tagged resources."
  }

  assert {
    condition = (
      !strcontains(aws_iam_role_policy.this.policy, "\"Action\":\"*\"") &&
      !strcontains(aws_iam_role_policy.this.policy, "AdministratorAccess") &&
      !strcontains(aws_iam_role_policy.this.policy, "secretsmanager:GetSecretValue") &&
      !strcontains(aws_iam_role_policy.this.policy, "iam:CreateServiceLinkedRole") &&
      length(aws_iam_role_policy.this.policy) < 10240
    )
    error_message = "The DEV apply role must stay below IAM's inline-policy limit and must not receive administrator access, secret reads, or service-linked role creation."
  }
}

run "test_apply_role_is_scoped_to_test_state_and_environment" {
  command = plan

  variables {
    name_prefix          = "cloud5-infra-test"
    common_tags          = { Project = "terraform-cloud-project", Environment = "test", Owner = "drghassen", ManagedBy = "Terraform" }
    project_name         = "terraform-cloud-project"
    environment          = "test"
    github_environment   = "test"
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
      strcontains(aws_iam_role.this.assume_role_policy, "repo:drghassen/cloud5drghassen:environment:test") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/heads/main") &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadAndWriteOnlyTestState"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/test/terraform.tfstate" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageOnlyTestStateLock"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/test/terraform.tfstate.tflock"
    )
    error_message = "The TEST apply role must trust only the TEST environment on main and update only TEST state."
  }
}

run "prod_apply_role_is_scoped_to_prod_state_and_environment" {
  command = plan

  variables {
    name_prefix          = "cloud5-infra-prod"
    common_tags          = { Project = "terraform-cloud-project", Environment = "prod", Owner = "drghassen", ManagedBy = "Terraform" }
    project_name         = "terraform-cloud-project"
    environment          = "prod"
    github_environment   = "prod"
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
      strcontains(aws_iam_role.this.assume_role_policy, "repo:drghassen/cloud5drghassen:environment:prod") &&
      strcontains(aws_iam_role.this.assume_role_policy, "refs/heads/main") &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ReadAndWriteOnlyProdState"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/prod/terraform.tfstate" &&
      one([for statement in jsondecode(aws_iam_role_policy.this.policy).Statement : statement if statement.Sid == "ManageOnlyProdStateLock"]).Resource ==
      "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/prod/terraform.tfstate.tflock"
    )
    error_message = "The PROD apply role must trust only the PROD environment on main and update only PROD state."
  }
}
