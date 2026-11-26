terraform {
  backend "s3" {
    key          = "bootstrap/drghassen/test-prod-plan/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
