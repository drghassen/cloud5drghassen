locals {
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix = var.resource_name_prefix
  common_tags = local.common_tags
  vpc_cidr    = var.vpc_cidr

  availability_zones = local.availability_zones

  public_subnet_cidrs      = [for index in [1, 2] : cidrsubnet(var.vpc_cidr, 8, index)]
  private_app_subnet_cidrs = [for index in [11, 12] : cidrsubnet(var.vpc_cidr, 8, index)]
  private_db_subnet_cidrs  = [for index in [21, 22] : cidrsubnet(var.vpc_cidr, 8, index)]
  nat_gateway_count        = var.nat_gateway_count
}

module "security" {
  source = "../../modules/security"

  name_prefix  = var.resource_name_prefix
  common_tags  = local.common_tags
  vpc_id       = module.network.vpc_id
  web_port     = 80
  enable_https = var.enable_https
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix                = var.resource_name_prefix
  common_tags                = local.common_tags
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  alb_security_group_id      = module.security.alb_security_group_id
  web_port                   = 80
  health_check_path          = "/"
  enable_https               = var.enable_https
  acm_certificate_arn        = var.acm_certificate_arn
  enable_deletion_protection = var.enable_deletion_protection
}

module "compute" {
  source = "../../modules/compute"

  name_prefix           = var.resource_name_prefix
  common_tags           = local.common_tags
  instance_type         = var.instance_type
  web_security_group_id = module.security.web_security_group_id
  instance_profile_name = module.security.web_instance_profile_name
  private_subnet_ids    = module.network.private_app_subnet_ids
  target_group_arn      = module.load_balancer.target_group_arn
  min_size              = var.min_size
  desired_capacity      = var.desired_capacity
  max_size              = var.max_size
}

module "database" {
  source = "../../modules/database"

  name_prefix           = var.resource_name_prefix
  common_tags           = local.common_tags
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_db_subnet_ids
  web_security_group_id = module.security.web_security_group_id

  db_instance_class       = var.db_instance_class
  db_name                 = "cloud5db"
  db_username             = "cloud5admin"
  allocated_storage       = 20
  max_allocated_storage   = 100
  backup_retention_period = var.db_backup_retention_period
  multi_az                = var.db_multi_az
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
}

resource "aws_vpc_security_group_egress_rule" "web_to_database" {
  security_group_id            = module.security.web_security_group_id
  referenced_security_group_id = module.database.db_security_group_id
  description                  = "PostgreSQL egress to the RDS security group only."
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

module "storage" {
  source = "../../modules/storage"

  name_prefix = var.resource_name_prefix
  common_tags = local.common_tags
}

module "notifications" {
  source = "../../modules/notifications"

  name_prefix    = var.resource_name_prefix
  aws_region     = var.aws_region
  aws_account_id = "326553917564"
  kms_key_arn    = "arn:aws:kms:eu-west-1:326553917564:key/e3457e7c-9593-498b-af07-d697ae114a45"
  common_tags    = local.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix            = var.resource_name_prefix
  aws_region             = var.aws_region
  common_tags            = local.common_tags
  alb_arn                = module.load_balancer.alb_arn
  target_group_arn       = module.load_balancer.target_group_arn
  autoscaling_group_name = module.compute.autoscaling_group_name
  db_instance_identifier = module.database.db_instance_identifier
  minimum_healthy_hosts  = var.min_size
  alarm_actions          = [module.notifications.topic_arn]
}
