mock_provider "aws" {}

override_resource {
  target = aws_security_group.alb

  values = {
    id = "sg-alb"
  }
  override_during = plan
}

override_resource {
  target = aws_security_group.web

  values = {
    id = "sg-web"
  }
  override_during = plan
}

run "web_and_database_access_are_restricted" {
  command = plan

  variables {
    name_prefix  = "cloud5-dev"
    common_tags  = { Project = "cloud5", Environment = "dev", Owner = "test", ManagedBy = "Terraform" }
    vpc_id       = "vpc-test"
    web_port     = 80
    enable_https = false
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_from_alb.referenced_security_group_id == aws_security_group.alb.id && aws_vpc_security_group_ingress_rule.web_from_alb.from_port == 80
    error_message = "Web instances must accept HTTP only from the ALB security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http.cidr_ipv4 == "0.0.0.0/0" && length(aws_vpc_security_group_ingress_rule.alb_https) == 0
    error_message = "HTTP must remain available for the demo, while HTTPS ingress stays closed until its listener is enabled."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_web.referenced_security_group_id == aws_security_group.web.id && aws_vpc_security_group_egress_rule.web_https.from_port == 443
    error_message = "ALB egress must target web instances and web egress must be limited to HTTPS."
  }

  assert {
    condition     = aws_iam_instance_profile.web_instance.role == aws_iam_role.web_instance.name && aws_iam_role_policy_attachment.systems_manager.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The instance profile must provide Systems Manager access without SSH ingress."
  }
}

run "https_ingress_is_enabled_with_the_https_listener" {
  command = plan

  variables {
    name_prefix  = "cloud5-dev"
    common_tags  = { Project = "cloud5", Environment = "dev", Owner = "test", ManagedBy = "Terraform" }
    vpc_id       = "vpc-test"
    web_port     = 80
    enable_https = true
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_https) == 1 && aws_vpc_security_group_ingress_rule.alb_https[0].cidr_ipv4 == "0.0.0.0/0"
    error_message = "The ALB must accept public HTTPS traffic when HTTPS is enabled."
  }
}
