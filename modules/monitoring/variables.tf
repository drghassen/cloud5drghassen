variable "name_prefix" {
  description = "Environment-specific resource name prefix."
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the monitored resources."
  type        = string
}

variable "common_tags" {
  description = "Mandatory project ownership tags."
  type        = map(string)
}

variable "alb_arn" {
  description = "Application Load Balancer ARN."
  type        = string
}

variable "target_group_arn" {
  description = "Application Load Balancer target group ARN."
  type        = string
}

variable "autoscaling_group_name" {
  description = "Web Auto Scaling Group name."
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS database instance identifier."
  type        = string
}

variable "minimum_healthy_hosts" {
  description = "Minimum expected number of healthy web targets."
  type        = number
  default     = 2

  validation {
    condition     = var.minimum_healthy_hosts >= 1
    error_message = "At least one healthy host is required."
  }
}

variable "alarm_actions" {
  description = "Approved SNS topic ARNs for alarm notifications."
  type        = list(string)
  default     = []
}
