output "role_arn" {
  description = "GitHub Actions OIDC role ARN for the approved environment apply."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the GitHub Actions OIDC environment apply role."
  value       = aws_iam_role.this.name
}
