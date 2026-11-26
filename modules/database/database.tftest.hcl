mock_provider "aws" {}

override_resource {
  target = aws_security_group.database

  values = {
    id = "sg-database"
  }
  override_during = plan
}

run "database_is_private_and_web_only" {
  command = plan

  variables {
    name_prefix           = "cloud5-dev"
    common_tags           = { Project = "cloud5", Environment = "dev", Owner = "test", ManagedBy = "Terraform" }
    vpc_id                = "vpc-test"
    private_subnet_ids    = ["subnet-db-a", "subnet-db-b"]
    web_security_group_id = "sg-web"
    db_instance_class     = "db.t3.micro"
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.storage_encrypted
    error_message = "RDS must be private and its storage encrypted."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password && toset(aws_db_instance.this.vpc_security_group_ids) == toset([aws_security_group.database.id])
    error_message = "RDS must use an AWS-managed master password and its dedicated security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.from_web.referenced_security_group_id == "sg-web" && aws_vpc_security_group_ingress_rule.from_web.from_port == 5432 && length(aws_security_group.database.egress) == 0
    error_message = "RDS must accept PostgreSQL only from the web security group and have no outbound rules."
  }
}
