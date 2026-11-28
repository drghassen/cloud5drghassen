mock_provider "aws" {}

run "dev_plan_is_read_only_and_environment_scoped" {
  command = plan

  variables {
    environment       = "dev"
    role_type         = "plan"
    role_name         = "cloud5-infra-dev-github-terraform-plan"
    name_prefix       = "cloud5-infra-dev"
    aws_region        = "eu-west-1"
    aws_account_id    = "326553917564"
    state_bucket_name = "cloud5-terraform-drghassen-state-326553917564"
    common_tags       = { Project = "terraform-cloud-project", Environment = "dev", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-dev-plan" }
  }

  assert {
    condition = (
      aws_iam_policy.monitoring[0].name == "cloud5-infra-dev-github-terraform-plan-monitoring" &&
      one([for statement in jsondecode(aws_iam_policy.monitoring[0].policy).Statement : statement if statement.Sid == "ReadProjectDashboard"]).Resource == "arn:aws:cloudwatch::326553917564:dashboard/cloud5-infra-dev-operations" &&
      toset(flatten([for statement in jsondecode(aws_iam_policy.monitoring[0].policy).Statement : statement.Action])) == toset(["cloudwatch:GetDashboard", "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource"]) &&
      toset(flatten([for statement in jsondecode(aws_iam_policy.notifications[0].policy).Statement : statement.Action])) == toset(["sns:GetTopicAttributes", "sns:ListTagsForResource"]) &&
      aws_iam_role_policy_attachment.monitoring[0].role == "cloud5-infra-dev-github-terraform-plan" &&
      aws_iam_policy.monitoring[0].tags.Component == "github-terraform-dev-plan" &&
      !strcontains(aws_iam_policy.monitoring[0].policy, "PutMetricAlarm") &&
      !strcontains(aws_iam_policy.notifications[0].policy, "CreateTopic") &&
      !strcontains(aws_iam_policy.notifications[0].policy, "sns:Publish")
    )
    error_message = "DEV PLAN must have only its exact read-only CloudWatch and SNS permissions."
  }
}

run "dev_apply_preserves_existing_policy_contract_without_managed_diagnostics" {
  command = plan

  variables {
    environment       = "dev"
    role_type         = "apply"
    role_name         = "cloud5-infra-dev-github-terraform-apply"
    name_prefix       = "cloud5-infra-dev"
    aws_region        = "eu-west-1"
    aws_account_id    = "326553917564"
    state_bucket_name = "cloud5-terraform-drghassen-state-326553917564"
    common_tags       = { Project = "terraform-cloud-project", Environment = "dev", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-dev-apply" }
  }

  assert {
    condition = (
      strcontains(aws_iam_policy.monitoring[0].policy, "autoscaling:EnableMetricsCollection") &&
      strcontains(aws_iam_policy.monitoring[0].policy, "aws:RequestTag/Environment") &&
      strcontains(aws_iam_policy.notifications[0].policy, "sns:DeleteTopic") &&
      strcontains(aws_iam_policy.notifications[0].policy, "aws:ResourceTag/Environment") &&
      toset(flatten([for statement in jsondecode(aws_iam_policy.monitoring[0].policy).Statement : statement.Action])) == toset(["cloudwatch:GetDashboard", "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards", "cloudwatch:PutMetricAlarm", "cloudwatch:TagResource", "cloudwatch:DeleteAlarms", "autoscaling:EnableMetricsCollection", "autoscaling:DisableMetricsCollection"]) &&
      toset(flatten([for statement in jsondecode(aws_iam_policy.notifications[0].policy).Statement : statement.Action])) == toset(["sns:GetTopicAttributes", "sns:ListTagsForResource", "sns:CreateTopic", "sns:TagResource", "sns:SetTopicAttributes", "sns:DeleteTopic"]) &&
      aws_iam_role_policy_attachment.notifications[0].role == "cloud5-infra-dev-github-terraform-apply" &&
      aws_iam_policy.notifications[0].tags.Component == "github-terraform-dev-apply" &&
      length(aws_iam_policy.diagnostics) == 0
    )
    error_message = "DEV APPLY monitoring and notifications must preserve their conditions; diagnostics remain inline temporarily."
  }
}

run "test_plan_never_references_another_environment" {
  command = plan

  variables {
    environment       = "test"
    role_type         = "plan"
    role_name         = "cloud5-infra-test-github-terraform-plan"
    name_prefix       = "cloud5-infra-test"
    aws_region        = "eu-west-1"
    aws_account_id    = "326553917564"
    state_bucket_name = "cloud5-terraform-drghassen-state-326553917564"
    common_tags       = { Project = "terraform-cloud-project", Environment = "test", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-test-plan" }
  }

  assert {
    condition = (
      strcontains(aws_iam_policy.monitoring[0].policy, "cloud5-infra-test-healthy-hosts-low") &&
      strcontains(aws_iam_policy.notifications[0].policy, "cloud5-infra-test-alerts") &&
      !strcontains(aws_iam_policy.monitoring[0].policy, "cloud5-infra-dev") &&
      !strcontains(aws_iam_policy.notifications[0].policy, "cloud5-infra-prod") &&
      length(aws_iam_policy.diagnostics) == 0
    )
    error_message = "TEST PLAN resources must be read-only and isolated to TEST."
  }
}

run "test_apply_diagnostics_is_write_only_and_encrypted" {
  command = plan

  variables {
    environment        = "test"
    role_type          = "apply"
    role_name          = "cloud5-infra-test-github-terraform-apply"
    name_prefix        = "cloud5-infra-test"
    aws_region         = "eu-west-1"
    aws_account_id     = "326553917564"
    state_bucket_name  = "cloud5-terraform-drghassen-state-326553917564"
    common_tags        = { Project = "terraform-cloud-project", Environment = "test", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-test-apply" }
    enable_diagnostics = true
  }

  assert {
    condition = (
      one(jsondecode(aws_iam_policy.diagnostics[0].policy).Statement).Action == ["s3:PutObject"] &&
      one(jsondecode(aws_iam_policy.diagnostics[0].policy).Statement).Resource == "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/ci-diagnostics/v1/test/*" &&
      one(jsondecode(aws_iam_policy.diagnostics[0].policy).Statement).Condition.StringEquals["s3:x-amz-server-side-encryption"] == "AES256" &&
      !strcontains(aws_iam_policy.diagnostics[0].policy, "kms:") &&
      !strcontains(aws_iam_policy.diagnostics[0].policy, "iam:")
    )
    error_message = "TEST diagnostics must be an AES256-protected PutObject-only permission in the TEST prefix."
  }
}

run "prod_plan_simulation_is_isolated" {
  command = plan

  variables {
    environment       = "prod"
    role_type         = "plan"
    role_name         = "cloud5-infra-prod-github-terraform-plan"
    name_prefix       = "cloud5-infra-prod"
    aws_region        = "eu-west-1"
    aws_account_id    = "326553917564"
    state_bucket_name = "cloud5-terraform-drghassen-state-326553917564"
    common_tags       = { Project = "terraform-cloud-project", Environment = "prod", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-prod-plan" }
  }

  assert {
    condition     = strcontains(aws_iam_policy.notifications[0].policy, "cloud5-infra-prod-alerts") && !strcontains(aws_iam_policy.notifications[0].policy, "cloud5-infra-test")
    error_message = "PROD simulation must generate only PROD ARNs."
  }
}

run "prod_apply_simulation_can_disable_extensions" {
  command = plan

  variables {
    environment          = "prod"
    role_type            = "apply"
    role_name            = "cloud5-infra-prod-github-terraform-apply"
    name_prefix          = "cloud5-infra-prod"
    aws_region           = "eu-west-1"
    aws_account_id       = "326553917564"
    state_bucket_name    = "cloud5-terraform-drghassen-state-326553917564"
    common_tags          = { Project = "terraform-cloud-project", Environment = "prod", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-prod-apply" }
    enable_monitoring    = false
    enable_notifications = false
  }

  assert {
    condition     = length(aws_iam_policy.monitoring) == 0 && length(aws_iam_policy.notifications) == 0 && length(aws_iam_policy.diagnostics) == 0
    error_message = "Optional extensions must be absent when disabled."
  }
}

run "plan_role_cannot_enable_diagnostics" {
  command = plan

  variables {
    environment        = "test"
    role_type          = "plan"
    role_name          = "cloud5-infra-test-github-terraform-plan"
    name_prefix        = "cloud5-infra-test"
    aws_region         = "eu-west-1"
    aws_account_id     = "326553917564"
    state_bucket_name  = "cloud5-terraform-drghassen-state-326553917564"
    common_tags        = { Project = "terraform-cloud-project", Environment = "test", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-test-plan" }
    enable_diagnostics = true
  }

  expect_failures = [var.enable_diagnostics]
}

run "inconsistent_role_and_prefix_are_rejected" {
  command = plan

  variables {
    environment       = "test"
    role_type         = "plan"
    role_name         = "cloud5-infra-dev-github-terraform-plan"
    name_prefix       = "cloud5-infra-test"
    aws_region        = "eu-west-1"
    aws_account_id    = "326553917564"
    state_bucket_name = "cloud5-terraform-drghassen-state-326553917564"
    common_tags       = { Project = "terraform-cloud-project", Environment = "test", Owner = "drghassen", ManagedBy = "Terraform", Component = "github-terraform-test-plan" }
  }

  expect_failures = [var.role_name]
}
