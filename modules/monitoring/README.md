# Monitoring Module

CloudWatch monitoring for the Cloud5 AWS infrastructure.

## Components

- Operations dashboard with nine metric widgets.
- Four operational CloudWatch alarms.
- Native ALB, EC2, ASG and RDS metrics.
- Optional SNS alarm actions.

## Security

Mandatory ownership tags are applied where supported.
Dashboard ownership is controlled through its exact name,
IAM permissions and Terraform plan validation.

## Cost

No custom metrics, CloudWatch Agent or detailed EC2
monitoring are enabled by this module.

Dashboard and alarm charges depend on AWS pricing
and account-wide free tier usage.

SNS notifications are disabled until approved
notification targets are configured.
