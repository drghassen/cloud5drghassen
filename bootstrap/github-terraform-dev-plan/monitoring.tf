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

resource "aws_iam_policy" "monitoring" {
  name        = "cloud5-infra-dev-github-terraform-plan-monitoring"
  description = "Read-only CloudWatch access for Cloud5 DEV Terraform plans."

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.monitoring_read_statements
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = module.github_terraform_dev_plan.role_name
  policy_arn = aws_iam_policy.monitoring.arn
}
