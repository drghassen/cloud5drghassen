variable "environment" {
  description = "Environment whose IAM extension resources are managed."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}

variable "role_type" {
  description = "GitHub Terraform role type receiving the extensions."
  type        = string

  validation {
    condition     = contains(["plan", "apply"], var.role_type)
    error_message = "role_type must be plan or apply."
  }
}

variable "role_name" {
  description = "Existing environment-scoped GitHub Terraform role name."
  type        = string

  validation {
    condition     = var.role_name == "${var.name_prefix}-github-terraform-${var.role_type}"
    error_message = "role_name must match name_prefix and role_type exactly."
  }
}

variable "name_prefix" {
  description = "Environment resource prefix; it must match environment."
  type        = string

  validation {
    condition     = var.name_prefix == "cloud5-infra-${var.environment}"
    error_message = "name_prefix must exactly match environment."
  }
}

variable "aws_region" {
  description = "AWS region containing the scoped resources."
  type        = string

  validation {
    condition     = var.aws_region == "eu-west-1"
    error_message = "This project permits IAM extensions only in eu-west-1."
  }
}

variable "aws_account_id" {
  description = "AWS account that owns the scoped resources."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "state_bucket_name" {
  description = "Approved private state bucket used for diagnostics."
  type        = string

  validation {
    condition     = var.state_bucket_name == "cloud5-terraform-drghassen-state-326553917564"
    error_message = "state_bucket_name must be the approved Cloud5 private state bucket."
  }
}

variable "common_tags" {
  description = "Required ownership and management tags for managed policies."
  type        = map(string)

  validation {
    condition = (
      try(var.common_tags.Project, null) == "terraform-cloud-project" &&
      try(var.common_tags.Owner, null) == "drghassen" &&
      try(var.common_tags.ManagedBy, null) == "Terraform" &&
      try(var.common_tags.Environment, null) == var.environment &&
      try(var.common_tags.Component, null) == "github-terraform-${var.environment}-${var.role_type}"
    )
    error_message = "common_tags must contain the required Project, Owner, ManagedBy, Environment, and Component values."
  }
}

variable "enable_monitoring" {
  description = "Whether to create and attach the scoped CloudWatch policy."
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Whether to create and attach the scoped SNS policy."
  type        = bool
  default     = true
}

variable "enable_diagnostics" {
  description = "Whether to create and attach the APPLY-only encrypted S3 diagnostics policy."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_diagnostics || var.role_type == "apply"
    error_message = "Diagnostics can be enabled only for an apply role."
  }
}
