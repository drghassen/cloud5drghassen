# GitHub OIDC apply roles for TEST and PROD

This bootstrap creates separate TEST and PROD apply roles. Each trust is
limited to the matching GitHub environment on `main`; permissions are scoped
to the matching state key and the environment-specific AWS resource names and
tags. It creates no workload resources.

The bootstrap state key is
`bootstrap/drghassen/test-prod-apply/terraform.tfstate` in the approved state
bucket. Initialize, review, and apply these roles before running the
promotion pipeline:

```powershell
terraform -chdir=bootstrap\github-terraform-test-prod-apply init -input=false -reconfigure `
  -backend-config="bucket=cloud5-terraform-drghassen-state-326553917564"
terraform -chdir=bootstrap\github-terraform-test-prod-apply validate
terraform -chdir=bootstrap\github-terraform-test-prod-apply plan -out=<path-outside-repository>\apply-roles.tfplan
terraform -chdir=bootstrap\github-terraform-test-prod-apply show -no-color <path-outside-repository>\apply-roles.tfplan
```

Apply only after confirming the plan creates or updates the two scoped roles:

```powershell
terraform -chdir=bootstrap\github-terraform-test-prod-apply apply <path-outside-repository>\apply-roles.tfplan
terraform -chdir=bootstrap\github-terraform-test-prod-apply output -json github_terraform_test_prod_apply_role_arns
```

Set the returned ARNs as `AWS_TERRAFORM_TEST_APPLY_ROLE_ARN` in the GitHub
`test` environment and `AWS_TERRAFORM_PROD_APPLY_ROLE_ARN` in `prod`. Add
required reviewers to both environments before allowing the pipeline to
promote workload changes.

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
| <a name="module_github_terraform_apply"></a> [github\_terraform\_apply](#module\_github\_terraform\_apply) | ../../modules/github-terraform-apply | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Region containing the Terraform environments. | `string` | `"eu-west-1"` | no |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable numeric GitHub owner ID. | `string` | `"128297499"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository in owner/name format. | `string` | `"drghassen/cloud5drghassen"` | no |
| <a name="input_github_repository_id"></a> [github\_repository\_id](#input\_github\_repository\_id) | Immutable numeric GitHub repository ID. | `string` | `"1473229803"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner tag applied to the apply roles. | `string` | `"drghassen"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag used to scope environment resources. | `string` | `"terraform-cloud-project"` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Existing bucket containing the environment state objects. | `string` | `"cloud5-terraform-drghassen-state-326553917564"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_terraform_test_prod_apply_role_arns"></a> [github\_terraform\_test\_prod\_apply\_role\_arns](#output\_github\_terraform\_test\_prod\_apply\_role\_arns) | Apply role ARNs keyed by environment. |
<!-- END_TF_DOCS -->