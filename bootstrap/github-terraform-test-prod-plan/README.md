# GitHub OIDC plan roles for TEST and PROD

This bootstrap creates separate read-only plan roles for TEST and PROD. Each
role trusts only its GitHub environment on `main` and can read only that
environment's Terraform state and lock file. It does not create workload
resources.

The bootstrap state key is
`bootstrap/drghassen/test-prod-plan/terraform.tfstate` in the approved state
bucket. Initialize, review, and apply the roles before running the promotion
pipeline:

```powershell
terraform -chdir=bootstrap\github-terraform-test-prod-plan init -input=false -reconfigure `
  -backend-config="bucket=cloud5-terraform-drghassen-state-326553917564"
terraform -chdir=bootstrap\github-terraform-test-prod-plan validate
terraform -chdir=bootstrap\github-terraform-test-prod-plan plan -out=<path-outside-repository>\plan-roles.tfplan
terraform -chdir=bootstrap\github-terraform-test-prod-plan show -no-color <path-outside-repository>\plan-roles.tfplan
```

Apply only after confirming the plan creates or updates the two plan roles:

```powershell
terraform -chdir=bootstrap\github-terraform-test-prod-plan apply <path-outside-repository>\plan-roles.tfplan
terraform -chdir=bootstrap\github-terraform-test-prod-plan output -json github_terraform_test_prod_plan_role_arns
```

Set the returned TEST and PROD ARNs as repository variables
`AWS_TERRAFORM_TEST_PLAN_ROLE_ARN` and `AWS_TERRAFORM_PROD_PLAN_ROLE_ARN`.
The shared `TERRAFORM_STATE_BUCKET` repository variable must point to the
approved bucket.

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
| <a name="module_github_terraform_plan"></a> [github\_terraform\_plan](#module\_github\_terraform\_plan) | ../../modules/github-terraform-plan | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Region containing the Terraform environments. | `string` | `"eu-west-1"` | no |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable numeric GitHub owner ID. | `string` | `"128297499"` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository in owner/name format. | `string` | `"drghassen/cloud5drghassen"` | no |
| <a name="input_github_repository_id"></a> [github\_repository\_id](#input\_github\_repository\_id) | Immutable numeric GitHub repository ID. | `string` | `"1473229803"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner tag applied to the plan roles. | `string` | `"drghassen"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag applied to the plan roles. | `string` | `"terraform-cloud-project"` | no |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Existing bucket containing the environment state objects. | `string` | `"cloud5-terraform-drghassen-state-326553917564"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_github_terraform_test_prod_plan_role_arns"></a> [github\_terraform\_test\_prod\_plan\_role\_arns](#output\_github\_terraform\_test\_prod\_plan\_role\_arns) | Read-only plan role ARNs keyed by environment. |
<!-- END_TF_DOCS -->