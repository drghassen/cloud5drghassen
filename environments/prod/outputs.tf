output "environment" {
  description = "Environment name."
  value       = var.environment
}

output "alb_url" {
  description = "Public URL of the Nginx demonstration."
  value       = "${var.enable_https ? "https" : "http"}://${module.load_balancer.alb_dns_name}"
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = module.load_balancer.alb_dns_name
}

output "autoscaling_group_name" {
  description = "Name of the web Auto Scaling group."
  value       = module.compute.autoscaling_group_name
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs hosting the ALB."
  value       = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs hosting EC2."
  value       = module.network.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs hosting RDS."
  value       = module.network.private_db_subnet_ids
}

output "database_endpoint" {
  description = "Private RDS endpoint."
  value       = module.database.db_endpoint
}

output "database_master_user_secret_arn" {
  description = "ARN of the AWS-managed secret containing the generated RDS master password."
  value       = module.database.master_user_secret_arn
}

output "storage_bucket_name" {
  description = "Name of the private S3 storage bucket."
  value       = module.storage.bucket_name
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs used for controlled private subnet egress."
  value       = module.network.nat_gateway_ids
}
