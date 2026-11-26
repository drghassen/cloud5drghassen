$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if ((Test-Path (Join-Path $RepoRoot "application")) -or (Test-Path (Join-Path $RepoRoot "ansible"))) {
    throw "Application and Ansible directories are outside this infrastructure-only repository scope."
}

Write-Host "=== Terraform formatting ===" -ForegroundColor Cyan
& terraform fmt -check -recursive
if ($LASTEXITCODE -ne 0) { throw "terraform fmt check failed" }

Write-Host "=== Terraform root validation ===" -ForegroundColor Cyan
$rootDirs = @(
    "bootstrap",
    "bootstrap\github-terraform-dev-plan",
    "bootstrap\github-terraform-dev-apply",
    "bootstrap\github-terraform-test-prod-plan",
    "bootstrap\github-terraform-test-prod-apply",
    "environments\dev",
    "environments\test",
    "environments\prod"
)

foreach ($rootDir in $rootDirs) {
    Write-Host "Validating $rootDir ..."
    & terraform "-chdir=$rootDir" init -backend=false -input=false
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed for $rootDir" }
    & terraform "-chdir=$rootDir" validate
    if ($LASTEXITCODE -ne 0) { throw "terraform validate failed for $rootDir" }
}

Write-Host "=== Terraform module tests ===" -ForegroundColor Cyan
$moduleDirs = @(
    "modules\network",
    "modules\security",
    "modules\load-balancer",
    "modules\compute",
    "modules\database",
    "modules\storage",
    "modules\github-terraform-plan",
    "modules\github-terraform-apply"
)

foreach ($moduleDir in $moduleDirs) {
    Write-Host "Testing $moduleDir ..."
    & terraform "-chdir=$moduleDir" init -backend=false -input=false
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed for $moduleDir" }
    & terraform "-chdir=$moduleDir" test
    if ($LASTEXITCODE -ne 0) { throw "terraform tests failed for $moduleDir" }
}

Write-Host "All local Terraform checks passed." -ForegroundColor Green
