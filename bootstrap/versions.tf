terraform {
  required_version = ">= 1.10.0"

  # Le bootstrap utilise un state LOCAL intentionnellement.
  # Il crée le bucket S3 nécessaire aux backends des environnements ;
  # il ne peut donc pas utiliser lui-même ce bucket comme backend.
  # Ne pas ajouter de bloc backend "s3" ici.

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Owner     = var.owner
      ManagedBy = "Terraform"
      Component = "terraform-state-backend"
    }
  }
}
