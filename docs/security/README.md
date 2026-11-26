# Infrastructure security decisions

- **Network:** public subnets host only the internet-facing ALB. EC2 instances
  and RDS use private subnets; database subnets have no internet route.
- **Ingress:** DEV, TEST, and PROD currently serve HTTP through the public ALB
  using its AWS-provided DNS name; no custom domain or certificate is needed.
  HTTP traffic is unencrypted, so these demo endpoints must not carry
  credentials or sensitive data. HTTPS can be enabled with a valid ACM
  certificate when a domain is available. The web security group accepts HTTP
  only from the ALB security group. RDS accepts PostgreSQL only from the web
  security group. No inbound SSH rule is created.
- **WAF:** AWS WAF is not currently associated with the public ALB; deployment
  is deferred, so managed web-attack filtering is not provided. This remains
  an accepted security gap until WAF is deployed.
- **Administration:** EC2 instances use an IAM instance profile for Systems
  Manager rather than public IPs or SSH keys.
- **Database:** RDS is encrypted, private, and receives its master password
  from AWS Secrets Manager. The password value is never a Terraform output.
- **Object storage:** the demo bucket blocks public access,
  enforces TLS, enables versioning, and uses server-side encryption.
- **State:** environment state keys are isolated in S3, encrypted, and locked
  with Terraform's native S3 lock file. State can contain sensitive
  infrastructure metadata; access must be limited to approved operators and
  the read-only DEV plan role.
- **DNS:** the unused DNS bootstrap code was removed. Its current local state
  was empty, but an older backup contained four resource entries; live AWS
  status is unverified. Check Route 53 before assuming hosted zones were
  deleted or that their charges have stopped.
- **CI:** plans use GitHub OIDC and a read-only role. A manual DEV apply is
  opt-in and gated by the protected `dev` environment; it requires a separately
  reviewed apply role. No workflow runs `terraform destroy` or uses static AWS
  keys.

Review the generated Terraform plan and AWS IAM policy scope before provisioning.
These controls describe the code; they do not prove that AWS resources have
been deployed or that account-level settings are configured.

## CI security scans and accepted Checkov findings

The GitHub Actions workflow runs Gitleaks against repository files, Checkov
against Terraform, TFLint against Terraform configurations, and zizmor against
the workflow definitions. These jobs do not receive AWS credentials and are
required before the DEV plan job. Scan versions are pinned in the workflow or
the pre-commit configuration. Checkov is a blocking gate for findings that are
not explicitly and locally justified with a `#checkov:skip` annotation.

The initial Checkov run reported 33 failed resource checks and 157 passed
checks. The 33 were repeated policy findings, not 33 confirmed exploitable
vulnerabilities. The decisions below preserve the requested HTTP demo and
low-cost scope; revisit them before using this as a production service.

| Checkov rule(s) | Decision and reason | Revisit when |
|---|---|---|
| `CKV_AWS_2`, `CKV_AWS_103`, `CKV2_AWS_20`, `CKV_AWS_260` | Public HTTP is intentional for the demo. HTTPS, TLS policy, and redirect depend on a domain and ACM certificate; the backend ingress remains restricted to the ALB security group. | A domain and certificate are available; enable HTTPS and remove the exception. |
| `CKV_AWS_378` | TLS terminates at the ALB; HTTP to the EC2 targets remains within private subnets. | The application requirement includes encryption from ALB to targets. |
| `CKV2_AWS_28`, `CKV_AWS_91` | WAF and ALB access logging require additional AWS configuration and have ongoing cost/retention implications. | A production threat model and log-retention budget are approved. |
| `CKV_AWS_150`, `CKV_AWS_293` | Deletion protection is disabled for disposable environments to support approved teardown; long-lived PROD defaults enable protection. | Any environment becomes persistent or production-critical. |
| `CKV_AWS_129`, `CKV_AWS_118`, `CKV_AWS_353`, `CKV2_AWS_30` | RDS engine logs, enhanced monitoring, Performance Insights, and query logging need an approved observability/retention cost policy. | Database monitoring and retention requirements are defined. |
| `CKV_AWS_161` | IAM database authentication is not enabled until the application is configured and tested to use it. | Application-side IAM authentication is implemented and verified. |
| `CKV_AWS_157` | Non-production RDS remains Single-AZ to control cost; PROD is configured Multi-AZ. | Before changing production availability requirements or defaults. |
| `CKV_AWS_18`, `CKV_AWS_144` | S3 access logging and cross-region replication require destination resources, retention/replication policy, and additional cost. | A recovery and audit policy requires them. |
| `CKV_AWS_145` | Application and state buckets explicitly use SSE-S3 by default; customer-managed KMS encryption is deferred because it adds key/request cost. The state bucket can accept a KMS key ARN when approved. | KMS encryption and request costs are approved. |
| `CKV_AWS_19` | The state bucket's encryption is explicitly configured conditionally as SSE-S3 or SSE-KMS; this Checkov rule does not resolve that conditional. | Recheck after Checkov can resolve the expression or the encryption configuration changes. |
| `CKV2_AWS_62` | S3 event notifications have no consumer in the current infrastructure-only scope. | An event-driven consumer is introduced. |
| `CKV2_AWS_11` | VPC Flow Logs need a log destination and retention policy with ongoing ingestion/storage cost. | Network auditing requirements and retention budget are approved. |
| `CKV2_AWS_5` | Checkov cannot follow the ALB and EC2 security-group references across Terraform module outputs; the groups are attached by the environment roots. | Keep the module wiring covered by Terraform tests and confirm in the reviewed plan. |

`drop_invalid_header_fields` is enabled on the ALB. Public port 443 is opened
only when the HTTPS listener is enabled. Secrets scanning checks repository
files; it is not a substitute for rotating any credential that may have been
committed in historical Git objects.
