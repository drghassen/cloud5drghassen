variable "name_prefix" {
  description = "Prefix used to name the DEV role and its managed resources."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to the GitHub Actions role."
  type        = map(string)
}

variable "project_name" {
  description = "Project tag required for EC2 resource creation."
  type        = string
}

variable "environment" {
  description = "Environment tag used to scope the apply role."
  type        = string

  validation {
    condition     = var.environment == "dev"
    error_message = "This module instance provisions the DEV apply role only."
  }
}

variable "github_environment" {
  description = "GitHub environment allowed to assume the apply role."
  type        = string

  validation {
    condition     = var.github_environment == "dev"
    error_message = "The apply role trust must use the dev GitHub environment."
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
  description = "Region containing the DEV infrastructure."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID containing the infrastructure."
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the shared Terraform state bucket."
  type        = string
}

variable "state_key" {
  description = "Exact DEV Terraform state key the role may update."
  type        = string
}
