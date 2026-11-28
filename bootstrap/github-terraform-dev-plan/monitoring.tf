module "extensions" {
  source = "../../modules/github-terraform-extensions"

  environment       = var.environment
  role_type         = "plan"
  role_name         = module.github_terraform_dev_plan.role_name
  name_prefix       = var.name_prefix
  aws_region        = var.aws_region
  aws_account_id    = data.aws_caller_identity.current.account_id
  state_bucket_name = var.state_bucket_name
  common_tags       = local.common_tags
}

moved {
  from = aws_iam_policy.monitoring
  to   = module.extensions.aws_iam_policy.monitoring[0]
}

moved {
  from = aws_iam_role_policy_attachment.monitoring
  to   = module.extensions.aws_iam_role_policy_attachment.monitoring[0]
}
