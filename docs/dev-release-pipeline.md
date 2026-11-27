# Terraform CI/CD

The public repository runs static checks for pull requests without AWS
credentials. The three GitHub plan environments are restricted to `main`,
independently of workflow code, because the existing role trusts permit PR
refs. Consequently even trusted PRs do not currently run AWS plans. A push to
`main` runs the DEV plan after checks; a manual dispatch selects DEV, TEST or
PROD. No push or PR triggers Apply. Each Apply requires an explicit dispatch
from `main`, a protected environment, and an approved plan from the same run.

The repository variables `TERRAFORM_DEV_S3_PLAN_HANDOFF_ENABLED`,
`TERRAFORM_TEST_S3_PLAN_HANDOFF_ENABLED`, and
`TERRAFORM_PROD_S3_PLAN_HANDOFF_ENABLED` independently control handoff and
Apply. All are currently false. TEST and PROD must remain false until their
own IAM and bucket access are reviewed and deployed. DEV's plan role writes
AES256 objects under `cloud5/ci-plans/v1/dev/`; its Apply role reads exact
object versions. The bucket and account are checked, overwrites are rejected,
and the approved commit and SHA-256 must match the downloaded binary.

Plan output is withheld from public logs. When handoff is enabled, a failed
plan's diagnostic log is written privately with SSE-S3 to the same run prefix
under `diagnostics/plan.log`; its key and version are shown in the job log.
The operator can retrieve that version with `aws s3api get-object`. No
Terraform binary or JSON plan is uploaded as a GitHub artifact.

Apply and ownership-gate output is redirected to the runner. **This output is
not retained when the runner is destroyed.** The live Apply role cannot write
to the plan prefix because the bucket policy explicitly denies it. Do not
enable an Apply until a confidential, durable failure-log mechanism
is reviewed and deployed. Every Apply job has an explicit failing guard until
that mechanism is implemented and reviewed. A possible separate change would scope
`s3:PutObject` to a dedicated diagnostics prefix, require SSE-S3 and amend
the bucket deny so Apply can write only diagnostics, never plans; it requires
its own IAM/bucket plans and approval. No such permission has been deployed.

DEV uses a required reviewer and `main` only, with administrator bypass
disabled. The sole collaborator is the owner, so independent review and
CODEOWNERS enforcement cannot be required without blocking the owner's PRs.
TEST and PROD retain their existing approval rules. The Checkov exception for
`CKV_AWS_133` applies only to DEV with zero backup retention.

## Controlled integration

1. Review the complete local diff and untracked files. Check that no state,
   plan, credential or secret is staged. Commit the reviewed files on
   `feat/mandatory-owner-abac`, then push and open a pull request:

   ```powershell
   git status --short
   git diff --check
   git add -- .
   git diff --cached --check
   git diff --cached --stat
   git commit -m "Harden Terraform pipeline and prepare DEV"
   git push -u origin feat/mandatory-owner-abac
   gh pr create --base main --head feat/mandatory-owner-abac
   ```

2. Review the PR and merge manually when authorized. Do not require a disabled
   workflow's status as a merge check. After a successful first run, configure
   appropriate required status checks and, when available, an independent
   reviewer and CODEOWNERS review.

   ```powershell
   gh pr view --repo drghassen/cloud5drghassen --web
   gh pr merge --repo drghassen/cloud5drghassen --squash
   ```

3. Only with separate authorization, re-enable the corrected workflow, confirm
   the effective DEV protections, and set only the DEV handoff variable to
   `true`. Keep TEST and PROD false.

   ```powershell
   gh workflow enable terraform.yml --repo drghassen/cloud5drghassen
   gh variable set TERRAFORM_DEV_S3_PLAN_HANDOFF_ENABLED --repo drghassen/cloud5drghassen --body true
   ```
4. Generate a DEV plan without Apply:

   ```powershell
   gh workflow run terraform.yml --ref main -f environment=dev -f apply=false
   ```

   In a private PowerShell terminal, obtain the run ID, attempt, S3 version
   and SHA-256 from that run's summary. Use an access-controlled directory:

   ```powershell
   $privateDir = 'C:\Users\dridi\.codex\cloud5-bootstrap-s3-backup-6511d8278145480490f4ebde6d38e08b'
   $runId = Read-Host 'Run ID'
   $attempt = Read-Host 'Run attempt'
   $version = Read-Host 'S3 plan version ID'
   $sha = (Read-Host 'Plan SHA-256').ToLowerInvariant()
   if ($runId -notmatch '^[1-9][0-9]*$' -or $attempt -notmatch '^[1-9][0-9]*$' -or $sha -notmatch '^[0-9a-f]{64}$' -or [string]::IsNullOrWhiteSpace($version)) { throw 'Invalid metadata' }
   $key = "cloud5/ci-plans/v1/dev/$runId/$attempt/tfplan"
   $plan = Join-Path $privateDir "dev-$runId-$attempt.tfplan"
   if (Test-Path $plan) { throw 'Refusing to overwrite existing plan' }
   aws s3api get-object --bucket cloud5-terraform-drghassen-state-326553917564 --key $key --version-id $version --expected-bucket-owner 326553917564 $plan | Out-Null
   if ($LASTEXITCODE -ne 0) { throw 'Plan download failed' }
   if ((Get-FileHash $plan -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha) { throw 'Plan hash mismatch' }
   terraform -chdir=environments/dev show -no-color $plan
   ```

   Check ownership, state, AMI and listener replacement, and review costs.
5. An `apply=false` run cannot later apply that plan. Only after the
   diagnostics blocker is resolved and Apply is separately authorized, start
   a new dispatch:

   ```powershell
   gh workflow run terraform.yml --ref main -f environment=dev -f apply=true
   ```

   It generates a **new** plan and then waits at the DEV environment.
   Privately review that run's exact binary using the download procedure above.
   Set DEV environment variables `TERRAFORM_APPROVED_PLAN_SHA256` and
   `TERRAFORM_APPROVED_COMMIT_SHA` to its lowercase SHA-256 and full commit.
   For a listener replacement, set `TERRAFORM_DESTRUCTION_APPROVAL` to JSON
   containing that same environment, commit, hash and exact address. Only then
   approve the waiting job. Do not reuse an earlier run's approval.

   For that new run only, after its private review and explicit approval:

   ```powershell
   $commit = gh api "repos/drghassen/cloud5drghassen/actions/runs/$runId" --jq .head_sha
   if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Invalid run commit' }
   gh variable set TERRAFORM_APPROVED_PLAN_SHA256 --repo drghassen/cloud5drghassen --env dev --body $sha
   gh variable set TERRAFORM_APPROVED_COMMIT_SHA --repo drghassen/cloud5drghassen --env dev --body $commit
   ```

   If that exact plan replaces the HTTP listener and its interruption was
   explicitly approved, additionally set the plan-specific approval:

   ```powershell
   $approval = @{environment='dev'; commit=$commit; sha256=$sha; addresses=@('module.load_balancer.aws_lb_listener.http')} | ConvertTo-Json -Compress
   gh variable set TERRAFORM_DESTRUCTION_APPROVAL --repo drghassen/cloud5drghassen --env dev --body $approval
   ```

If Apply fails, do not retry automatically or assume rollback. Preserve
diagnostics through the approved private mechanism and inspect AWS and state.
