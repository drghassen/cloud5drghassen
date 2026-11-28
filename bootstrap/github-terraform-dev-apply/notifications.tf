locals {
  notifications_topic_arn = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cloud5-infra-dev-alerts"

  notifications_required_tags = {
    Owner       = "drghassen"
    Project     = "terraform-cloud-project"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }

  notifications_request_tags = {
    for key, value in local.notifications_required_tags :
    "aws:RequestTag/${key}" => value
  }

  notifications_resource_tags = {
    for key, value in local.notifications_required_tags :
    "aws:ResourceTag/${key}" => value
  }
}

resource "aws_iam_policy" "notifications" {
  name        = "cloud5-infra-dev-github-terraform-apply-notifications"
  description = "Scoped management of the Cloud5 DEV SNS topic."

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

        Resource = local.notifications_topic_arn
      },
      {
        Sid    = "CreateTaggedProjectSNSTopic"
        Effect = "Allow"

        Action = [
          "sns:CreateTopic",
          "sns:TagResource"
        ]

        Resource = local.notifications_topic_arn

        Condition = {
          StringEquals = local.notifications_request_tags
        }
      },
      {
        Sid    = "ManageOwnedProjectSNSTopic"
        Effect = "Allow"

        Action = [
          "sns:SetTopicAttributes",
          "sns:DeleteTopic"
        ]

        Resource = local.notifications_topic_arn

        Condition = {
          StringEquals = local.notifications_resource_tags
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "notifications" {
  role       = module.github_terraform_dev_apply.role_name
  policy_arn = aws_iam_policy.notifications.arn
}
