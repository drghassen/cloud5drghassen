mock_provider "aws" {}

override_data {
  target = data.aws_ami.amazon_linux

  values = {
    id = "ami-0123456789abcdef0"
  }
}

run "nginx_demo_uses_private_multi_az_instances" {
  command = plan

  variables {
    name_prefix           = "cloud5-dev"
    common_tags           = { Project = "cloud5", Environment = "dev", Owner = "test", ManagedBy = "Terraform" }
    web_security_group_id = "sg-web"
    instance_profile_name = "cloud5-dev-instance-profile"
    private_subnet_ids    = ["subnet-a", "subnet-b"]
    target_group_arn      = "arn:aws:elasticloadbalancing:eu-west-1:111122223333:targetgroup/cloud5/123456789"
    min_size              = 2
    desired_capacity      = 2
    max_size              = 4
  }

  assert {
    condition     = aws_launch_template.web.image_id == "ami-0123456789abcdef0"
    error_message = "The launch template must use the selected Amazon Linux 2023 AMI."
  }

  assert {
    condition     = strcontains(base64decode(aws_launch_template.web.user_data), "dnf install -y nginx") && strcontains(base64decode(aws_launch_template.web.user_data), "$(hostname)") && strcontains(base64decode(aws_launch_template.web.user_data), "systemctl enable --now nginx")
    error_message = "User data must install and start Nginx and expose the instance hostname."
  }

  assert {
    condition     = aws_launch_template.web.metadata_options[0].http_tokens == "required" && aws_launch_template.web.block_device_mappings[0].ebs[0].encrypted
    error_message = "Instances must require IMDSv2 and use encrypted root volumes."
  }

  assert {
    condition     = aws_launch_template.web.network_interfaces[0].associate_public_ip_address == "false" && aws_autoscaling_group.web.min_size == 2 && aws_autoscaling_group.web.desired_capacity == 2
    error_message = "Web instances must stay private and keep at least two instances."
  }

  assert {
    condition     = toset(aws_autoscaling_group.web.vpc_zone_identifier) == toset(["subnet-a", "subnet-b"]) && aws_autoscaling_group.web.health_check_type == "ELB"
    error_message = "The ASG must use both private subnets and load balancer health checks."
  }
}

run "reject_desired_capacity_above_maximum" {
  command = plan

  variables {
    name_prefix           = "cloud5-dev"
    web_security_group_id = "sg-web"
    instance_profile_name = "cloud5-dev-instance-profile"
    private_subnet_ids    = ["subnet-a", "subnet-b"]
    target_group_arn      = "arn:aws:elasticloadbalancing:eu-west-1:111122223333:targetgroup/cloud5/123456789"
    min_size              = 2
    desired_capacity      = 5
    max_size              = 4
  }

  expect_failures = [var.desired_capacity]
}
