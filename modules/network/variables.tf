
variable "vpc_cidr" {
  description = "CIDR block of the Cloud5 VPC"
  type        = string

  validation {
    condition = (
      can(cidrhost(var.vpc_cidr, 0)) &&
      can(cidrsubnet(var.vpc_cidr, 0, 0)) &&
      cidrsubnet(var.vpc_cidr, 0, 0) == var.vpc_cidr &&
      endswith(var.vpc_cidr, "/16")
    )
    error_message = "The VPC CIDR must be a canonical IPv4 /16 network."
  }
}

variable "name_prefix" {
  description = "Prefix used to name Cloud5 network resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to network resources"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "Availability Zones used by Cloud5"
  type        = list(string)

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      length(distinct(var.availability_zones)) == 2
    )
    error_message = "Cloud5 requires exactly two distinct Availability Zones."
  }
}


variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition = (
      length(var.public_subnet_cidrs) == 2 &&
      alltrue([for cidr in var.public_subnet_cidrs :
        can(cidrhost(cidr, 0)) &&
        can(cidrsubnet(cidr, 0, 0)) &&
        cidrsubnet(cidr, 0, 0) == cidr &&
        endswith(cidr, "/24")
      ])
    )
    error_message = "Exactly two valid public subnet CIDRs are required."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)

  validation {
    condition = (
      length(var.private_app_subnet_cidrs) == 2 &&
      alltrue([for cidr in var.private_app_subnet_cidrs :
        can(cidrhost(cidr, 0)) &&
        can(cidrsubnet(cidr, 0, 0)) &&
        cidrsubnet(cidr, 0, 0) == cidr &&
        endswith(cidr, "/24")
      ])
    )
    error_message = "Exactly two valid private application subnet CIDRs are required."
  }
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets"
  type        = list(string)

  validation {
    condition = (
      length(var.private_db_subnet_cidrs) == 2 &&
      alltrue([for cidr in var.private_db_subnet_cidrs :
        can(cidrhost(cidr, 0)) &&
        can(cidrsubnet(cidr, 0, 0)) &&
        cidrsubnet(cidr, 0, 0) == cidr &&
        endswith(cidr, "/24")
      ])
    )
    error_message = "Exactly two valid private database subnet CIDRs are required."
  }
}


variable "nat_gateway_count" {
  description = "Number of NAT Gateways to create"
  type        = number

  validation {
    condition = (
      floor(var.nat_gateway_count) == var.nat_gateway_count &&
      var.nat_gateway_count >= 1 &&
      var.nat_gateway_count <= 2
    )
    error_message = "Cloud5 requires one or two NAT Gateways."
  }
}
