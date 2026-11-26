resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:ALB access logs require a dedicated destination and retention policy, deferred for this cost-constrained demo.
  #checkov:skip=CKV_AWS_150:Deletion protection is disabled for disposable environments so approved cleanup remains possible.
  #checkov:skip=CKV2_AWS_28:AWS WAF is a separately billed control and is deferred from this project scope.
  #checkov:skip=CKV2_AWS_20:HTTP-to-HTTPS redirection activates with the future HTTPS listener.
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "web" {
  #checkov:skip=CKV_AWS_378:TLS terminates at the ALB; backend instances use HTTP only inside their private subnets.
  name        = "${var.name_prefix}-web-tg"
  port        = var.web_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = var.health_check_path
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-web-tg"
  })
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:HTTPS is deferred until a custom domain and ACM certificate are available.
  #checkov:skip=CKV_AWS_103:This listener is HTTP-only until HTTPS is enabled with an ACM certificate.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []

      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.enable_https ? [] : [1]

      content {
        target_group {
          arn = aws_lb_target_group.web.arn
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-http-listener"
  })
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-https-listener"
  })
}
