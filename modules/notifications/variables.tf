variable "name_prefix" {
  description = "Environment-specific resource name prefix."
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the SNS topic."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account owning the SNS topic."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must contain 12 digits."
  }
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS encryption key."
  type        = string
}

variable "common_tags" {
  description = "Mandatory project ownership tags."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Owner", "Project", "Environment", "ManagedBy"] :
      try(trimspace(var.common_tags[key]) != "", false)
    ])

    error_message = "Mandatory ownership tags must be present."
  }
}
