output "role_arn" {
  description = "GitHub Actions OIDC role ARN for DEV infrastructure apply."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the GitHub Actions OIDC DEV apply role."
  value       = aws_iam_role.this.name
}
