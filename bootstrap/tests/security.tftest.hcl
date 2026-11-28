mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" {
    defaults = { account_id = "326553917564" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564" }
  }
}

variables {
  state_bucket_name = "cloud5-terraform-drghassen-state-326553917564"
}

run "bucket_security" {
  command = plan

  assert {
    condition = (
      length(jsondecode(aws_s3_bucket_policy.state.policy).Statement) == 22 &&
      alltrue([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s.Effect == "Deny"]) &&
      length(distinct([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s.Sid])) == 22 &&
      contains([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s.Sid], "DenyInsecureTransport")
    )
    error_message = "The bucket policy must contain 22 distinct deny statements including TLS enforcement."
  }

  assert {
    condition = alltrue([for env in ["dev", "test", "prod"] :
      one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "DenyOtherPrincipals${title(env)}Diagnostics"]).Condition.StringNotEquals["aws:PrincipalArn"] == ["arn:aws:iam::326553917564:root", "arn:aws:iam::326553917564:user/drghassen", "arn:aws:iam::326553917564:role/cloud5-infra-${env}-github-terraform-apply"] &&
      one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "Deny${title(env)}DiagnosticsWithoutSseS3"]).Condition.StringNotEquals["s3:x-amz-server-side-encryption"] == "AES256" &&
      one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "Deny${title(env)}ApplyReadingOrDeletingDiagnostics"]).Resource == "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/ci-diagnostics/v1/${env}/*" &&
      toset(one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "Deny${title(env)}ApplyReadingOrDeletingDiagnostics"]).Action) == toset(["s3:GetObject", "s3:GetObjectVersion", "s3:DeleteObject", "s3:DeleteObjectVersion"]) &&
      one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "Deny${title(env)}ApplyReadingOrDeletingDiagnostics"]).Condition.StringEquals["aws:PrincipalArn"] == "arn:aws:iam::326553917564:role/cloud5-infra-${env}-github-terraform-apply" &&
      length(one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "Deny${title(env)}ApplyOtherEnvironmentDiagnostics"]).Resource) == 2 &&
      alltrue([for other in ["dev", "test", "prod"] : contains(one([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s if s.Sid == "Deny${title(env)}ApplyOtherEnvironmentDiagnostics"]).Resource, "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/ci-diagnostics/v1/${other}/*") == (other != env)]) &&
      contains([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s.Sid], "DenyOtherPrincipals${title(env)}Plans") &&
      contains([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s.Sid], "DenyPlanRoleReading${title(env)}Plans") &&
      contains([for s in jsondecode(aws_s3_bucket_policy.state.policy).Statement : s.Sid], "DenyApplyRoleWriting${title(env)}Plans")
    ])
    error_message = "Diagnostics and private-plan protections must remain scoped to each environment."
  }

  assert {
    condition = (
      aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled" &&
      aws_s3_bucket_public_access_block.state.block_public_acls && aws_s3_bucket_public_access_block.state.block_public_policy &&
      aws_s3_bucket_public_access_block.state.ignore_public_acls && aws_s3_bucket_public_access_block.state.restrict_public_buckets &&
      aws_s3_bucket.state.force_destroy == false &&
      length(aws_s3_bucket_lifecycle_configuration.state.rule) == 4 &&
      length([for rule in aws_s3_bucket_lifecycle_configuration.state.rule : rule if rule.id == "expire-dev-ci-diagnostics" && rule.filter[0].prefix == "cloud5/ci-diagnostics/v1/dev/" && rule.expiration[0].days == 7 && rule.noncurrent_version_expiration[0].noncurrent_days == 1]) == 1 &&
      length([for rule in aws_s3_bucket_lifecycle_configuration.state.rule : rule if rule.id == "expire-ci-plan-versions" && rule.filter[0].prefix == "cloud5/ci-plans/v1/" && rule.expiration[0].days == 7 && rule.noncurrent_version_expiration[0].noncurrent_days == 1]) == 1 &&
      length([for rule in aws_s3_bucket_lifecycle_configuration.state.rule : rule if rule.id == "expire-old-state-versions" && rule.filter[0].prefix == "" && rule.expiration[0].expired_object_delete_marker && rule.noncurrent_version_expiration[0].noncurrent_days == 90]) == 1 &&
      length([for rule in aws_s3_bucket_lifecycle_configuration.state.rule : rule if rule.id == "expire-test-ci-diagnostics" && rule.filter[0].prefix == "cloud5/ci-diagnostics/v1/test/" && rule.expiration[0].days == 7 && rule.noncurrent_version_expiration[0].noncurrent_days == 1]) == 1 &&
      length([for rule in aws_s3_bucket_lifecycle_configuration.state.rule : rule if rule.id == "expire-prod-ci-diagnostics"]) == 0
    )
    error_message = "Versioning, public access blocking and the four intended lifecycle rules must be preserved."
  }
}
