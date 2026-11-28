output "topic_arn" {
  description = "ARN of the environment-specific SNS alert topic."
  value       = local.topic_arn

  depends_on = [aws_sns_topic.alerts]
}

output "topic_name" {
  description = "Name of the SNS alert topic."
  value       = local.topic_name
}
