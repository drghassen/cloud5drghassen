# GitHub OIDC apply role for DEV

This bootstrap creates the separate DEV GitHub Actions apply role. Its trust
is limited to `drghassen/cloud5drghassen`, the `dev` GitHub environment, and
the `main` branch. Its policy scopes Terraform state to the DEV key, limits
`iam:PassRole` to the DEV EC2 instance role, and grants only the actions used
by the project's DEV resources in `eu-west-1`.

The GitHub `dev` environment must have a required reviewer before the automatic
promotion workflow is enabled. The workflow applies only the binary plan
created in that same run. Add main-branch protection before using this for
anything beyond a disposable demonstration.

## Plan and provision

Run from the repository root in an authenticated PowerShell session:

```powershell
aws sts get-caller-identity
terraform -chdir=bootstrap\github-terraform-dev-apply init -input=false `
  -backend-config="bucket=cloud5-terraform-drghassen-state-326553917564"
terraform -chdir=bootstrap\github-terraform-dev-apply validate
terraform -chdir=bootstrap\github-terraform-dev-apply plan -out=<path-outside-repository>\dev-apply-role.tfplan
terraform -chdir=bootstrap\github-terraform-dev-apply show -no-color <path-outside-repository>\dev-apply-role.tfplan
```

Confirm that the plan creates only the apply role and its inline policy. Apply
only after reviewing the plan:

```powershell
terraform -chdir=bootstrap\github-terraform-dev-apply apply <path-outside-repository>\dev-apply-role.tfplan
terraform -chdir=bootstrap\github-terraform-dev-apply output -raw github_terraform_dev_apply_role_arn
```

Set the returned ARN as `AWS_TERRAFORM_DEV_APPLY_ROLE_ARN` in the GitHub
`dev` environment. Set `TERRAFORM_STATE_BUCKET` in both `dev` and `dev-plan`,
and set `AWS_TERRAFORM_DEV_PLAN_ROLE_ARN` in `dev-plan`. Do not create static
AWS access-key secrets.

The role intentionally does not create IAM service-linked roles. If an AWS
service-linked role is missing, provision that prerequisite separately with
an administrator and review the resulting role before retrying.
