resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:This group is attached to the ALB through the security module output; Checkov does not follow this module boundary.
  name        = "${var.name_prefix}-alb-sg"
  description = "Public HTTP and HTTPS entry point."
  vpc_id      = var.vpc_id
  egress      = []

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:Public HTTP is an explicitly documented temporary demo endpoint until HTTPS is enabled.
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the Internet."
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the Internet."
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "web" {
  #checkov:skip=CKV2_AWS_5:This group is attached to the Auto Scaling launch template through the security module output; Checkov does not follow this module boundary.
  name        = "${var.name_prefix}-web-sg"
  description = "Web traffic only from the Application Load Balancer."
  vpc_id      = var.vpc_id
  egress      = []

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-web-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  #checkov:skip=CKV_AWS_260:Ingress is restricted to the ALB security group; the public-port finding is a module-analysis false positive.
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "HTTP from the ALB only."
  ip_protocol                  = "tcp"
  from_port                    = var.web_port
  to_port                      = var.web_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.web.id
  description                  = "Forward HTTP requests to web instances."
  ip_protocol                  = "tcp"
  from_port                    = var.web_port
  to_port                      = var.web_port
}

resource "aws_vpc_security_group_egress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS for package updates and Systems Manager."
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_iam_role" "web_instance" {
  name = "${var.name_prefix}-web-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-web-instance-role"
  })
}

resource "aws_iam_role_policy_attachment" "systems_manager" {
  role       = aws_iam_role.web_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web_instance" {
  name = "${var.name_prefix}-web-instance-profile"
  role = aws_iam_role.web_instance.name

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-web-instance-profile"
  })
}
