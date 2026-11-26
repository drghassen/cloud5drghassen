# GitHub OIDC plan role for DEV

This isolated bootstrap creates the read-only GitHub Actions role used by
the automatic DEV promotion stage from `main`. It does not create
application or AWS workload resources, and it does not modify the existing
GitHub OIDC provider.

The trust policy is limited to this repository's `dev-plan` environment and
the `main` branch. The permissions can read the exact DEV state object, manage
only its lock file, and describe the infrastructure needed for a plan. They
cannot create or modify resources, read Secrets Manager values, or pass IAM
roles.

The DEV environment state key is
`cloud5/infrastructure/dev/terraform.tfstate`; TEST and PROD use separate keys.
The bootstrap itself has its own state key:
`bootstrap/drghassen/dev-plan/terraform.tfstate`.

## Review and provision

Run from the repository root in an authenticated PowerShell session. Confirm
the AWS identity before initializing:

```powershell
aws sts get-caller-identity
terraform -chdir=bootstrap\github-terraform-dev-plan init -input=false -reconfigure `
  -backend-config="bucket=cloud5-terraform-drghassen-state-326553917564"
terraform -chdir=bootstrap\github-terraform-dev-plan validate
terraform -chdir=bootstrap\github-terraform-dev-plan plan -out=dev-plan-role.tfplan
terraform -chdir=bootstrap\github-terraform-dev-plan show -no-color dev-plan-role.tfplan
```

Review the plan and confirm it creates only the IAM role and its inline policy.
Do not apply without explicit approval:

```powershell
terraform -chdir=bootstrap\github-terraform-dev-plan apply dev-plan-role.tfplan
terraform -chdir=bootstrap\github-terraform-dev-plan output -raw github_terraform_dev_plan_role_arn
```

Set the returned ARN as `AWS_TERRAFORM_DEV_PLAN_ROLE_ARN` in the GitHub
`dev-plan` environment. Do not configure long-lived AWS access keys. DEV apply
uses the separately provisioned apply role in the protected GitHub `dev`
environment; the promotion flow is documented in
`docs/dev-release-pipeline.md`.

The backend bucket in the init command is the approved state bucket; this
bootstrap's own state uses the separate key
`bootstrap/drghassen/dev-plan/terraform.tfstate`. The plan role can read only
the DEV environment state key configured by `state_bucket_name` and `state_key`.
Preserve the bootstrap state key when updating the role.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_github_terraform_dev_plan"></a> [github\_terraform\_dev\_plan](#module\_github\_terraform\_dev\_plan) | ../../modules/github-terraform-plan | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region containing the DEV deployment. | `string` | `"eu-west-1"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | AWS environment tag applied to the plan role. | `string` | `"dev"` | no |
| <a name="input_github_environment"></a> [github\_environment](#input\_github\_environment) | GitHub environment used by DEV Terraform plans. | `string` | `"dev-plan"` | no |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable numeric GitHub owner ID. | `string` | `"128297499"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository in owner/name format. | `string` | `"drghassen/cloud5drghassen"` | no |
| <a name="input_github_repository_id"></a> [github\_repository\_id](#input\_github\_repository\_id) | Immutable numeric GitHub repository ID. | `string` | `"1473229803"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used by the isolated DEV infrastructure. | `string` | `"cloud5-infra-dev"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner tag applied to the role. | `string` | `"drghassen"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag applied to the role. | `string` | `"terraform-cloud-project"` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Existing user-owned S3 bucket holding the DEV Terraform state. | `string` | `"cloud5-terraform-drghassen-state-326553917564"` | no |
| <a name="input_state_key"></a> [state\_key](#input\_state\_key) | Exact DEV Terraform state key the read-only plan role may read. | `string` | `"cloud5/infrastructure/dev/terraform.tfstate"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_terraform_dev_plan_role_arn"></a> [github\_terraform\_dev\_plan\_role\_arn](#output\_github\_terraform\_dev\_plan\_role\_arn) | ARN to set as the AWS\_TERRAFORM\_DEV\_PLAN\_ROLE\_ARN GitHub environment variable. |
<!-- END_TF_DOCS -->