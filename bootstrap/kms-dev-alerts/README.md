# DEV Alerts KMS Bootstrap

Creates the dedicated customer-managed KMS key
for Cloud5 DEV SNS notifications.

## Resources

- Symmetric KMS encryption key.
- Alias: alias/cloud5-infra-dev-alerts.
- Automatic key rotation.
- Terraform prevent_destroy protection.

## State Management

This bootstrap uses an independent local state.

Keep secure backups outside the Git repository.
Never commit Terraform state or saved plans.

## Security

The workload CI/CD roles do not administer this key.

CloudWatch and SNS receive scoped cryptographic
permissions required for encrypted notifications.

## Lifecycle

Apply changes only after reviewing a saved plan.

Do not delete or disable the key while the SNS
topic depends on it.

The customer-managed key incurs AWS charges.
