# Sorties du bootstrap – utilisées pour configurer les backends des environnements.

output "state_bucket_name" {
  description = "Nom du bucket S3 créé pour stocker les states Terraform. Passer ce nom à scripts/init-env.sh."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN du bucket S3 de state."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Région AWS du bucket S3."
  value       = aws_s3_bucket.state.region
}

output "required_iam_permissions" {
  description = <<-EOT
    Permissions IAM minimales requises par toute identité qui accède au backend.
    À utiliser pour configurer les rôles Terraform CI/CD et les postes opérateurs.
  EOT
  value = {
    s3_actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    s3_resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
    kms_actions = var.kms_key_arn != "" ? [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ] : []
    kms_resources = var.kms_key_arn != "" ? [var.kms_key_arn] : []
    note          = "Ces permissions sont documentées. Les attribuer explicitement aux rôles CI et aux postes opérateurs autorisés."
  }
}
