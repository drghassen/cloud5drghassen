# Terraform CI/CD pipeline

The repository uses a single workflow file, `.github/workflows/terraform.yml`,
aligned with the project specification while preserving all security and quality
scans.

## Pipeline stages

1. **Scans and static checks (no AWS credentials):**
   - `security-scans`: Gitleaks secret scanning and Checkov IaC scanning.
   - `terraform-lint`: TFLint recursive check.
   - `workflow-security`: `zizmor` security audit of `.github/workflows`.
   - `terraform-module-tests`: Bootstrap validation, module `terraform test`,
     and workflow contract tests.
2. **Pull Requests (`pull_request`):**
   - After scans pass, runs `plan-dev`, `plan-test`, and `plan-prod` in
     read-only mode via GitHub OIDC (`dev-plan`, `test-plan`, `prod-plan`).
   - Executes `terraform fmt -check -recursive`, `terraform init -input=false`,
     `terraform validate`, `terraform plan -input=false -out=tfplan`, and
     `terraform show -no-color tfplan > plan.txt`.
   - Publishes `tfplan` and `plan.txt` as workflow artifacts and writes the
     readable plan to the GitHub Step Summary. Never runs `apply`.
3. **Push to `main` (`push`) and manual runs (`workflow_dispatch`):**
   - On `push` to `main`, promotion runs sequentially:
     - `plan-dev` -> `apply-dev` (`environment: dev`)
     - `plan-test` -> `apply-test` (`environment: test`, manual approval gate)
     - `plan-prod` -> `apply-prod` (`environment: prod`, mandatory manual approval gate)
   - On `workflow_dispatch`, the operator explicitly selects `environment`
     (`dev`, `test`, or `prod`) and whether to `apply` (`true`/`false`).
   - `apply-*` jobs only run from `refs/heads/main`, verify the `tfplan.sha256`
     checksum, and apply the exact saved `tfplan`.

## GitHub configuration

Configure these GitHub Actions **variables** (using GitHub OIDC, no static AWS
access keys):

| Scope | Variable | Purpose |
|---|---|---|
| Repository | `TERRAFORM_STATE_BUCKET` | Existing S3 backend bucket |
| Repository | `AWS_TERRAFORM_DEV_PLAN_ROLE_ARN` | Read-only DEV plan role |
| Repository | `AWS_TERRAFORM_TEST_PLAN_ROLE_ARN` | Read-only TEST plan role |
| Repository | `AWS_TERRAFORM_PROD_PLAN_ROLE_ARN` | Read-only PROD plan role |
| `dev` | `AWS_TERRAFORM_DEV_APPLY_ROLE_ARN` | DEV apply role |
| `test` | `AWS_TERRAFORM_TEST_APPLY_ROLE_ARN` | TEST apply role |
| `prod` | `AWS_TERRAFORM_PROD_APPLY_ROLE_ARN` | PROD apply role |

Configure required reviewers in GitHub Environments for `test` and `prod`
(mandatory manual approval before `apply`). Keep `dev-plan`, `test-plan`, and
`prod-plan` without required reviewers so Pull Request and plan stages can
produce `tfplan` and `plan.txt` automatically after scans pass.

The read-only plan roles (`bootstrap/github-terraform-dev-plan` and
`bootstrap/github-terraform-test-prod-plan`) trust `refs/heads/main` and
`refs/pull/*/merge` for their matching `*-plan` GitHub environment. The apply
roles (`bootstrap/github-terraform-dev-apply` and
`bootstrap/github-terraform-test-prod-apply`) trust only `refs/heads/main`.

## Isolated state keys

| Environment | State key |
|---|---|
| DEV | `cloud5/infrastructure/dev/terraform.tfstate` |
| TEST | `cloud5/infrastructure/test/terraform.tfstate` |
| PROD | `cloud5/infrastructure/prod/terraform.tfstate` |

See [cost guidance](./costs.md) and [security decisions](./security/README.md).
