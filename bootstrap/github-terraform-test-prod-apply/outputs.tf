output "github_terraform_test_prod_apply_role_arns" {
  description = "Apply role ARNs keyed by environment."
  value       = { for environment, role in module.github_terraform_apply : environment => role.role_arn }
}
