# Terraform Cloud Project

Infrastructure-only AWS project built with Terraform. It follows the supplied
requirements: a multi-AZ VPC, private web instances behind an ALB, private
PostgreSQL RDS, a protected S3 bucket, and separate `dev`, `test`, and `prod`
states. The web tier is a small Nginx demonstration provisioned by EC2
`user_data`; it displays each instance hostname to make load balancing visible.

## Architecture

```text
Internet
   |
Public ALB (2 public subnets / 2 AZs)
   |
Private EC2 Auto Scaling Group (2+ instances / 2 AZs)
   |                         |
Private RDS subnets        NAT egress (web subnets only)
   |
Private, encrypted, versioned S3 storage bucket
```

The DB subnets have no Internet route. RDS accepts PostgreSQL only from the
web-instance security group. Instances have no public IP; administrative
access uses AWS Systems Manager rather than inbound SSH.

## Repository layout

```text
bootstrap/                  S3 remote-state bucket
bootstrap/github-terraform-dev-plan/
                            Read-only OIDC role for DEV plans
modules/
  network/                  VPC, subnets, gateways, and routes
  security/                 Security groups and EC2 instance role
  load-balancer/            ALB, listeners, target group, health check
  compute/                  Launch Template, Nginx user_data, Auto Scaling
  database/                 Private PostgreSQL RDS and subnet group
  storage/                  Private versioned and encrypted S3 bucket
environments/{dev,test,prod}/
                            Environment roots and separate S3 state keys
.github/workflows/          Terraform validation, tests, plan, gated DEV apply
docs/                       Architecture, deployment, cost, and security notes
scripts/                    Local validation and backend initialization
```

## Requirements

- Terraform `>= 1.10.0`
- AWS CLI v2 and an authorized AWS identity (prefer AWS IAM Identity Center)
- AWS region `eu-west-1`
- Access to the approved state bucket:
  `cloud5-terraform-stockyard-drghassen-state-326553917564`

Terraform state is stored in this bucket at:

| Environment | State key |
|---|---|
| DEV | `cloud5/infrastructure/dev/terraform.tfstate` |
| TEST | `cloud5/infrastructure/test/terraform.tfstate` |
| PROD | `cloud5/infrastructure/prod/terraform.tfstate` |

These are new keys. Do not migrate, overwrite, or delete older states.

## Local workflow

Initialize DEV's remote backend from PowerShell:

```powershell
.\scripts\init-env.ps1 `
  -Environment dev `
  -Bucket "cloud5-terraform-stockyard-drghassen-state-326553917564" `
  -BackendRegion "eu-west-1"
```

Review a plan before any apply:

```powershell
terraform -chdir=environments\dev validate
terraform -chdir=environments\dev plan -out=dev.tfplan
terraform -chdir=environments\dev show -no-color dev.tfplan
```

The first deployment creates cost-bearing resources. Do not apply until the
complete plan, AWS account, region, resource names, and estimated costs have
been reviewed and explicitly approved. The GitHub workflow supports manual
plan-only runs on `main`; applying requires a separately provisioned,
reviewed DEV OIDC role and required reviewers on the protected GitHub `dev`
environment. See [CI/CD guidance](docs/dev-release-pipeline.md).

## Validation

Run local checks:

```powershell
.\scripts\check.ps1
```

The workflow runs `terraform fmt`, initializes and validates each root, runs
module tests without AWS changes, and creates a read-only DEV plan for pull
requests or manual runs from `main`. A manual run is plan-only by default;
applying requires an explicit input and protected environment approval.

## Costs and cleanup

The main recurring cost drivers are NAT Gateways and their data processing,
the public ALB, two or more EC2 instances and encrypted EBS volumes, RDS
instance/storage/backups, and S3 storage/requests. DEV uses one NAT Gateway
and a single-AZ small RDS class to limit cost; PROD defaults to two NAT
Gateways and Multi-AZ RDS. TEST is disposable and must be destroyed after its
demonstration. See [docs/costs.md](docs/costs.md) before provisioning.

Do not run `terraform destroy` against DEV or PROD without reviewing the plan
and obtaining explicit approval. Never delete or alter existing AWS stacks or
state objects as part of this refactor.
