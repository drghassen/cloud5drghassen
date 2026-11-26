terraform {
  backend "s3" {
    key          = "bootstrap/drghassen/dev-plan/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
