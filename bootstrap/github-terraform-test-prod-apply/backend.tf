terraform {
  backend "s3" {
    key          = "bootstrap/drghassen/test-prod-apply/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
