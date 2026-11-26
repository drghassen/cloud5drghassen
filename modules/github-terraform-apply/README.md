# GitHub Terraform apply role module

Defines a GitHub OIDC role for applying one environment's Terraform
infrastructure. The trust is limited to the configured repository,
environment, and `main`; state permissions are limited to one state object
and lock file. Resource permissions are scoped by the environment-specific
name prefix and tags, including `iam:PassRole` only for that environment's
web instance role and only to EC2.

Instantiate this module from the environment-specific bootstrap roots. Review
each role's Terraform plan before provisioning.

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
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Region containing the environment infrastructure. | `string` | n/a | yes |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Tags applied to the GitHub Actions role. | `map(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment tag used to scope the apply role. | `string` | n/a | yes |
| <a name="input_github_environment"></a> [github\_environment](#input\_github\_environment) | GitHub environment allowed to assume the apply role. | `string` | n/a | yes |
| <a name="input_github_owner_id"></a> [github\_owner\_id](#input\_github\_owner\_id) | Immutable numeric GitHub owner ID. | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository in owner/name format. | `string` | n/a | yes |
| <a name="input_github_repository_id"></a> [github\_repository\_id](#input\_github\_repository\_id) | Immutable numeric GitHub repository ID. | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used to name the environment role and its managed resources. | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the existing GitHub Actions OIDC provider. | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag required for EC2 resource creation. | `string` | n/a | yes |
| <a name="input_state_bucket_arn"></a> [state\_bucket\_arn](#input\_state\_bucket\_arn) | ARN of the shared Terraform state bucket. | `string` | n/a | yes |
| <a name="input_state_key"></a> [state\_key](#input\_state\_key) | Exact environment Terraform state key the role may update. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | GitHub Actions OIDC role ARN for the approved environment apply. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the GitHub Actions OIDC environment apply role. |
<!-- END_TF_DOCS -->