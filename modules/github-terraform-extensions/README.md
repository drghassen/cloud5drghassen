# GitHub Terraform IAM extensions

This module is the single source of truth for optional environment-scoped IAM
managed policies attached to existing GitHub Terraform roles. It never creates
roles, OIDC providers, KMS keys, SNS subscriptions, or a provider configuration.

It creates monitoring and notification policies when enabled. An APPLY role can
also receive diagnostics: only `s3:PutObject` to its own
`cloud5/ci-diagnostics/v1/<environment>/` prefix with SSE-S3 (`AES256`). PLAN
roles cannot enable that policy.

The module accepts `dev`, `test`, and `prod` for reusable policy tests, but
this change instantiates only DEV and TEST. PROD is deliberately not instantiated.

## Required contract

- `name_prefix` and `role_name` must exactly describe the same approved role.
- The project region is `eu-west-1`; the state bucket is the approved private bucket.
- `common_tags` must retain Project, Owner, ManagedBy, Environment, and Component.
- No policy grants `kms:*`, `iam:*`, SNS publishing/subscription, or cross-environment S3.

DEV diagnostics intentionally remain in the existing APPLY inline policy.
`enable_diagnostics = false` on the DEV call prevents duplicate permission
until a separately reviewed state migration is approved.
