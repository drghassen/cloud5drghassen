variable "name_prefix" {
  description = "Prefix used to name compute resources."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to compute resources."
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type used by the web Auto Scaling group."
  type        = string
  default     = "t3.micro"
}

variable "web_security_group_id" {
  description = "Security group attached to the private web instances."
  type        = string
}

variable "instance_profile_name" {
  description = "EC2 instance profile used for Systems Manager access."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private application subnet IDs in separate Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) == 2 && length(distinct(var.private_subnet_ids)) == 2
    error_message = "Exactly two distinct private application subnets are required."
  }
}

variable "target_group_arn" {
  description = "HTTP target group ARN used by the web Auto Scaling group."
  type        = string
}

variable "min_size" {
  description = "Minimum number of web instances."
  type        = number
  default     = 2

  validation {
    condition     = var.min_size >= 2
    error_message = "At least two web instances are required for availability."
  }
}

variable "desired_capacity" {
  description = "Initial and maintained number of web instances."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must be between min_size and max_size."
  }
}

variable "max_size" {
  description = "Maximum number of web instances."
  type        = number
  default     = 4

  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be greater than or equal to min_size."
  }
}

variable "health_check_grace_period" {
  description = "Seconds to wait after launch before evaluating load balancer health."
  type        = number
  default     = 300

  validation {
    condition     = var.health_check_grace_period >= 0
    error_message = "health_check_grace_period cannot be negative."
  }
}

variable "cpu_target_utilization" {
  description = "Average CPU utilization target used for Auto Scaling."
  type        = number
  default     = 60

  validation {
    condition     = var.cpu_target_utilization >= 20 && var.cpu_target_utilization <= 80
    error_message = "cpu_target_utilization must be between 20 and 80."
  }
}

variable "root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}
