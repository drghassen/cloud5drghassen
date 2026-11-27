# Variables du bootstrap – bucket S3 de state Terraform.

variable "project_name" {
  description = "Nom du projet Cloud5. Utilisé dans les noms de ressources et les tags."
  type        = string
  default     = "cloud5"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.project_name))
    error_message = "project_name doit être en minuscules, contenir uniquement des lettres, chiffres et tirets, et ne pas dépasser 63 caractères."
  }
}

variable "state_bucket_name" {
  description = <<-EOT
    Nom complet du bucket S3 de state Terraform.
    Format conventionnel : <project_name>-terraform-state-<account_id>
    Exemple                : cloud5-terraform-state-123456789012

    Ce nom est global ; il doit être unique dans S3 worldwide.
    Si le bucket existe déjà, utiliser la procédure d'importation décrite
    dans bootstrap/README.md avant d'exécuter terraform apply.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name doit respecter les contraintes de nommage S3 (minuscules, chiffres, tirets, points ; 3–63 caractères)."
  }
}

variable "aws_region" {
  description = "Région AWS où le bucket S3 de state est créé."
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region doit être une région AWS valide (ex. eu-west-1)."
  }
}

variable "owner" {
  description = "Identifiant du propriétaire des ressources de backend."
  type        = string
  default     = "drghassen"

  validation {
    condition     = var.owner == "drghassen"
    error_message = "The resource owner must be drghassen."
  }
}

variable "kms_key_arn" {
  description = <<-EOT
    ARN optionnel d'une clé KMS customer-managed pour le chiffrement SSE-KMS du bucket.

    Si vide (""), le chiffrement SSE-S3 (AES256) est utilisé à la place.
    Pour une meilleure séparation des droits en production, fournir une clé
    KMS dédiée au state Terraform.

    NE JAMAIS coder cet ARN en dur dans les fichiers backend.tf des environnements :
    il doit toujours être injecté via scripts/init-env.sh (option --kms-key-id).
  EOT
  type        = string
  default     = ""

  validation {
    condition = (
      var.kms_key_arn == "" ||
      can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]{36}$", var.kms_key_arn)) ||
      can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:alias/.+$", var.kms_key_arn))
    )
    error_message = "kms_key_arn doit être vide ou un ARN KMS valide (clé ou alias)."
  }
}
