variable "aws_region" {
  description = "AWS region containing the DEV deployment."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "AWS environment tag applied to the plan role."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This bootstrap configuration provisions only the DEV plan role."
  }
}

variable "github_environment" {
  description = "GitHub environment used by manually dispatched DEV Terraform plans."
  type        = string
  default     = "dev-plan"

  validation {
    condition     = var.github_environment == "dev-plan"
    error_message = "The plan role trust must use the dev-plan GitHub environment."
  }
}

variable "project_name" {
  description = "Project tag applied to the role."
  type        = string
  default     = "terraform-cloud-project"
}

variable "owner" {
  description = "Owner tag applied to the role."
  type        = string
  default     = "drghassen"
}

variable "name_prefix" {
  description = "Prefix used by the isolated DEV infrastructure."
  type        = string
  default     = "cloud5-infra-dev"
}

variable "state_bucket_name" {
  description = "Existing user-owned S3 bucket holding the DEV Terraform state."
  type        = string
  default     = "cloud5-terraform-drghassen-state-326553917564"
}

variable "state_key" {
  description = "Exact DEV Terraform state key the PR plan role may read."
  type        = string
  default     = "cloud5/infrastructure/dev/terraform.tfstate"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID."
  type        = string
  default     = "128297499"
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string
  default     = "1473229803"
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
  default     = "drghassen/cloud5drghassen"
}
