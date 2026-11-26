output "role_arn" {
  description = "GitHub Actions OIDC role ARN for read-only manual DEV plans."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the GitHub Actions OIDC DEV plan role."
  value       = aws_iam_role.this.name
}
