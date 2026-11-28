locals {
  topic_name = "${var.name_prefix}-alerts"
  topic_arn  = "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${local.topic_name}"

  alarm_arns = [
    for name in [
      "alb-5xx-high",
      "ec2-cpu-high",
      "healthy-hosts-low",
      "rds-storage-low"
    ] :
    "arn:aws:cloudwatch:${var.aws_region}:${var.aws_account_id}:alarm:${var.name_prefix}-${name}"
  ]

  topic_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowAccountTopicManagement"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }

        Action = [
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic"
        ]

        Resource = local.topic_arn
      },
      {
        Sid    = "AllowProjectCloudWatchAlarms"
        Effect = "Allow"

        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }

        Action   = "sns:Publish"
        Resource = local.topic_arn

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }

          ArnEquals = {
            "aws:SourceArn" = local.alarm_arns
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic" "alerts" {
  name              = local.topic_name
  fifo_topic        = false
  kms_master_key_id = var.kms_key_arn
  policy            = local.topic_policy

  tags = merge(var.common_tags, {
    Name = local.topic_name
  })

  lifecycle {
    precondition {
      condition = startswith(
        var.kms_key_arn,
        "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/"
      )

      error_message = "KMS key must belong to the expected AWS account and region."
    }
  }
}
