#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -e application || -e ansible ]]; then
  echo "Application and Ansible directories are outside this infrastructure-only repository scope." >&2
  exit 1
fi

echo "=== Terraform formatting ==="
terraform fmt -check -recursive

echo "=== Terraform root validation ==="
for d in bootstrap bootstrap/github-terraform-dev-plan bootstrap/github-terraform-dev-apply bootstrap/github-terraform-test-prod-plan bootstrap/github-terraform-test-prod-apply environments/dev environments/test environments/prod; do
  terraform -chdir="$d" init -backend=false -input=false
  terraform -chdir="$d" validate
done

echo "=== Terraform module tests ==="
terraform -chdir=bootstrap test
for m in modules/network modules/security modules/load-balancer modules/compute modules/database modules/storage modules/github-terraform-plan modules/github-terraform-apply modules/github-terraform-extensions; do
  terraform -chdir="$m" init -backend=false -input=false
  terraform -chdir="$m" test
done

echo "All local Terraform checks passed."
