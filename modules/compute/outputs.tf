output "autoscaling_group_name" {
  description = "Name of the web Auto Scaling group."
  value       = aws_autoscaling_group.web.name
}

output "autoscaling_group_arn" {
  description = "ARN of the web Auto Scaling group."
  value       = aws_autoscaling_group.web.arn
}

output "launch_template_id" {
  description = "ID of the web Launch Template."
  value       = aws_launch_template.web.id
}

output "launch_template_version" {
  description = "Latest Launch Template version used by the Auto Scaling group."
  value       = aws_launch_template.web.latest_version
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI selected for the web instances."
  value       = data.aws_ami.amazon_linux.id
}
