# GitHub Terraform plan role module

Defines a read-only AWS IAM role for each environment's Terraform plans from
`main` and Pull Requests through GitHub OIDC. Permissions are limited to that environment's
Terraform state and lock file plus the AWS metadata reads needed by Terraform.
The role cannot apply infrastructure, read secret values, or pass IAM roles.

The DEV role is instantiated from `bootstrap/github-terraform-dev-plan`; the
TEST and PROD roles are created by the shared test/prod bootstrap. Review each
bootstrap plan before provisioning. See `variables.tf`, `outputs.tf`, and
`github-terraform-plan.tftest.hcl` for the module interface and policy tests.

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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | AWS account ID containing the infrastructure. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Region containing the infrastructure to plan. | `string` | n/a | yes |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags applied to the role. | `map(string)` | n/a | yes |
| <a name="input_github_environment"></a> [github\_environment](#input\_github\_environment) | GitHub environment allowed to assume the plan role. | `string` | n/a | yes |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable numeric GitHub owner ID. | `string` | n/a | yes |
| <a name="input_github_ref_patterns"></a> [github\_ref\_patterns](#input\_github\_ref\_patterns) | Git reference patterns trusted for the plan role. | `list(string)` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository in owner/name format. | `string` | n/a | yes |
| <a name="input_github_repository_id"></a> [github\_repository\_id](#input\_github\_repository\_id) | Immutable numeric GitHub repository ID. | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used to name the environment Terraform plan role and managed infrastructure. | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the existing GitHub Actions OIDC provider. | `string` | n/a | yes |
| <a name="input_state_bucket_arn"></a> [state\_bucket\_arn](#input\_state\_bucket\_arn) | ARN of the existing Terraform state bucket. | `string` | n/a | yes |
| <a name="input_state_key"></a> [state\_key](#input\_state\_key) | Exact environment state key the read-only plan role may read. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | GitHub Actions OIDC role ARN for read-only environment plans. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the GitHub Actions OIDC environment plan role. |
<!-- END_TF_DOCS -->