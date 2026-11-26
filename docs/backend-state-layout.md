# Terraform remote state

The three environment roots use one approved S3 bucket in `eu-west-1`, with
independent keys and native S3 lock files (`use_lockfile = true`):

| Environment | State key |
|---|---|
| DEV | `cloud5/infrastructure/dev/terraform.tfstate` |
| TEST | `cloud5/infrastructure/test/terraform.tfstate` |
| PROD | `cloud5/infrastructure/prod/terraform.tfstate` |

The currently approved bucket is
`cloud5-terraform-drghassen-state-326553917564`.

## Backend configuration

Each environment's `backend.tf` contains only the key, encryption setting, and
native lock-file setting. The bucket name and region are supplied at
initialization so they are not duplicated in the root configuration:

```powershell
.\scripts\init-env.ps1 `
  -Environment dev `
  -Bucket "cloud5-terraform-drghassen-state-326553917564" `
  -BackendRegion "eu-west-1"
```

The script runs only `terraform init`. It never migrates state, applies
resources, deletes locks, or reconfigures a backend.

## Safety

- Never place state, plan files, credentials, or secret variable files in Git.
- Review the account, region, key, and plan before any apply.
- Do not migrate, overwrite, or delete existing state objects without explicit
  authorization and a separately reviewed migration plan.
- Terraform's `.tflock` object is managed by Terraform; do not remove it while
  an operation is active.
- Preserve the existing bucket and historical state objects.

See the root [README](../README.md) for validation and deployment commands.
