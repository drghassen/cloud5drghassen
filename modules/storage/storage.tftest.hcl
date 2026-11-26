mock_provider "aws" {}

override_data {
  target = data.aws_caller_identity.current

  values = {
    account_id = "111122223333"
  }
}

run "bucket_is_private_versioned_encrypted_and_lifecycle_managed" {
  command = plan

  variables {
    name_prefix = "cloud5-dev"
    common_tags = {
      Project     = "cloud5"
      Environment = "dev"
      Owner       = "test"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == "cloud5-dev-storage-111122223333"
    error_message = "The bucket name must be unique to the environment and AWS account."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.block_public_policy && aws_s3_bucket_public_access_block.this.ignore_public_acls && aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "The storage bucket must block all public access."
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled" && one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "The storage bucket must enable versioning and server-side encryption."
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.this.rule).noncurrent_version_expiration[0].noncurrent_days == 90
    error_message = "Old object versions must have a bounded retention period."
  }
}
