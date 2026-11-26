#!/usr/bin/env bash
# =============================================================================
# init-env.sh – Initialize Terraform S3 backend for a Cloud5 environment.
#
# Usage:
#   bash scripts/init-env.sh <dev|test|prod> <state_bucket> [backend_region] [kms_key_id]
#
# Arguments:
#   <dev|test|prod>   Target environment (required).
#   <state_bucket>    S3 bucket name for Terraform remote state (required).
#   [backend_region]  AWS region of the S3 bucket (optional, default: eu-west-1).
#   [kms_key_id]      Optional KMS key ARN or alias for state SSE-KMS.
#
# Example:
#   bash scripts/init-env.sh dev  cloud5-terraform-state-326553917564 eu-west-1
#   bash scripts/init-env.sh test cloud5-terraform-state-326553917564 eu-west-1
#   bash scripts/init-env.sh prod cloud5-terraform-state-326553917564 eu-west-1
#
# Authentication:
#   AWS identity is resolved from the environment (AWS_PROFILE, AWS SSO, OIDC,
#   or instance role). Never pass access keys via -backend-config or arguments.
#
# Safety:
#   This script only runs `terraform init`. It never runs apply, destroy,
#   force-unlock, -migrate-state, or -reconfigure automatically.
# =============================================================================

set -euo pipefail

ENV="${1:?[init-env] Environment required (dev, test or prod).}"
BUCKET="${2:?[init-env] S3 state bucket name required.}"
BACKEND_REGION="${3:-eu-west-1}"
KMS_KEY_ID="${4:-}"

# ---------------------------------------------------------------------------
# Validate environment name
# ---------------------------------------------------------------------------
case "$ENV" in
  dev|test|prod)
    ;;
  *)
    echo "[init-env] ERROR: Invalid environment '$ENV'. Expected: dev, test or prod." >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Validate bucket (must not be empty after trimming)
# ---------------------------------------------------------------------------
if [[ -z "${BUCKET// /}" ]]; then
  echo "[init-env] ERROR: State bucket name must not be empty." >&2
  exit 2
fi

if [[ -n "$KMS_KEY_ID" && -z "${KMS_KEY_ID// /}" ]]; then
  echo "[init-env] ERROR: KMS key ID cannot be blank when supplied." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Resolve project root from script location, independent of CWD
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/environments/$ENV"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "[init-env] ERROR: Environment directory not found: $ENV_DIR" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Confirm configuration before initializing
# ---------------------------------------------------------------------------
echo "========================================"
echo " Cloud5 – Terraform Backend Init"
echo "========================================"
echo " Environment   : $ENV"
echo " Directory     : $ENV_DIR"
echo " State bucket  : $BUCKET"
echo " Backend region: $BACKEND_REGION"
echo " State key     : cloud5/infrastructure/$ENV/terraform.tfstate"
echo "========================================"
echo ""

cd "$ENV_DIR"

# ---------------------------------------------------------------------------
# Initialize backend – bucket and region injected; no credentials passed.
# Use -reconfigure only manually when intentionally switching backends.
# ---------------------------------------------------------------------------
backend_args=(
  -input=false
  "-backend-config=bucket=$BUCKET"
  "-backend-config=region=$BACKEND_REGION"
)
if [[ -n "$KMS_KEY_ID" ]]; then
  backend_args+=("-backend-config=kms_key_id=$KMS_KEY_ID")
fi
terraform init "${backend_args[@]}"

echo ""
echo "[init-env] Terraform initialization completed for environment: $ENV"
