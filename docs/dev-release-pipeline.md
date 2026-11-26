# Terraform promotion pipeline

The repository is infrastructure-only. `.github/workflows/terraform.yml`
runs static checks on pull requests and pushes to `main`. Pull requests do not
receive AWS credentials and never plan or apply infrastructure.

## Automatic order on `main`

The scan, lint, workflow-audit, Terraform validation, and module-test jobs
start in parallel. Each environment stage waits for all of them to pass, then
promotion proceeds sequentially:

1. **DEV:** create a read-only plan and upload its readable output, binary plan,
   and SHA-256 digest; wait for approval in the `dev` GitHub environment; apply
   only that uploaded plan.
2. **TEST:** starts only after DEV apply succeeds; plan, wait for approval in
   `test`, then apply the exact plan.
3. **PROD:** starts only after TEST apply succeeds; plan, wait for approval in
   `prod`, then apply the exact plan.

The next environment cannot plan or apply until the previous environment has
completed. A rejected or failed apply stops the promotion chain. Manual
`workflow_dispatch` from `main` runs the same sequence; dispatching another
branch runs checks only.

Before any apply role is assumed, the job confirms that `main` still points to
the commit that produced the plan. This prevents approval of an outdated plan
after a newer commit has been pushed. The binary plan and digest are retained
for seven days; approve before expiration. No apply job creates a fresh plan
or runs `terraform destroy`.

The scan, lint, workflow-audit, validation, and module-test jobs are peers;
one scan does not launch the others. The stage jobs use `needs` to wait for
all required gates and then sequence DEV -> TEST -> PROD. The `dev-plan`,
`test-plan`, and `prod-plan` environments must not have required reviewers;
approval gates belong on `dev`, `test`, and `prod`.

## GitHub configuration

Configure these GitHub Actions **variables** before pushing a workflow update
that enables automatic promotion:

| Scope | Variable | Purpose |
|---|---|---|
| Repository | `TERRAFORM_STATE_BUCKET` | Existing S3 backend bucket |
| Repository | `AWS_TERRAFORM_DEV_PLAN_ROLE_ARN` | Read-only DEV plan role |
| Repository | `AWS_TERRAFORM_TEST_PLAN_ROLE_ARN` | Read-only TEST plan role |
| Repository | `AWS_TERRAFORM_PROD_PLAN_ROLE_ARN` | Read-only PROD plan role |
| `dev` | `AWS_TERRAFORM_DEV_APPLY_ROLE_ARN` | DEV apply role |
| `test` | `AWS_TERRAFORM_TEST_APPLY_ROLE_ARN` | TEST apply role |
| `prod` | `AWS_TERRAFORM_PROD_APPLY_ROLE_ARN` | PROD apply role |

Add `drghassen` as a required reviewer for the `dev`, `test`, and `prod`
environments. The same account can approve its own deployment unless GitHub's
prevent-self-review control is enabled and supported for the repository. This
is a manual gate, not independent review if the initiator is also the only
reviewer. Protect `main` with required reviews/status checks for a stronger
separation of duties.

The `dev-plan`, `test-plan`, and `prod-plan` roles are read-only for their
matching environment state and AWS metadata. They are restricted to the new
repository, its immutable GitHub owner/repository IDs, the matching plan
environment, and `main`. The apply roles are separate, scoped to only their
environment's state key and named/tagged AWS resources, and trusted only by
the matching protected GitHub environment on `main`. All roles use GitHub
OIDC; do not configure static AWS access keys.

The DEV roles are maintained in
`bootstrap/github-terraform-dev-plan` and
`bootstrap/github-terraform-dev-apply`. The TEST/PROD plan and apply roles are
maintained in `bootstrap/github-terraform-test-prod-plan` and
`bootstrap/github-terraform-test-prod-apply`; each bootstrap has a separate
Terraform state key. Review bootstrap plans before provisioning roles. These
bootstrap roots create IAM roles and policies only, not workload resources.

## Checks and deployment safety

The workflow runs Gitleaks, Checkov, TFLint, zizmor, recursive Terraform
formatting and validation, and Terraform module tests. Static checks do not
receive AWS credentials. Checkov failures are not suppressed globally;
accepted exceptions are recorded next to affected Terraform resources and
explained in [security decisions](./security/README.md).

Each environment plan uses its committed `terraform.tfvars.example` and its
isolated state key:

| Environment | State key |
|---|---|
| DEV | `cloud5/infrastructure/dev/terraform.tfstate` |
| TEST | `cloud5/infrastructure/test/terraform.tfstate` |
| PROD | `cloud5/infrastructure/prod/terraform.tfstate` |

Review the plan artifact and estimated costs before approving. TEST is
disposable; PROD defaults include cost-bearing high-availability settings,
including two NAT Gateways and Multi-AZ RDS. HTTP is used with the ALB's AWS
DNS name and is unencrypted; do not send credentials or sensitive data through
these demonstration endpoints. See [cost guidance](./costs.md).

Workflow concurrency prevents simultaneous promotion runs and never cancels a
possibly active apply. If `main` advances while a run is waiting for approval,
cancel that older run manually so the newest run can start. If an old run
reaches its apply job, the stale-commit checks reject it before applying.
