# Backend S3 : état séparé par environnement, chiffré, verrouillage natif (Terraform >= 1.10).
# Le bucket et la région sont injectés via -backend-config.
terraform {
  backend "s3" {
    key          = "cloud5/infrastructure/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
