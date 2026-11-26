variable "name_prefix" {
  description = "Prefix used to name the environment Terraform plan role and managed infrastructure."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to the role."
  type        = map(string)
}

variable "github_environment" {
  description = "GitHub environment allowed to assume the plan role."
  type        = string

  validation {
    condition     = contains(["dev-plan", "test-plan", "prod-plan"], var.github_environment)
    error_message = "The plan role must use a supported environment-specific plan environment."
  }
}

variable "github_ref_patterns" {
  description = "Git reference patterns trusted for the plan role."
  type        = list(string)

  validation {
    condition     = length(var.github_ref_patterns) > 0 && alltrue([for pattern in var.github_ref_patterns : length(trimspace(pattern)) > 0])
    error_message = "At least one non-empty Git reference pattern is required."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the existing GitHub Actions OIDC provider."
  type        = string
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
}

variable "aws_region" {
  description = "Region containing the infrastructure to plan."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID containing the infrastructure."
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the existing Terraform state bucket."
  type        = string
}

variable "state_key" {
  description = "Exact environment state key the read-only plan role may read."
  type        = string
}
