# Infrastructure CI/CD

The repository is infrastructure-only. It does not build, package, migrate, or
release an application. The EC2 compute module uses `user_data` to install
Nginx for the infrastructure demonstration.

## Pull requests and pushes to `main`

`.github/workflows/terraform.yml` performs:

1. Workflow security analysis with zizmor, secret scanning with Gitleaks, IaC
   scanning with Checkov, and Terraform linting with TFLint.
2. Recursive Terraform formatting check.
3. Backend-free initialization and validation for the state-bucket,
   DEV plan-role and apply-role bootstraps, and `dev`, `test`, and
   `prod` roots.
4. Terraform tests for the infrastructure modules, including the DEV plan-role
   and apply-role modules.
5. On manually dispatched DEV runs from `main` only, a read-only plan using
   GitHub OIDC. Pull requests receive no AWS credentials and do not run plans.
   The readable plan, binary plan, and SHA-256 digest are uploaded as a
   short-lived artifact.

The static scans and Terraform validation run without AWS credentials. DEV
planning is blocked unless all scan, validation, and module-test jobs pass.
Checkov failures are not suppressed globally; accepted, cost- or scope-related
exceptions are recorded next to the affected Terraform resources and explained
in [security decisions](./security/README.md).

The DEV plan job requires these GitHub `dev-plan` environment variables:

| Variable | Purpose |
|---|---|
| `AWS_TERRAFORM_DEV_PLAN_ROLE_ARN` | Read-only AWS role for manual DEV plans |
| `TERRAFORM_STATE_BUCKET` | Existing S3 backend bucket name |

The role is defined in `bootstrap/github-terraform-dev-plan` and restricted to
the new repository/environment identity, the `main` branch, and the DEV state.
It cannot apply resources. Configure the environment variables only after the
role has been provisioned or updated through a separately reviewed process.
The DEV plan uses HTTP and the ALB-provided AWS DNS name, so it does not require
a custom domain or ACM certificate. HTTP traffic is unencrypted; do not send
credentials or sensitive data through this demonstration endpoint. HTTPS can
be enabled later by setting `enable_https` and providing an issued certificate
ARN in `eu-west-1`.

## Applying infrastructure

Manual dispatch on `main` defaults to plan-only. Setting the explicit `apply`
input enables a separate apply job targeting the GitHub `dev` environment.
The environment currently has no required reviewer, as authorized for this
individual project, so the apply proceeds without an independent approval.
The job downloads the binary plan from the same workflow run, verifies its
SHA-256, and applies only that plan. It never makes a fresh plan during the
apply job.

Before enabling apply, configure these variables in the GitHub environments:

| Environment | Variable | Purpose |
|---|---|---|
| `dev-plan` | `AWS_TERRAFORM_DEV_PLAN_ROLE_ARN` | Read-only plan role ARN |
| `dev-plan` and `dev` | `TERRAFORM_STATE_BUCKET` | Existing S3 backend bucket |
| `dev` | `AWS_TERRAFORM_DEV_APPLY_ROLE_ARN` | Separately provisioned DEV apply role ARN |

The apply role is provisioned by `bootstrap/github-terraform-dev-apply`. It
trusts only this repository's `dev` environment on `main`, uses GitHub OIDC
(no static keys), accesses only the DEV state key and lock, and has scoped
permissions for the Terraform-managed DEV resources. Add required reviewers
to `dev` and protect `main` before using this for a long-lived or sensitive
environment; without those protections, an authorized manual dispatch can
apply changes without independent review.

The plan artifact contains a Terraform binary plan and may include sensitive
infrastructure details. It is retained for seven days; restrict repository
access. If environment reviewers are configured later, approve the apply job
before the artifact expires. Manual workflow runs are not canceled by later
pushes, to avoid interrupting an apply.
The current application-release workflows and roles were removed and must not
be reused.

## Runner permissions and concurrency

Plan jobs request only GitHub `contents: read` and `id-token: write`; validation
and module-test jobs do not request AWS credentials. Apply is never triggered
on push or pull request, and no workflow runs `terraform destroy`.
