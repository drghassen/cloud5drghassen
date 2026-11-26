variable "aws_region" {
  description = "Region containing the DEV deployment."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment tag applied to the DEV apply role."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This bootstrap configuration provisions only the DEV apply role."
  }
}

variable "github_environment" {
  description = "GitHub environment allowed to assume the DEV apply role."
  type        = string
  default     = "dev"

  validation {
    condition     = var.github_environment == "dev"
    error_message = "The DEV apply role must trust the dev GitHub environment."
  }
}

variable "project_name" {
  description = "Project tag applied to the role and required for EC2 resources."
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
  description = "Existing user-owned S3 bucket holding the Terraform state."
  type        = string
  default     = "cloud5-terraform-drghassen-state-326553917564"
}

variable "state_key" {
  description = "Exact DEV Terraform state key the apply role may update."
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
