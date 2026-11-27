variable "aws_region" {
  description = "Region containing the Terraform environments."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project tag used to scope environment resources."
  type        = string
  default     = "terraform-cloud-project"

  validation {
    condition     = var.project_name == "terraform-cloud-project"
    error_message = "The Project tag must be terraform-cloud-project."
  }
}

variable "owner" {
  description = "Owner tag applied to the apply roles."
  type        = string
  default     = "drghassen"

  validation {
    condition     = var.owner == "drghassen"
    error_message = "The resource owner must be drghassen."
  }
}

variable "state_bucket_name" {
  description = "Existing bucket containing the environment state objects."
  type        = string
  default     = "cloud5-terraform-drghassen-state-326553917564"
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
