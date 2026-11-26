variable "aws_region" {
  description = "AWS region used by this environment."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = var.aws_region == "eu-west-1"
    error_message = "This project is configured for eu-west-1."
  }
}

variable "environment" {
  description = "Environment name; fixed for this root module."
  type        = string
  default     = "test"

  validation {
    condition     = var.environment == "test"
    error_message = "The environments/test root accepts only environment = test."
  }
}

variable "project_name" {
  description = "Project tag applied to resources."
  type        = string
  default     = "terraform-cloud-project"
}

variable "resource_name_prefix" {
  description = "Short unique prefix used in AWS resource names."
  type        = string
  default     = "cloud5-infra-test"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,25}$", var.resource_name_prefix))
    error_message = "resource_name_prefix must be lowercase letters, digits, or hyphens and at most 25 characters."
  }
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "drghassen"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR block."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16") && cidrsubnet(var.vpc_cidr, 0, 0) == var.vpc_cidr
    error_message = "vpc_cidr must be a canonical IPv4 /16 block."
  }
}

variable "instance_type" {
  description = "EC2 instance type used by the web Auto Scaling group."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances; at least two are required."
  type        = number
  default     = 2

  validation {
    condition     = var.min_size >= 2
    error_message = "min_size must be at least two."
  }
}

variable "desired_capacity" {
  description = "Initial desired number of instances."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must be between min_size and max_size."
  }
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4

  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be greater than or equal to min_size."
  }
}

variable "db_instance_class" {
  description = "RDS PostgreSQL instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways; one reduces TEST cost, two provide per-AZ egress."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2], var.nat_gateway_count)
    error_message = "nat_gateway_count must be one or two."
  }
}

variable "db_backup_retention_period" {
  description = "RDS automated backup retention in days."
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable RDS Multi-AZ standby."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Prevent accidental RDS deletion."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the RDS final snapshot on destroy; use only for disposable environments."
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Prevent accidental ALB deletion."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS and redirect HTTP to HTTPS; requires an ACM certificate."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in eu-west-1 when HTTPS is enabled."
  type        = string
  default     = ""
}
