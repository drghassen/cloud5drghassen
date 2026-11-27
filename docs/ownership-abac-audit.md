# DEV deployment preparation

The project prioritizes a working DEV environment. The account is shared and
complete ABAC isolation is not claimed. The first preparation did not apply or
migrate state; subsequently the user reports separately authorized S3 and DEV
IAM corrections, which were verified in AWS. See the current CI/CD guidance
for operational status and blockers.

## Controls retained

- Owner is fixed to `drghassen`; environment roots retain Project, Environment
  and ManagedBy tags and independent S3 state keys.
- GitHub plan/apply roles remain separate and use OIDC. PassRole is limited to
  the exact EC2 role and service. SSM policy attachment is limited by the exact
  `iam:PolicyARN` and role ARN; the live DEV policy contains the fix.
- Launch permissions are split between new instances/volumes, tagged existing
  launch template/subnet/security groups, Amazon-owned AMIs and private network
  interfaces. IMDSv2 is required; create-time tagging is restricted to specific
  EC2 creation actions. Auto Scaling requires a numbered template version.
- RDS-managed credentials require Secrets Manager CreateSecret/TagResource and
  KMS DescribeKey in addition to RDS permissions. The proposed policy limits
  secret actions to `rds!db-*` in the account/region, and KMS description to
  the `alias/aws/secretsmanager` key. It does not grant GetSecretValue. The
  RDS-generated secret name is not specific to this project; in a shared account
  this tagging permission is a residual limitation requiring review.
- The saved-plan check verifies ownership tags and explicit approval for
  replacements. It permits the Auto Scaling policy only when its parent group
  is present and correctly tagged. Other unsupported child changes still fail
  closed, and must be reviewed if they occur in a future plan.

## Pipeline confidentiality

The six explicitly identified historical plan artifacts were deleted; the
Actions artifacts API subsequently returned an empty list. The workflows and
logs were retained. Four associated runs were scanned with Gitleaks without a
detected secret, but historical plan-step logs still expose infrastructure
metadata. The scan does not certify that every historical log is free of
sensitive data; a separate decision is required before deleting any logs.

The proposed workflow writes binary plans to the existing private versioned
bucket only when the corresponding `TERRAFORM_<ENV>_S3_PLAN_HANDOFF_ENABLED`
variable is `true`; all flags currently remain false. It redirects
plan output away from public logs and has no GitHub plan artifact. The saved
plan's key, exact S3 version and SHA-256 are recorded as metadata. Apply is
manual, verifies the approved commit and SHA, downloads that exact version and
uses the ownership gate. TEST and PROD retain their existing environment
reviewers. DEV now requires the owner as reviewer, without administrator bypass.
No independent reviewer is currently available.

The bootstrap proposal restricts `cloud5/ci-plans/v1/{environment}/*` to the
corresponding Plan and Apply roles and the named operator; Plan writes with
SSE-S3, Apply reads the version. It adds a 7-day current-version and 1-day
noncurrent-version lifecycle for the plan prefix; actual S3 deletion is
asynchronous. The live bucket has public access blocked, versioning and SSE-S3
enabled. The local bucket bootstrap state was found at
`C:\dev\terraform-cloud-project\bootstrap\terraform.tfstate`. Its lineage,
serial, seven resource IDs, account, bucket name and region were checked against
the available local history and AWS; no evidence of a newer local copy was
found. This is strong evidence, not proof that no other state copy exists. A
confidential backup was made. A saved plan reading the original state proposes
only the bucket policy and lifecycle updates; the source hash was unchanged.
The original 90-day state lifecycle rule remains unchanged. The plan rule only
matches `cloud5/ci-plans/v1/`; no existing state or backup object version is in
that prefix. Never write state or backup files to that reserved plan prefix.
Do not create another Terraform owner, import, or migrate the state.
The DEV GitHub Plan and Apply roles have received the reviewed IAM updates.
TEST and PROD role updates remain separate. Validate effective S3 access
including explicit denies before activating handoff.

## DEV plan and prerequisites

