mock_provider "aws" {}

variables {
  name_prefix    = "cloud5-infra-dev"
  aws_region     = "eu-west-1"
  aws_account_id = "326553917564"
  kms_key_arn    = "arn:aws:kms:eu-west-1:326553917564:key/e3457e7c-9593-498b-af07-d697ae114a45"

  common_tags = {
    Owner       = "drghassen"
    Project     = "terraform-cloud-project"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

run "validate_dev_topic" {
  command = plan

  assert {
    condition     = aws_sns_topic.alerts.name == "cloud5-infra-dev-alerts"
    error_message = "Unexpected SNS topic name."
  }

  assert {
    condition     = aws_sns_topic.alerts.fifo_topic == false
    error_message = "SNS topic must be a Standard topic."
  }

  assert {
    condition     = aws_sns_topic.alerts.kms_master_key_id == var.kms_key_arn
    error_message = "SNS topic must use the approved KMS key."
  }

  assert {
    condition = alltrue([
      for key, value in var.common_tags :
      aws_sns_topic.alerts.tags[key] == value
    ])
    error_message = "Mandatory ownership tags are missing."
  }

  assert {
    condition     = output.topic_arn == "arn:aws:sns:eu-west-1:326553917564:cloud5-infra-dev-alerts"
    error_message = "Unexpected SNS topic ARN."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_sns_topic.alerts.policy).Statement :
      statement
      if try(
        statement.Principal.Service == "cloudwatch.amazonaws.com" &&
        statement.Action == "sns:Publish" &&
        statement.Resource == output.topic_arn &&
        statement.Condition.StringEquals["aws:SourceAccount"] == var.aws_account_id &&
        length(statement.Condition.ArnEquals["aws:SourceArn"]) == 4,
        false
      )
    ]) == 1

    error_message = "CloudWatch publishing policy is not correctly restricted."
  }
}

run "reject_foreign_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:eu-west-1:111122223333:key/12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [
    aws_sns_topic.alerts
  ]
}
