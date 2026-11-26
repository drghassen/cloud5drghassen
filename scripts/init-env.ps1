
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Bucket,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BackendRegion = "eu-west-1",

    [Parameter(Mandatory = $false)]
    [string]$KmsKeyId
)

$ErrorActionPreference = "Stop"

if ($BackendRegion -ne "eu-west-1") {
    throw "[init-env] Unsupported region '$BackendRegion'. Expected: eu-west-1."
}

if ($KmsKeyId -and $KmsKeyId.Trim().Length -eq 0) {
    throw "[init-env] KmsKeyId cannot be blank when supplied."
}

# Verify Terraform is installed
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw "[init-env] Terraform CLI is not installed or not in PATH."
}

# Resolve project paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EnvironmentDir = Join-Path $ProjectRoot "environments\$Environment"

if (-not (Test-Path $EnvironmentDir -PathType Container)) {
    throw "[init-env] Environment directory not found: $EnvironmentDir"
}

# Display configuration
Write-Host "========================================"
Write-Host " Cloud5 - Terraform Backend Init"
Write-Host "========================================"
Write-Host " Environment   : $Environment"
Write-Host " Directory     : $EnvironmentDir"
Write-Host " State bucket  : $Bucket"
Write-Host " Backend region: $BackendRegion"
Write-Host " State key     : cloud5/infrastructure/$Environment/terraform.tfstate"
Write-Host "========================================"

Push-Location $EnvironmentDir

try {
    $backendConfig = @(
        "-backend-config=bucket=$Bucket",
        "-backend-config=region=$BackendRegion"
    )
    if ($KmsKeyId) {
        $backendConfig += "-backend-config=kms_key_id=$KmsKeyId"
    }
    & terraform init -input=false @backendConfig

    if ($LASTEXITCODE -ne 0) {
        throw "[init-env] terraform init failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "[init-env] Initialization completed for $Environment." -ForegroundColor Green
}
finally {
    Pop-Location
}
