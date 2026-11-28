locals {
  dashboard_arn = "arn:aws:cloudwatch::${var.aws_account_id}:dashboard/${var.name_prefix}-operations"
  alarm_arns = [
    for name in ["healthy-hosts-low", "alb-5xx-high", "ec2-cpu-high", "rds-storage-low"] :
    "arn:aws:cloudwatch:${var.aws_region}:${var.aws_account_id}:alarm:${var.name_prefix}-${name}"
  ]
  asg_arn = "arn:aws:autoscaling:${var.aws_region}:${var.aws_account_id}:autoScalingGroup:*:autoScalingGroupName/${var.name_prefix}-web-asg"

  required_tags = {
    Owner       = var.common_tags.Owner
    Project     = var.common_tags.Project
    Environment = var.environment
    ManagedBy   = var.common_tags.ManagedBy
  }
  request_tags  = { for key, value in local.required_tags : "aws:RequestTag/${key}" => value }
  resource_tags = { for key, value in local.required_tags : "aws:ResourceTag/${key}" => value }

  monitoring_read_statements = [
    {
      Sid      = "ReadProjectDashboard"
      Effect   = "Allow"
      Action   = ["cloudwatch:GetDashboard"]
      Resource = local.dashboard_arn
    },
    {
      Sid      = "ReadProjectAlarms"
      Effect   = "Allow"
      Action   = ["cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource"]
      Resource = local.alarm_arns
    }
  ]
}

resource "aws_iam_policy" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  name        = "${var.name_prefix}-github-terraform-${var.role_type}-monitoring"
  description = var.role_type == "plan" ? "Read-only CloudWatch access for Cloud5 ${upper(var.environment)} Terraform plans." : "Scoped CloudWatch and ASG monitoring management for Cloud5 ${upper(var.environment)}."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.monitoring_read_statements, [for statement in [
      {
        Sid      = "ManageProjectDashboard"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards"]
        Resource = local.dashboard_arn
      },
      {
        Sid       = "CreateTaggedProjectAlarms"
        Effect    = "Allow"
        Action    = ["cloudwatch:PutMetricAlarm", "cloudwatch:TagResource"]
        Resource  = local.alarm_arns
        Condition = { StringEquals = local.request_tags }
      },
      {
        Sid       = "ManageOwnedProjectAlarms"
        Effect    = "Allow"
        Action    = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms"]
        Resource  = local.alarm_arns
        Condition = { StringEquals = local.resource_tags }
      },
      {
        Sid       = "ManageProjectASGMetrics"
        Effect    = "Allow"
        Action    = ["autoscaling:EnableMetricsCollection", "autoscaling:DisableMetricsCollection"]
        Resource  = local.asg_arn
        Condition = { StringEquals = local.resource_tags }
      }
    ] : statement if var.role_type == "apply"])
  })
  tags = var.common_tags

  lifecycle {
    precondition {
      condition     = var.role_name == "${var.name_prefix}-github-terraform-${var.role_type}"
      error_message = "role_name must match name_prefix and role_type exactly."
    }
  }
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count      = var.enable_monitoring ? 1 : 0
  role       = var.role_name
  policy_arn = aws_iam_policy.monitoring[0].arn
}
