mock_provider "aws" {}

run "network_multi_az_layout_and_controlled_egress" {
  command = plan

  variables {
    name_prefix              = "cloud5-test"
    vpc_cidr                 = "10.20.0.0/16"
    availability_zones       = ["eu-west-1a", "eu-west-1b"]
    public_subnet_cidrs      = ["10.20.1.0/24", "10.20.2.0/24"]
    private_app_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
    private_db_subnet_cidrs  = ["10.20.21.0/24", "10.20.22.0/24"]
    nat_gateway_count        = 1
    common_tags = {
      Project     = "terraform-cloud-project"
      Environment = "test"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.20.0.0/16"
    error_message = "VPC CIDR must match the requested 10.20.0.0/16 block."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private_app) == 2 && length(aws_subnet.private_db) == 2
    error_message = "The network module must create 2 public, 2 private app, and 2 private DB subnets."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Exactly 1 NAT Gateway must be created for single NAT config."
  }

  assert {
    condition     = length(aws_route.private_app_internet) == 2 && length(aws_route_table_association.private_db) == 2
    error_message = "Application subnets must use controlled NAT egress and database subnets must be associated with the private route table."
  }
}

run "reject_noncanonical_vpc_cidr" {
  command = plan
  variables {
    name_prefix              = "cloud5-test"
    vpc_cidr                 = "10.20.0.1/16"
    availability_zones       = ["eu-west-1a", "eu-west-1b"]
    public_subnet_cidrs      = ["10.20.1.0/24", "10.20.2.0/24"]
    private_app_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
    private_db_subnet_cidrs  = ["10.20.21.0/24", "10.20.22.0/24"]
    nat_gateway_count        = 1
  }
  expect_failures = [var.vpc_cidr]
}

run "reject_noncanonical_subnet_cidr" {
  command = plan
  variables {
    name_prefix              = "cloud5-test"
    vpc_cidr                 = "10.20.0.0/16"
    availability_zones       = ["eu-west-1a", "eu-west-1b"]
    public_subnet_cidrs      = ["10.20.1.1/24", "10.20.2.0/24"]
    private_app_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
    private_db_subnet_cidrs  = ["10.20.21.0/24", "10.20.22.0/24"]
    nat_gateway_count        = 1
  }
  expect_failures = [var.public_subnet_cidrs]
}

run "reject_duplicate_subnet_cidr" {
  command = plan
  variables {
    name_prefix              = "cloud5-test"
    vpc_cidr                 = "10.20.0.0/16"
    availability_zones       = ["eu-west-1a", "eu-west-1b"]
    public_subnet_cidrs      = ["10.20.1.0/24", "10.20.1.0/24"]
    private_app_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
    private_db_subnet_cidrs  = ["10.20.21.0/24", "10.20.22.0/24"]
    nat_gateway_count        = 1
  }
  expect_failures = [aws_vpc.this]
}

run "reject_fractional_nat_gateway_count" {
  command = plan
  variables {
    name_prefix              = "cloud5-test"
    vpc_cidr                 = "10.20.0.0/16"
    availability_zones       = ["eu-west-1a", "eu-west-1b"]
    public_subnet_cidrs      = ["10.20.1.0/24", "10.20.2.0/24"]
    private_app_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
    private_db_subnet_cidrs  = ["10.20.21.0/24", "10.20.22.0/24"]
    nat_gateway_count        = 1.5
  }
  expect_failures = [var.nat_gateway_count]
}
