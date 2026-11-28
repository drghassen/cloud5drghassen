locals {
  topic_arn = "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.name_prefix}-alerts"
}

resource "aws_iam_policy" "notifications" {
  count = var.enable_notifications ? 1 : 0

  name        = "${var.name_prefix}-github-terraform-${var.role_type}-notifications"
  description = var.role_type == "plan" ? "Read-only access to the Cloud5 ${upper(var.environment)} SNS topic." : "Scoped management of the Cloud5 ${upper(var.environment)} SNS topic."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "ReadProjectSNSTopic"
        Effect   = "Allow"
        Action   = ["sns:GetTopicAttributes", "sns:ListTagsForResource"]
        Resource = local.topic_arn
      }
      ], var.role_type == "apply" ? [
      {
        Sid       = "CreateTaggedProjectSNSTopic"
        Effect    = "Allow"
        Action    = ["sns:CreateTopic", "sns:TagResource"]
        Resource  = local.topic_arn
        Condition = { StringEquals = local.request_tags }
      },
      {
        Sid       = "ManageOwnedProjectSNSTopic"
        Effect    = "Allow"
        Action    = ["sns:SetTopicAttributes", "sns:DeleteTopic"]
        Resource  = local.topic_arn
        Condition = { StringEquals = local.resource_tags }
      }
    ] : [])
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "notifications" {
  count      = var.enable_notifications ? 1 : 0
  role       = var.role_name
  policy_arn = aws_iam_policy.notifications[0].arn
}
