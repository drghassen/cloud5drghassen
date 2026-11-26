variable "name_prefix" {
  description = "Prefix used to name security resources."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to security resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID where security groups are created."
  type        = string
}

variable "web_port" {
  description = "Port used by the Nginx web instances."
  type        = number
  default     = 80

  validation {
    condition     = var.web_port >= 1 && var.web_port <= 65535
    error_message = "web_port must be a valid TCP port."
  }
}

variable "enable_https" {
  description = "Open public HTTPS ingress only when the HTTPS listener is enabled."
  type        = bool
  default     = false
}
