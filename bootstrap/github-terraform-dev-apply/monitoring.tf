locals {
  monitoring_dashboard_arn = "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/cloud5-infra-dev-operations"

  monitoring_alarm_arns = [
    for name in [
      "healthy-hosts-low",
      "alb-5xx-high",
      "ec2-cpu-high",
      "rds-storage-low"
    ] :
    "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:cloud5-infra-dev-${name}"
  ]

  monitoring_read_statements = [
    {
      Sid      = "ReadProjectDashboard"
      Effect   = "Allow"
      Action   = ["cloudwatch:GetDashboard"]
      Resource = local.monitoring_dashboard_arn
    },
    {
      Sid    = "ReadProjectAlarms"
      Effect = "Allow"
      Action = [
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListTagsForResource"
      ]
      Resource = local.monitoring_alarm_arns
    }
  ]
}

locals {
  monitoring_required_tags = {
    Owner       = "drghassen"
    Project     = "terraform-cloud-project"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }

  monitoring_request_tags = {
    for key, value in local.monitoring_required_tags :
    "aws:RequestTag/${key}" => value
  }

  monitoring_resource_tags = {
    for key, value in local.monitoring_required_tags :
    "aws:ResourceTag/${key}" => value
  }

  monitoring_asg_arn = "arn:aws:autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/cloud5-infra-dev-web-asg"
}

resource "aws_iam_policy" "monitoring" {
  name        = "cloud5-infra-dev-github-terraform-apply-monitoring"
  description = "Scoped CloudWatch and ASG monitoring management for Cloud5 DEV."

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = concat(local.monitoring_read_statements, [
      {
        Sid    = "ManageProjectDashboard"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:DeleteDashboards"
        ]
        Resource = local.monitoring_dashboard_arn
      },
      {
        Sid    = "CreateTaggedProjectAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:TagResource"
        ]
        Resource = local.monitoring_alarm_arns

        Condition = {
          StringEquals = local.monitoring_request_tags
        }
      },
      {
        Sid    = "ManageOwnedProjectAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms"
        ]
        Resource = local.monitoring_alarm_arns

        Condition = {
          StringEquals = local.monitoring_resource_tags
        }
      },
      {
        Sid    = "ManageProjectASGMetrics"
        Effect = "Allow"
        Action = [
          "autoscaling:EnableMetricsCollection",
          "autoscaling:DisableMetricsCollection"
        ]
        Resource = local.monitoring_asg_arn

        Condition = {
          StringEquals = local.monitoring_resource_tags
        }
      }
    ])
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = module.github_terraform_dev_apply.role_name
  policy_arn = aws_iam_policy.monitoring.arn
}
