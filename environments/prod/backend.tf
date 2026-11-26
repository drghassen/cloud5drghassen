# Backend S3 : état séparé par environnement, chiffré, verrouillage natif (Terraform >= 1.10).
# Le nom du bucket et la région sont injectés via -backend-config (voir scripts/init-env.sh).
terraform {
  backend "s3" {
    key          = "cloud5/infrastructure/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
