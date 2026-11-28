# Notifications Module

Secure SNS alerting for Cloud5 infrastructure.

## Components

- Environment-specific SNS Standard topic.
- Customer-managed KMS encryption key.
- Restricted CloudWatch publishing policy.
- Mandatory ownership tags.
- Deterministic SNS topic ARN.

## Security

CloudWatch publishing is restricted to four approved
environment-specific alarm ARNs.

KMS administration is separated from the workload
Terraform pipeline.

Email subscriptions are managed by an authorized
operator outside Terraform.

No email address or credentials must be committed.

## Deployment

DEV is the first supported deployment environment.
TEST and PROD require dedicated IAM permissions,
KMS keys and ownership gate integration.

## Cost

SNS requests, notification delivery and KMS usage
are subject to AWS pricing.

## Validation

Run terraform test with the mocked AWS provider.
Real notification delivery requires a confirmed
email subscription and an end-to-end alarm test.
