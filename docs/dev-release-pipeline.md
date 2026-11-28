# Terraform CI/CD release procedure

The workflow defines static security checks and separate DEV, TEST and PROD
plan and apply jobs. Pull requests do not run AWS plans. A push to `main` can
plan DEV; an Apply requires an explicit `workflow_dispatch` from `main`, the
matching environment, `apply=true`, and the corresponding handoff flag.
Verify the effective GitHub environment reviewer and branch protections, AWS
permissions, bucket versioning and flag settings before any deployment: this
document does not attest their current configuration.

## DEV handoff and private review

When DEV handoff is enabled, Plan stores its binary in the private versioned
S3 bucket with SSE-S3 and a run/attempt-specific key. The Plan job outputs the
bucket, key, version ID, SHA-256, commit, run ID, attempt and environment.
Apply checks these against its run context, downloads the exact version and
checks the binary hash. Job Outputs provide same-run consistency, not an
independent approval of the hash. The DEV environment approval is required;
the workflow does not approve itself. A plan-only run cannot subsequently be
applied by a different run.

Before approving a pending DEV Apply, an authorized reviewer should:

1. Check the run's commit, run ID, attempt and DEV summary. The summary only
   gives metadata and counts of actions on resource instances, not details.
2. In an access-controlled workspace using read-only AWS access, download the
   exact S3 key and version from the summary with `aws s3api get-object`,
   `--version-id` and `--expected-bucket-owner 326553917564`. Use bucket
   `cloud5-terraform-drghassen-state-326553917564`. Calculate SHA-256 locally
   and compare it with the run summary before viewing the plan.
3. Privately render the binary using the matching Terraform version and
   `terraform show`, review all resource changes, ownership, costs and risks,
   and compare the counts with the summary. Plan files and output can contain
   secrets; do not publish them, and handle local copies under the applicable
   retention policy.
4. For every destruction or replacement, explicitly authorize the exact
   addresses using `TERRAFORM_DESTRUCTION_APPROVAL` in the format required by
   `check_plan_ownership.py`: JSON with `environment`, full `commit`, `sha256`
   and `addresses`. The ownership gate verifies this separately. Approve the
   GitHub DEV environment only after review and authorization are complete.

The DEV job invokes `dev_diagnostics.sh` for a private diagnostics preflight,
ownership gate and Apply. It records output under the private versioned
`cloud5/ci-diagnostics/v1/dev/<run>/<attempt>/` prefix. If the preflight fails,
Apply is not started; if upload fails after execution, inspect AWS and state
before deciding what to do. Plan failure diagnostics use the separate private
plan diagnostics prefix. Do not put diagnostic contents in public logs.

An Apply uses the saved plan and Terraform rejects a stale state snapshot.
AWS may change independently after planning. A rerun has a distinct attempt;
review its newly produced plan and metadata again. A stale or missing plan
requires a fresh plan and review, not reuse of an earlier approval.

## TEST and PROD

Their handoff flags are independent. The current workflow deliberately fails
their Apply jobs at the private diagnostics guard before AWS credentials are
configured. The existing environment approval, manual approved SHA/commit,
ownership and destruction gates remain in place; removing the guard or enabling
an environment requires separately reviewed work.

## Failure and rollback

Do not automatically retry a failed Apply or assume a rollback occurred.
Retrieve the exact private diagnostic version, identify the failed resource
and API action, and inspect actual AWS resources and the remote Terraform
state. Preserve evidence securely. For rollback, first assess impact and state,
then prepare and review a new corrective configuration and plan, including any
destructions, and obtain the required approvals. Do not edit state manually or
run an independent destroy as an automatic recovery step.
