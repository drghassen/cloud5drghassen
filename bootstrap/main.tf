# Bootstrap : bucket S3 d'état (versioning, SSE-KMS, blocage public, politique TLS-only).
# État local, exécuté une seule fois par un opérateur autorisé.
#
# Ce module crée l'infrastructure backend Terraform avant que les environnements
# DEV/TEST/PROD puissent stocker leur propre state à distance.
#
# USAGE :
#   terraform -chdir=bootstrap init
#   terraform -chdir=bootstrap apply
#
# Si le bucket existe déjà, utiliser la procédure d'importation documentée
# dans bootstrap/README.md avant d'exécuter apply.
#
# INTERDIT pendant cette session d'audit :
#   Ne PAS exécuter terraform apply ici contre AWS.
#   Ne PAS importer de ressource AWS existante automatiquement.

data "aws_caller_identity" "current" {}

locals {
  # Le nom du bucket inclut l'ID de compte pour l'unicité globale S3.
  # Après provisionnement, passer le nom à scripts/init-env.sh comme argument.
  bucket_name = var.state_bucket_name

  common_tags = {
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Component   = "terraform-state-backend"
    Environment = "shared"
  }
}

# ---------------------------------------------------------------------------
# S3 Bucket – state Terraform
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Access logging needs a separate log bucket and retention policy, deferred from this bootstrap.
  #checkov:skip=CKV_AWS_19:Encryption is explicitly configured below as SSE-S3 by default or SSE-KMS when a key ARN is supplied; Checkov cannot resolve the conditional.
  #checkov:skip=CKV_AWS_144:Cross-region replication requires a second state bucket and region, deferred from this single-region backend.
  #checkov:skip=CKV_AWS_145:SSE-S3 is the cost-conscious default; a KMS key can be supplied when its request costs are approved.
  #checkov:skip=CKV2_AWS_62:No event consumer is in scope for the Terraform state bucket.
  bucket = local.bucket_name

  # Ne JAMAIS activer force_destroy sur un bucket de state : les versions
  # historiques des états sont précieuses et doivent être conservées.
  force_destroy = false

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })

  lifecycle {
    # Le bucket ne doit jamais être recréé par Terraform.
    # Si le bucket existe déjà, utiliser terraform import.
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Versioning – obligatoire pour use_lockfile et l'historique d'état
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# Chiffrement par défaut – SSE-KMS
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      # Utiliser la clé KMS fournie en variable, ou la clé AWS gérée s3
      # si aucune clé customer-managed n'est configurée.
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    # Exiger le chiffrement explicite à l'écriture (pas d'objet non chiffré).
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
  }
}

# ---------------------------------------------------------------------------
# Blocage total des accès publics
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Contrôle de propriété des objets
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------------------------------------------------------------------
# Politique de bucket – TLS uniquement et deny sans chiffrement
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        # Refus de toute requête en transit non chiffré (HTTP).
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      ], [for environment in ["dev", "test", "prod"] : {
        Sid       = "DenyOtherPrincipals${title(environment)}Plans"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${aws_s3_bucket.state.arn}/cloud5/ci-plans/v1/${environment}/*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.owner}",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-${environment}-github-terraform-plan",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-${environment}-github-terraform-apply"
            ]
          }
        }
        }], [for environment in ["dev", "test", "prod"] : {
        Sid       = "DenyPlanRoleReading${title(environment)}Plans"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource  = "${aws_s3_bucket.state.arn}/cloud5/ci-plans/v1/${environment}/*"
        Condition = { StringEquals = { "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-${environment}-github-terraform-plan" } }
        }], [for environment in ["dev", "test", "prod"] : {
        Sid       = "DenyApplyRoleWriting${title(environment)}Plans"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
        Resource  = "${aws_s3_bucket.state.arn}/cloud5/ci-plans/v1/${environment}/*"
        Condition = { StringEquals = { "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-${environment}-github-terraform-apply" } }
      }], [
      {
        Sid       = "DenyOtherPrincipalsDevDiagnostics"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${aws_s3_bucket.state.arn}/cloud5/ci-diagnostics/v1/dev/*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.owner}",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-dev-github-terraform-apply"
            ]
          }
        }
      },
      {
        Sid       = "DenyDevApplyReadingOrDeletingDiagnostics"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectVersion", "s3:DeleteObject", "s3:DeleteObjectVersion"]
        Resource  = "${aws_s3_bucket.state.arn}/cloud5/ci-diagnostics/v1/dev/*"
        Condition = { StringEquals = { "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-dev-github-terraform-apply" } }
      },
      {
        Sid       = "DenyDevDiagnosticsWithoutSseS3"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/cloud5/ci-diagnostics/v1/dev/*"
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "AES256" } }
      },
      {
        Sid       = "DenyDevApplyOtherEnvironmentDiagnostics"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.state.arn}/cloud5/ci-diagnostics/v1/test/*",
          "${aws_s3_bucket.state.arn}/cloud5/ci-diagnostics/v1/prod/*"
        ]
        Condition = { StringEquals = { "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloud5-infra-dev-github-terraform-apply" } }
      }
    ])
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------------------------------------------------------------------
# Lifecycle – expiration des anciennes versions de state et de lockfiles
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # Attendre que le versioning soit activé avant de configurer le lifecycle.
  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    # Toutes les clés de state et de lockfiles.
    filter {
      prefix = ""
    }

    # Marquer les anciens objets supprimés (delete markers) pour suppression.
    expiration {
      expired_object_delete_marker = true
    }

    # Supprimer les versions non courantes après 90 jours.
    # Les versions récentes (< 90 jours) sont toujours conservées pour rollback.
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Supprimer les multiparts incomplets après 7 jours.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Separate prefix only: the existing state-retention rule remains unchanged.
  rule {
    id     = "expire-ci-plan-versions"
    status = "Enabled"
    filter {
      prefix = "cloud5/ci-plans/v1/"
    }
    expiration {
      days = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "expire-dev-ci-diagnostics"
    status = "Enabled"
    filter {
      prefix = "cloud5/ci-diagnostics/v1/dev/"
    }
    expiration {
      days = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}
