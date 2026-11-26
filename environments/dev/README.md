# DEV environment

This root composes the six AWS infrastructure modules for development:
network, security, load balancer, compute, database, and storage. Compute
serves a small Nginx page installed by EC2 `user_data`.

- Region: `eu-west-1`
- State key: `cloud5/infrastructure/dev/terraform.tfstate`
- Default NAT Gateways: 1
- RDS: small Single-AZ PostgreSQL by default
- HTTP is enabled by default and uses the ALB's AWS-provided DNS name; no
  custom domain or certificate is required. Do not send sensitive data over
  this unencrypted demo endpoint. HTTPS can be enabled with an issued ACM
  certificate ARN in `eu-west-1`.

Initialize the approved S3 backend with `scripts/init-env.ps1`, review the
Terraform plan, and do not apply without explicit approval. See the root
[README](../../README.md) and [state layout](../../docs/backend-state-layout.md).

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
| <a name="module_compute"></a> [compute](#module\_compute) | ../../modules/compute | n/a |
| <a name="module_database"></a> [database](#module\_database) | ../../modules/database | n/a |
| <a name="module_load_balancer"></a> [load\_balancer](#module\_load\_balancer) | ../../modules/load-balancer | n/a |
| <a name="module_network"></a> [network](#module\_network) | ../../modules/network | n/a |
| <a name="module_security"></a> [security](#module\_security) | ../../modules/security | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ../../modules/storage | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_vpc_security_group_egress_rule.web_to_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | Optional ACM certificate ARN in eu-west-1 when HTTPS is enabled. | `string` | `""` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region used by this environment. | `string` | `"eu-west-1"` | no |
| <a name="input_db_backup_retention_period"></a> [db\_backup\_retention\_period](#input\_db\_backup\_retention\_period) | RDS automated backup retention in days. | `number` | `7` | no |
| <a name="input_db_deletion_protection"></a> [db\_deletion\_protection](#input\_db\_deletion\_protection) | Prevent accidental RDS deletion. | `bool` | `false` | no |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | RDS PostgreSQL instance class. | `string` | `"db.t3.micro"` | no |
| <a name="input_db_multi_az"></a> [db\_multi\_az](#input\_db\_multi\_az) | Enable RDS Multi-AZ standby; disabled in cost-conscious DEV. | `bool` | `false` | no |
| <a name="input_db_skip_final_snapshot"></a> [db\_skip\_final\_snapshot](#input\_db\_skip\_final\_snapshot) | Skip the RDS final snapshot on destroy; use only for disposable environments. | `bool` | `true` | no |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | Initial desired number of instances. | `number` | `2` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Prevent accidental ALB deletion. | `bool` | `false` | no |
| <a name="input_enable_https"></a> [enable\_https](#input\_enable\_https) | Enable HTTPS and redirect HTTP to HTTPS; requires an ACM certificate. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name; fixed for this root module. | `string` | `"dev"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type used by the web Auto Scaling group. | `string` | `"t3.micro"` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of instances. | `number` | `4` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of instances; at least two are required. | `number` | `2` | no |
| <a name="input_nat_gateway_count"></a> [nat\_gateway\_count](#input\_nat\_gateway\_count) | Number of NAT Gateways; one reduces DEV cost, two provide per-AZ egress. | `number` | `1` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner tag value. | `string` | `"drghassen"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag applied to resources. | `string` | `"terraform-cloud-project"` | no |
| <a name="input_resource_name_prefix"></a> [resource\_name\_prefix](#input\_resource\_name\_prefix) | Short unique prefix used in AWS resource names. | `string` | `"cloud5-infra-dev"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC IPv4 CIDR block. | `string` | `"10.20.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | Public DNS name of the Application Load Balancer. |
| <a name="output_alb_url"></a> [alb\_url](#output\_alb\_url) | Public URL of the Nginx demonstration. |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the web Auto Scaling group. |
| <a name="output_database_endpoint"></a> [database\_endpoint](#output\_database\_endpoint) | Private RDS endpoint. |
| <a name="output_database_master_user_secret_arn"></a> [database\_master\_user\_secret\_arn](#output\_database\_master\_user\_secret\_arn) | ARN of the AWS-managed secret containing the generated RDS master password. |
| <a name="output_environment"></a> [environment](#output\_environment) | Environment name. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | NAT Gateway IDs used for controlled private subnet egress. |
| <a name="output_private_app_subnet_ids"></a> [private\_app\_subnet\_ids](#output\_private\_app\_subnet\_ids) | Private application subnet IDs hosting EC2. |
| <a name="output_private_db_subnet_ids"></a> [private\_db\_subnet\_ids](#output\_private\_db\_subnet\_ids) | Private database subnet IDs hosting RDS. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs hosting the ALB. |
| <a name="output_storage_bucket_name"></a> [storage\_bucket\_name](#output\_storage\_bucket\_name) | Name of the private S3 storage bucket. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID. |
<!-- END_TF_DOCS -->