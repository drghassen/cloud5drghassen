variable "name_prefix" {
  description = "Prefix used to name database resources."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to database resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID hosting the database."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private database subnet IDs in separate Availability Zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) >= 2
    error_message = "At least two distinct private database subnets are required."
  }
}

variable "web_security_group_id" {
  description = "Security group allowed to connect to PostgreSQL."
  type        = string
}

variable "db_instance_class" {
  description = "RDS PostgreSQL instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "cloud5db"
}

variable "db_username" {
  description = "RDS master username; its generated password is stored by AWS Secrets Manager."
  type        = string
  default     = "cloud5admin"
}

variable "allocated_storage" {
  description = "Initial allocated database storage in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "PostgreSQL RDS storage must be at least 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling limit in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must be greater than or equal to allocated_storage."
  }
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35 days."
  }
}

variable "multi_az" {
  description = "Whether to deploy RDS with a synchronous standby in another Availability Zone."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to prevent accidental RDS deletion."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when destroying RDS; use only for disposable environments."
  type        = bool
  default     = true
}
