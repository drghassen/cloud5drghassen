# S3 state bucket bootstrap

This root manages the shared, private S3 bucket used by the Terraform
environment backends. It is intentionally separate from `environments/` and
uses local Terraform state. Do not configure this root to use the bucket it
creates as its own backend.

The project already has an approved environment state bucket:
`cloud5-terraform-drghassen-state-326553917564` in `eu-west-1`.
Its existing name is preserved; do not create a replacement bucket, import or
modify AWS resources, or apply this root as part of the refactor.

## New bucket only

For a genuinely new AWS account, initialize and review this root with the
intended unique bucket name:

```powershell
terraform -chdir=bootstrap init -backend=false -input=false
terraform -chdir=bootstrap plan -input=false `
  -var="state_bucket_name=<globally-unique-bucket-name>" `
  -var="aws_region=eu-west-1" `
  -out=bootstrap.tfplan
terraform -chdir=bootstrap show -no-color bootstrap.tfplan
```

Applying requires separate approval. Never apply a plan that would replace or
delete an existing bucket or its state versions. Store and back up the
bootstrap's local state securely; it must not be committed.

## Environment state

The environment roots use the shared bucket with these isolated keys:

- `cloud5/infrastructure/dev/terraform.tfstate`
- `cloud5/infrastructure/test/terraform.tfstate`
- `cloud5/infrastructure/prod/terraform.tfstate`

See [remote state layout](../docs/backend-state-layout.md) and the root
[README](../README.md) for initialization and safety rules.
