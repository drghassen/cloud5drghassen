output "dashboard_name" {
  description = "CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.operations.dashboard_name
}

output "alarm_arns" {
  description = "CloudWatch operational alarm ARNs."
  value = {
    for key, alarm in aws_cloudwatch_metric_alarm.this :
    key => alarm.arn
  }
}
