moved {
  from = aws_iam_policy.notifications
  to   = module.extensions.aws_iam_policy.notifications[0]
}

moved {
  from = aws_iam_role_policy_attachment.notifications
  to   = module.extensions.aws_iam_role_policy_attachment.notifications[0]
}
