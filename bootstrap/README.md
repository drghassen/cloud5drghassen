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

## Diagnostics security and operator review

Apply diagnostics use `cloud5/ci-diagnostics/v1/{dev,test,prod}/`; failed
PLAN logs remain under `cloud5/ci-plans/v1/{environment}/`. The bucket policy
denies access to each diagnostics prefix except account root, `drghassen`, and
that environment's APPLY role. APPLY may write with explicit AES256, but is
denied reads and deletes and access to other diagnostics prefixes. PLAN roles
are denied object access. Root and owner still need identity permissions.
These object-prefix controls do not fully isolate bucket-level operations such
as ListBucket. No PROD identity permission or pipeline is activated here.

DEV and TEST diagnostics expire after 7 days; noncurrent versions expire
after 1 day. Lifecycle processing also applies to objects and versions already
present, asynchronously. PROD has no dedicated diagnostics expiration rule.
The existing global 90-day noncurrent-version rule still applies. Reverting a
lifecycle configuration cannot recover permanently deleted versions.

Before any approved change, verify the account and make a private copy of the
local state without exposing its contents. Inventory both current objects and
versions for each diagnostics prefix and retain the results privately:

```powershell
aws sts get-caller-identity
$review = Join-Path $env:USERPROFILE 'cloud5-private-s3-review'
New-Item -ItemType Directory -Force $review | Out-Null
Copy-Item -LiteralPath bootstrap/terraform.tfstate -Destination "$review/bootstrap-state-backup.tfstate"
$bucket = 'cloud5-terraform-drghassen-state-326553917564'
foreach ($envName in 'dev','test','prod') {
  aws s3api list-objects-v2 --bucket $bucket --expected-bucket-owner 326553917564 --prefix "cloud5/ci-diagnostics/v1/$envName/" --output json | Set-Content "$review/$envName-objects.json"
  aws s3api list-object-versions --bucket $bucket --expected-bucket-owner 326553917564 --prefix "cloud5/ci-diagnostics/v1/$envName/" --output json | Set-Content "$review/$envName-versions.json"
}
terraform -chdir=bootstrap init -backend=false -input=false
terraform -chdir=bootstrap plan -input=false -var="state_bucket_name=$bucket" -out="$review/backend.tfplan"
terraform -chdir=bootstrap show -no-color "$review/backend.tfplan"
Get-FileHash "$review/backend.tfplan" -Algorithm SHA256
```

Review the saved plan privately: only updates to `aws_s3_bucket_policy.state`
and `aws_s3_bucket_lifecycle_configuration.state` are acceptable (0 add, 2
change, 0 destroy). Review separately the already accepted bucket `policy` and
`lifecycle_rule` drift; stop on any other drift. Extract the planned policy
locally and run `aws accessanalyzer validate-policy --policy-type RESOURCE_POLICY
--validate-policy-resource-type AWS::S3::Bucket --policy-document file://<private-policy.json>`.
After separate approval, apply only the saved reviewed plan. Verify with real
OIDC sessions in a separately approved controlled test: matching APPLY can put
an AES256 test object, while missing/wrong encryption, reads, deletes, other
environments and PLAN object access must be denied. Use isolated test keys and
an authorized operator for any cleanup. Check bucket-level permissions separately.

For rollback, review a saved plan restoring the previously approved bucket
policy and lifecycle configuration, preserve SSE-C restrictions observed in
AWS, and apply only after approval. Never replace the bucket or restore a state
blindly. A lifecycle rollback cannot restore already deleted versions.
