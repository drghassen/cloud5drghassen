output "role_arn" {
  description = "GitHub Actions OIDC role ARN for read-only environment plans."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the GitHub Actions OIDC environment plan role."
  value       = aws_iam_role.this.name
}
