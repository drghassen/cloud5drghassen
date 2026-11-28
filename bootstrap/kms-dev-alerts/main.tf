terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["326553917564"]

  default_tags {
    tags = local.common_tags
  }
}

locals {
  account_id = "326553917564"
  aws_region = "eu-west-1"

  name_prefix = "cloud5-infra-dev"

  topic_arn = "arn:aws:sns:${local.aws_region}:${local.account_id}:${local.name_prefix}-alerts"

  common_tags = {
    Owner       = "drghassen"
    Project     = "terraform-cloud-project"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }

  alarm_arns = [
    for name in [
      "alb-5xx-high",
      "ec2-cpu-high",
      "healthy-hosts-low",
      "rds-storage-low"
    ] :
    "arn:aws:cloudwatch:${local.aws_region}:${local.account_id}:alarm:${local.name_prefix}-${name}"
  ]
}

resource "aws_kms_key" "alerts" {
  description              = "Cloud5 DEV SNS alert encryption"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  enable_key_rotation      = true
  deletion_window_in_days  = 30
  multi_region             = false

  bypass_policy_lockout_safety_check = false

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountIAMPermissions"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowProjectCloudWatchAlarms"
        Effect = "Allow"

        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }

        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }

          ArnEquals = {
            "aws:SourceArn" = local.alarm_arns
          }
        }
      },
      {
        Sid    = "AllowProjectSNSEncryption"
        Effect = "Allow"

        Principal = {
          Service = "sns.amazonaws.com"
        }

        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "kms:EncryptionContext:aws:sns:topicArn" = local.topic_arn
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alerts"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "alerts" {
  name          = "alias/${local.name_prefix}-alerts"
  target_key_id = aws_kms_key.alerts.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for the DEV SNS topic."
  value       = aws_kms_key.alerts.arn
}

output "kms_key_id" {
  description = "DEV alert encryption key identifier."
  value       = aws_kms_key.alerts.key_id
}

output "kms_alias_name" {
  description = "DEV alert encryption key alias."
  value       = aws_kms_alias.alerts.name
}
