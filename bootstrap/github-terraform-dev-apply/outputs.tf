output "github_terraform_dev_apply_role_arn" {
  description = "ARN to set as the AWS_TERRAFORM_DEV_APPLY_ROLE_ARN GitHub environment variable."
  value       = module.github_terraform_dev_apply.role_arn
}
