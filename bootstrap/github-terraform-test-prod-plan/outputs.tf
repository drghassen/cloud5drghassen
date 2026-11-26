output "github_terraform_test_prod_plan_role_arns" {
  description = "Read-only plan role ARNs keyed by environment."
  value       = { for environment, role in module.github_terraform_plan : environment => role.role_arn }
}
