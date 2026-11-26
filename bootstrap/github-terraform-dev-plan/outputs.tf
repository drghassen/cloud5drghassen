output "github_terraform_dev_plan_role_arn" {
  description = "ARN to set as the AWS_TERRAFORM_DEV_PLAN_ROLE_ARN GitHub environment variable."
  value       = module.github_terraform_dev_plan.role_arn
}
