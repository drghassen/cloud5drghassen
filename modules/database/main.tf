resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnets"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-db-sg"
  description = "Private PostgreSQL access from web instances only."
  vpc_id      = var.vpc_id
  egress      = []

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "from_web" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = var.web_security_group_id
  description                  = "PostgreSQL from the web security group only."
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_129:Database engine log export is deferred until the project defines a CloudWatch retention and cost policy.
  #checkov:skip=CKV_AWS_118:Enhanced monitoring is deferred for the cost-constrained demo.
  #checkov:skip=CKV_AWS_161:IAM database authentication requires application-side support and is not configured in this infrastructure-only phase.
  #checkov:skip=CKV_AWS_293:Deletion protection is disabled only for disposable environments; enable it for long-lived environments.
  #checkov:skip=CKV_AWS_353:Performance Insights is deferred until database monitoring requirements and cost are approved.
  #checkov:skip=CKV_AWS_157:Single-AZ is retained for lower-cost non-production environments; production settings enable Multi-AZ.
  #checkov:skip=CKV2_AWS_30:PostgreSQL query logging is deferred until CloudWatch retention and cost are defined.
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  instance_class = var.db_instance_class
  db_name        = var.db_name
  username       = var.db_username

  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  port                   = 5432

  multi_az                   = var.multi_az
  backup_retention_period    = var.backup_retention_period
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name_prefix}-final"
  copy_tags_to_snapshot      = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-postgres"
  })
}
