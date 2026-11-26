# Cost review before provisioning

The DEV, TEST, and PROD environment configurations have not been applied as
part of this refactor. The unused `bootstrap/dns` configuration was removed.
Its current local state was empty, while its older backup contained four
resource entries; this does not confirm whether any DNS resources still exist
in AWS. Verify Route 53 in the AWS account before assuming they were deleted.
Review current AWS prices and the actual Terraform plan before provisioning
other resources.

## Recurring cost drivers

| Resource | DEV / TEST defaults | PROD defaults | Cost notes |
|---|---|---|---|
| NAT Gateway | 1 per environment | 2 | Hourly charge plus processed data and public IPv4; usually a major fixed cost |
| Application Load Balancer | 1 per environment | 1 | Hourly charge plus LCU usage and public IPv4 |
| EC2 Auto Scaling | 2 `t3.micro` instances | 2 `t3.small` instances | Instance-hours, EBS volumes, data transfer, and any scaling above desired capacity |
| RDS PostgreSQL | `db.t3.micro`, Single-AZ | `db.t3.small`, Multi-AZ | DB instance-hours, allocated storage, backups, and I/O |
| S3 storage | 1 bucket | 1 bucket | Stored data, requests, and retained object versions |
| DNS resources from the removed bootstrap | Not required for HTTP access | Not required for HTTP access | AWS status is unverified; any hosted zones still present incur recurring charges |
| Public IPv4 / transfer | Depends on provisioned services | Depends on provisioned services | Internet egress and public addresses can add charges |

These are configured size defaults, not a price quote. Estimate using the
planned hours, storage sizes, expected network transfer, backup retention, and
current AWS pricing. TEST resources should be destroyed after the approved test
window; never destroy DEV or PROD without explicit approval.

The ALB's AWS-provided DNS name works over HTTP without buying a domain or
certificate, but the ALB and other AWS resources are not free. Removing the
DNS Terraform code does not delete AWS resources. Verify whether any hosted
zones remain, then use a separately reviewed and approved change if cleanup
is needed; no DNS destroy or AWS change was performed here.

## Before applying

1. Confirm the AWS account and `eu-west-1` region.
2. Review every resource and default in the saved plan.
3. Estimate monthly cost with the AWS Pricing Calculator or current regional
   pricing data, including NAT and public IPv4 charges.
4. Record the estimate and obtain approval before creating resources.
5. Monitor actual spend and clean up only the explicitly approved environment.
