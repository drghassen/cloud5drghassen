terraform {
  backend "s3" {
    key          = "bootstrap/drghassen/dev-apply/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
