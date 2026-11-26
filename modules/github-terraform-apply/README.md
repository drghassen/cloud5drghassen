# GitHub Terraform apply role module

Defines a GitHub OIDC role for applying the project's DEV Terraform
infrastructure. The role trusts only the configured repository's `dev`
environment on `main`; its state permissions are limited to one object and
lock file. Resource permissions are limited to the DEV project, including
`iam:PassRole` for only the web instance role and only to EC2.

Instantiate this module from `bootstrap/github-terraform-dev-apply`. It is
currently configured for DEV only; do not attach the same unscoped policy to
TEST or PROD roles. Review the module policy and bootstrap plan before
provisioning.
