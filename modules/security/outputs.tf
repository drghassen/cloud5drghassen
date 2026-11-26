output "alb_security_group_id" {
  description = "Security group ID attached to the public ALB."
  value       = aws_security_group.alb.id
}

output "web_security_group_id" {
  description = "Security group ID attached to private web instances."
  value       = aws_security_group.web.id
}

output "web_instance_profile_name" {
  description = "Instance profile for private web instances."
  value       = aws_iam_instance_profile.web_instance.name
}

output "web_instance_role_arn" {
  description = "IAM role ARN assumed by private web instances."
  value       = aws_iam_role.web_instance.arn
}
