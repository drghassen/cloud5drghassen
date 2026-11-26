variable "name_prefix" {
  description = "Prefix used to name load balancer resources (up to 25 characters)."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 25
    error_message = "name_prefix must be 25 characters or shorter."
  }
}

variable "common_tags" {
  description = "Common tags applied to load balancer resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID hosting the target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs used by the internet-facing ALB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2 && length(distinct(var.public_subnet_ids)) >= 2
    error_message = "The ALB requires at least two distinct public subnets."
  }
}

variable "alb_security_group_id" {
  description = "Security group ID attached to the ALB."
  type        = string
}

variable "web_port" {
  description = "Port used by Nginx on private web instances."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path used by the target group health check."
  type        = string
  default     = "/"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must begin with '/'."
  }
}

variable "enable_https" {
  description = "Enable HTTPS and redirect HTTP to HTTPS; disable only for disposable HTTP demos."
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in the same region as the ALB; required when HTTPS is enabled."
  type        = string
  default     = ""

  validation {
    condition     = var.enable_https ? can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-f0-9-]{36}$", var.acm_certificate_arn)) : var.acm_certificate_arn == ""
    error_message = "HTTPS requires a valid ACM certificate ARN; otherwise leave the ARN empty."
  }
}

variable "enable_deletion_protection" {
  description = "Protect the ALB from accidental deletion in long-lived environments."
  type        = bool
  default     = false
}
