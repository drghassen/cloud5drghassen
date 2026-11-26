# Compute module

Creates a Launch Template and multi-AZ Auto Scaling Group of private Amazon
Linux 2023 instances. EC2 `user_data` installs Nginx and serves a demonstration
page that displays the instance hostname. The web tier uses the supplied
instance profile and security group, encrypted gp3 root volumes, and a
CPU-target tracking policy.

See `variables.tf` and `outputs.tf` for the module interface, and
`compute.tftest.hcl` for plan-only tests.

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
| [aws_autoscaling_group.web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.cpu_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_launch_template.web](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags applied to compute resources. | `map(string)` | `{}` | no |
| <a name="input_cpu_target_utilization"></a> [cpu\_target\_utilization](#input\_cpu\_target\_utilization) | Average CPU utilization target used for Auto Scaling. | `number` | `60` | no |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | Initial and maintained number of web instances. | `number` | `2` | no |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period) | Seconds to wait after launch before evaluating load balancer health. | `number` | `300` | no |
| <a name="input_instance_profile_name"></a> [instance\_profile\_name](#input\_instance\_profile\_name) | EC2 instance profile used for Systems Manager access. | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type used by the web Auto Scaling group. | `string` | `"t3.micro"` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of web instances. | `number` | `4` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of web instances. | `number` | `2` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used to name compute resources. | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private application subnet IDs in separate Availability Zones. | `list(string)` | n/a | yes |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Encrypted gp3 root volume size in GiB. | `number` | `20` | no |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | HTTP target group ARN used by the web Auto Scaling group. | `string` | n/a | yes |
| <a name="input_web_security_group_id"></a> [web\_security\_group\_id](#input\_web\_security\_group\_id) | Security group attached to the private web instances. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | Amazon Linux 2023 AMI selected for the web instances. |
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | ARN of the web Auto Scaling group. |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the web Auto Scaling group. |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the web Launch Template. |
| <a name="output_launch_template_version"></a> [launch\_template\_version](#output\_launch\_template\_version) | Latest Launch Template version used by the Auto Scaling group. |
<!-- END_TF_DOCS -->