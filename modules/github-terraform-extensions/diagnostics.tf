resource "aws_iam_policy" "diagnostics" {
  count = var.enable_diagnostics ? 1 : 0

  name        = "${var.name_prefix}-github-terraform-apply-diagnostics"
  description = "Encrypted S3 diagnostics writes for Cloud5 ${upper(var.environment)} Terraform apply."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteEncryptedEnvironmentDiagnostics"
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::${var.state_bucket_name}/cloud5/ci-diagnostics/v1/${var.environment}/*"
      Condition = {
        StringEquals = { "s3:x-amz-server-side-encryption" = "AES256" }
      }
    }]
  })
  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "diagnostics" {
  count      = var.enable_diagnostics ? 1 : 0
  role       = var.role_name
  policy_arn = aws_iam_policy.diagnostics[0].arn
}