The local saved DEV plan was generated with the current authenticated AWS user,
not the GitHub OIDC role. It proposes six security-group rules, an Auto Scaling
group and policy, and a private PostgreSQL DB; it also updates the launch
template to a newer Amazon Linux AMI and replaces the tainted HTTP listener.
The latter may interrupt HTTP. Existing referenced DEV groups, subnets, ALB,
target group, launch template and DB subnet group were checked for project
ownership; the VPC is not recreated. RDS backup retention is zero, so automated
backups are disabled. Existing NAT, ALB, EC2, EBS, RDS and Secrets Manager can
incur costs; Free Tier coverage and quotas are not guaranteed.

The live DEV Apply policy now contains the restricted attachment statement,
and the managed policy is attached. This does not establish that all
dependent permissions will succeed for every AWS operation.

IAM Access Analyzer and IAM policy simulation test proposed documents and
synthetic contexts, not actual service calls or all effective policies, SCPs,
boundaries and service-linked-role behavior. Verify them before considering
DEV ready. Review both saved plans, the listener interruption, the AMI update,
costs and RDS backup choice; obtain explicit authorization separately for any
IAM change or infrastructure apply. The working tree is not a clean committed
snapshot, so the current HEAD alone does not identify all local changes.

The current DEV default and example both use zero days of RDS automated backup.
Exception: `CKV_AWS_133` applies only to the DEV database configured with
`db_backup_retention_period = 0`; the user accepted the loss of automated
backups in the academic environment. Revisit this exception if the DEV database
contains valuable data or Free Tier restrictions change. TEST and PROD do not
share this exception. `scripts/gha/check_checkov.py` runs the normal Checkov
scan and accepts only this exact check, resource, shared-module path and DEV
caller, when the DEV default and example both specify zero. Missing information,
other findings, parsing errors and unexpected scanner failures fail closed.
Tests exercise TEST and PROD failures. This trade-off does not imply Free Tier
eligibility or a cost guarantee. The IAM simulator validates
individual decisions, not whether a complete RDS/ASG service request will
work with all dependent permissions.

On 2026-11-27 the AWS Price List API returned Ireland on-demand rates of
$0.0114/hour for Linux `t3.micro`, $0.0200/hour for PostgreSQL Single-AZ
`db.t3.micro`, and $0.0252/hour plus $0.008/LCU-hour for an ALB. At 730 hours,
two EC2 instances, one DB and one ALB total approximately $49.64 before any
eligible credits, usage allowances, taxes, data, storage, public IPs, NAT,
Secrets Manager, or LCU usage. The existing DEV NAT gateway and ALB are already
active and can incur charges even before the proposed Apply. The Pricing API
uses its `us-east-1` endpoint to retrieve `EU (Ireland)` product metadata; it
does not change deployment region. Check actual billing and account-specific
Free Tier eligibility and quotas; these rates are not a billing forecast.

## Controlled rollout and rollback

1. The S3 bootstrap and DEV Plan/Apply IAM corrections have already been
   applied separately; do not repeat those plans. Verify current access.
2. Commit/review the changes and follow the repository's manual merge process.
   The OIDC trust and environment branch restrictions must allow the exact
   branch; no merge is authorized by this document.
3. Only after prerequisites are live, enable the handoff and trigger a DEV
   `workflow_dispatch` with `apply=false`. Privately retrieve the exact S3
   version, verify its SHA, inspect the plan and state and check all ownership.
   The run with `apply=false` cannot later perform Apply: a later `apply=true`
   run creates a new plan that must itself be reviewed and approved at its DEV
   environment gate. Set environment approval variables to that new run's
   exact full commit SHA and plan SHA before the reviewer approves the job.
4. If an authorized Apply fails, preserve complete logs privately and inspect
   AWS resources and state before any retry. Never assume rollback. The current
   workflow's Apply output handling still requires a confidentiality and log
   retention review before enabling it on this public repository.

References: [EC2 Auto Scaling launch-template permissions](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-launch-template-permissions.html),
[RDS managed-secret permissions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html),
[ELB tagging during creation](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/tagging-resources-during-creation.html).
