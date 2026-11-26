output "db_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "RDS endpoint, including port."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "RDS database hostname."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS database port."
  value       = aws_db_instance.this.port
}

output "db_security_group_id" {
  description = "Security group ID protecting the RDS instance."
  value       = aws_security_group.database.id
}

output "master_user_secret_arn" {
  description = "ARN of the AWS-managed secret containing the generated RDS master password."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
