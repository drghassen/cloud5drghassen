mock_provider "aws" {}

run "http_load_balancer_for_nginx_demo" {
  command = plan

  variables {
    name_prefix           = "cloud5-dev"
    vpc_id                = "vpc-test"
    public_subnet_ids     = ["subnet-public-a", "subnet-public-b"]
    alb_security_group_id = "sg-alb"
    web_port              = 80
    health_check_path     = "/"
    enable_https          = false
    common_tags           = { Project = "cloud5", Environment = "dev", Owner = "test", ManagedBy = "Terraform" }
  }

  assert {
    condition     = aws_lb.this.load_balancer_type == "application" && !aws_lb.this.internal && aws_lb.this.enable_deletion_protection == false
    error_message = "The demo ALB must be public and destroyable."
  }

  assert {
    condition     = aws_lb_target_group.web.port == 80 && aws_lb_target_group.web.health_check[0].path == "/"
    error_message = "The target group must send HTTP to Nginx and health-check the root page."
  }

  assert {
    condition     = aws_lb_listener.http.port == 80 && aws_lb_listener.http.protocol == "HTTP" && aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "The demo HTTP listener must forward requests to the web target group."
  }
}

run "https_requires_a_certificate" {
  command = plan

  variables {
    name_prefix           = "cloud5-dev"
    vpc_id                = "vpc-test"
    public_subnet_ids     = ["subnet-public-a", "subnet-public-b"]
    alb_security_group_id = "sg-alb"
    enable_https          = true
  }

  expect_failures = [var.acm_certificate_arn]
}

run "https_redirects_http" {
  command = plan

  variables {
    name_prefix           = "cloud5-dev"
    vpc_id                = "vpc-test"
    public_subnet_ids     = ["subnet-public-a", "subnet-public-b"]
    alb_security_group_id = "sg-alb"
    enable_https          = true
    acm_certificate_arn   = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "redirect" && aws_lb_listener.http.default_action[0].redirect[0].protocol == "HTTPS"
    error_message = "The HTTP listener must redirect traffic to HTTPS when HTTPS is enabled."
  }

  assert {
    condition     = aws_lb_listener.https[0].protocol == "HTTPS"
    error_message = "An HTTPS listener must exist when HTTPS is enabled."
  }
}
