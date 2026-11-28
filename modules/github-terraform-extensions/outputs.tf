output "policy_arns" {
  description = "ARNs of enabled managed policies, keyed by extension."
  value = merge(
    var.enable_monitoring ? { monitoring = aws_iam_policy.monitoring[0].arn } : {},
    var.enable_notifications ? { notifications = aws_iam_policy.notifications[0].arn } : {},
    var.enable_diagnostics ? { diagnostics = aws_iam_policy.diagnostics[0].arn } : {}
  )
}
