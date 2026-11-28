# IAM Terraform extensions migration runbook

## Scope and architecture

`modules/github-terraform-extensions` centralizes CloudWatch monitoring, SNS
notifications, and APPLY-only S3 diagnostics managed policies. Every instance
creates distinct AWS IAM policies for one environment and role; policies are
never shared between environments.

DEV PLAN and APPLY now use the module for monitoring and notifications. These
state-address migrations are declared and must be retained:

| Bootstrap | Old address | New address |
| --- | --- | --- |
| DEV PLAN | `aws_iam_policy.monitoring` | `module.extensions.aws_iam_policy.monitoring[0]` |
| DEV PLAN | `aws_iam_role_policy_attachment.monitoring` | `module.extensions.aws_iam_role_policy_attachment.monitoring[0]` |
| DEV PLAN | `aws_iam_policy.notifications` | `module.extensions.aws_iam_policy.notifications[0]` |
| DEV PLAN | `aws_iam_role_policy_attachment.notifications` | `module.extensions.aws_iam_role_policy_attachment.notifications[0]` |
| DEV APPLY | `aws_iam_policy.monitoring` | `module.extensions.aws_iam_policy.monitoring[0]` |
| DEV APPLY | `aws_iam_role_policy_attachment.monitoring` | `module.extensions.aws_iam_role_policy_attachment.monitoring[0]` |
| DEV APPLY | `aws_iam_policy.notifications` | `module.extensions.aws_iam_policy.notifications[0]` |
| DEV APPLY | `aws_iam_role_policy_attachment.notifications` | `module.extensions.aws_iam_role_policy_attachment.notifications[0]` |

TEST PLAN adds monitoring and notifications (four resources); TEST APPLY adds
monitoring, notifications, and diagnostics (six resources). PROD has no module
instance. DEV diagnostics remain in the pre-existing APPLY inline policy as
temporary technical debt.

## Permission matrix

| Environment / role | Monitoring | Notifications | Diagnostics |
| --- | --- | --- | --- |
| DEV PLAN | Exact dashboard/alarm reads | Exact topic reads | None |
| DEV APPLY | Exact dashboard/alarm/ASG management, tag-conditioned | Exact topic management, tag-conditioned | Existing inline AES256 PutObject only |
| TEST PLAN | Exact dashboard/alarm reads | Exact topic reads | None |
| TEST APPLY | Exact dashboard/alarm/ASG management, tag-conditioned | Exact topic management, tag-conditioned | Managed AES256 PutObject only to TEST prefix |
| PROD | Simulation only; not instantiated | Simulation only; not instantiated | Simulation only; not instantiated |

## Operator procedure (PowerShell)

Run in an authenticated human operator session. Store all artifacts outside the
repository. No command below should be run with `apply` until approval.

```powershell
$private = Join-Path $env:USERPROFILE "cloud5-private-iam-review"
New-Item -ItemType Directory -Force -Path $private | Out-Null
$bucket = "cloud5-terraform-drghassen-state-326553917564"
aws sts get-caller-identity --query Account --output text

foreach ($root in "bootstrap/github-terraform-dev-plan", "bootstrap/github-terraform-dev-apply", "bootstrap/github-terraform-test-prod-plan", "bootstrap/github-terraform-test-prod-apply") {
  terraform -chdir=$root init -input=false -reconfigure -backend-config="bucket=$bucket"
  terraform -chdir=$root state pull | Set-Content -NoNewline (Join-Path $private (($root -replace '[\\/]', '-') + '.tfstate.json'))
}

terraform -chdir=bootstrap/github-terraform-dev-plan plan -input=false -out="$private/dev-plan.tfplan"
terraform -chdir=bootstrap/github-terraform-dev-apply plan -input=false -out="$private/dev-apply.tfplan"
terraform -chdir=bootstrap/github-terraform-dev-plan show -json "$private/dev-plan.tfplan" | Set-Content "$private/dev-plan.json"
terraform -chdir=bootstrap/github-terraform-dev-apply show -json "$private/dev-apply.tfplan" | Set-Content "$private/dev-apply.json"

# DEV must have no create, update, delete, or replace action.
(Get-Content "$private/dev-plan.json" -Raw | ConvertFrom-Json).resource_changes | Where-Object { $_.change.actions -join ',' -ne 'no-op' } | Format-Table address, @{n='actions';e={$_.change.actions -join ','}}
(Get-Content "$private/dev-apply.json" -Raw | ConvertFrom-Json).resource_changes | Where-Object { $_.change.actions -join ',' -ne 'no-op' } | Format-Table address, @{n='actions';e={$_.change.actions -join ','}}

$testPlanTargets = @('module.test_extensions.aws_iam_policy.monitoring[0]', 'module.test_extensions.aws_iam_role_policy_attachment.monitoring[0]', 'module.test_extensions.aws_iam_policy.notifications[0]', 'module.test_extensions.aws_iam_role_policy_attachment.notifications[0]')
terraform -chdir=bootstrap/github-terraform-test-prod-plan plan -input=false -out="$private/test-plan-extensions.tfplan" @($testPlanTargets | ForEach-Object { "-target=$_" })

$testApplyTargets = @('module.test_extensions.aws_iam_policy.monitoring[0]', 'module.test_extensions.aws_iam_role_policy_attachment.monitoring[0]', 'module.test_extensions.aws_iam_policy.notifications[0]', 'module.test_extensions.aws_iam_role_policy_attachment.notifications[0]', 'module.test_extensions.aws_iam_policy.diagnostics[0]', 'module.test_extensions.aws_iam_role_policy_attachment.diagnostics[0]')
terraform -chdir=bootstrap/github-terraform-test-prod-apply plan -input=false -out="$private/test-apply-extensions.tfplan" @($testApplyTargets | ForEach-Object { "-target=$_" })

terraform -chdir=bootstrap/github-terraform-test-prod-plan show -json "$private/test-plan-extensions.tfplan" | Set-Content "$private/test-plan-extensions.json"
terraform -chdir=bootstrap/github-terraform-test-prod-apply show -json "$private/test-apply-extensions.tfplan" | Set-Content "$private/test-apply-extensions.json"
Get-FileHash "$private/*.tfplan" -Algorithm SHA256
```

Before approval, allow only `create` for the exact TEST addresses shown above;
reject any PROD address or other action. Extract proposed policy JSON locally,
then run IAM Access Analyzer policy validation, for example:

```powershell
aws accessanalyzer validate-policy --policy-document file://policy.json --policy-type IDENTITY_POLICY
```

Apply only saved reviewed files, never a regenerated plan:

```powershell
terraform -chdir=bootstrap/github-terraform-test-prod-plan apply "$private/test-plan-extensions.tfplan"
terraform -chdir=bootstrap/github-terraform-test-prod-apply apply "$private/test-apply-extensions.tfplan"
```

After approval, use `aws iam list-attached-role-policies` and
`aws iam get-policy-version` for the named TEST roles/policies, then run a read-only bootstrap plan confirming that no new PROD changes
were introduced by this refactoring. Previously deferred PROD IAM changes
must remain unapplied.

## Rollback

Git rollback and Terraform state rollback are distinct. After DEV address
migration, never `git revert` and apply: old addresses would propose replacement
resources. First review state and a compatible moved mapping. For TEST,
rollback requires a reviewed Terraform plan that detaches and deletes only the
ten TEST extension resources (four PLAN and six APPLY). Never use `state rm`, `state mv`, `state push`, force-unlock,
or a blind destroy.
