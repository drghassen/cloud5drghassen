# Database module

Creates a private PostgreSQL RDS instance and DB subnet group across the
private database subnets. Storage is encrypted, backups are configurable, and
the master password is generated and managed by AWS Secrets Manager. The DB
security group accepts PostgreSQL only from the supplied web security group.

The password value is never output by Terraform. See `variables.tf` and
`outputs.tf` for the module interface, and `database.tftest.hcl` for plan-only
tests.

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
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_security_group.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_ingress_rule.from_web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Initial allocated database storage in GiB. | `number` | `20` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Automated backup retention in days. | `number` | `7` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags applied to database resources. | `map(string)` | `{}` | no |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | RDS PostgreSQL instance class. | `string` | `"db.t3.micro"` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Initial PostgreSQL database name. | `string` | `"cloud5db"` | no |
| <a name="input_db_username"></a> [db\_username](#input\_db\_username) | RDS master username; its generated password is stored by AWS Secrets Manager. | `string` | `"cloud5admin"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to prevent accidental RDS deletion. | `bool` | `false` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Maximum storage autoscaling limit in GiB. | `number` | `100` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Whether to deploy RDS with a synchronous standby in another Availability Zone. | `bool` | `false` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used to name database resources. | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private database subnet IDs in separate Availability Zones. | `list(string)` | n/a | yes |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip the final snapshot when destroying RDS; use only for disposable environments. | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID hosting the database. | `string` | n/a | yes |
| <a name="input_web_security_group_id"></a> [web\_security\_group\_id](#input\_web\_security\_group\_id) | Security group allowed to connect to PostgreSQL. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_db_address"></a> [db\_address](#output\_db\_address) | RDS database hostname. |
| <a name="output_db_endpoint"></a> [db\_endpoint](#output\_db\_endpoint) | RDS endpoint, including port. |
| <a name="output_db_instance_id"></a> [db\_instance\_id](#output\_db\_instance\_id) | RDS instance identifier. |
| <a name="output_db_port"></a> [db\_port](#output\_db\_port) | RDS database port. |
| <a name="output_db_security_group_id"></a> [db\_security\_group\_id](#output\_db\_security\_group\_id) | Security group ID protecting the RDS instance. |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | ARN of the AWS-managed secret containing the generated RDS master password. |
<!-- END_TF_DOCS -->