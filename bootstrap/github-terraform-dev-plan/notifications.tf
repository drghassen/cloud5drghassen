resource "aws_iam_policy" "notifications" {
  name        = "cloud5-infra-dev-github-terraform-plan-notifications"
  description = "Read-only access to the Cloud5 DEV SNS topic."

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadProjectSNSTopic"
        Effect = "Allow"

        Action = [
          "sns:GetTopicAttributes",
          "sns:ListTagsForResource"
        ]

        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cloud5-infra-dev-alerts"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "notifications" {
  role       = module.github_terraform_dev_plan.role_name
  policy_arn = aws_iam_policy.notifications.arn
}
