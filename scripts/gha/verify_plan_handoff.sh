#!/usr/bin/env bash
set -euo pipefail

# Require all values and bind the download to the reviewed run and plan.
: "${TARGET_ENV:?}"
: "${STATE_BUCKET:?}"
: "${PLAN_BUCKET:?}"
: "${PLAN_KEY:?}"
: "${PLAN_VERSION:?}"
: "${PLAN_SHA:?}"
: "${APPROVED_SHA:?}"
: "${APPROVED_COMMIT:?}"
: "${GITHUB_SHA:?}"
: "${GITHUB_RUN_ID:?}"
: "${GITHUB_RUN_ATTEMPT:?}"
case "$TARGET_ENV" in dev|test|prod) ;; *) exit 1 ;; esac
test "$STATE_BUCKET" = "cloud5-terraform-drghassen-state-326553917564"
test "$PLAN_BUCKET" = "$STATE_BUCKET"
[[ "$GITHUB_RUN_ID" =~ ^[1-9][0-9]*$ ]]
[[ "$GITHUB_RUN_ATTEMPT" =~ ^[1-9][0-9]*$ ]]
test "$PLAN_KEY" = "cloud5/ci-plans/v1/$TARGET_ENV/$GITHUB_RUN_ID/$GITHUB_RUN_ATTEMPT/tfplan"
[[ "$PLAN_SHA" =~ ^[0-9a-f]{64}$ ]]
[[ "$APPROVED_SHA" =~ ^[0-9a-f]{64}$ ]]
[[ "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ ]]
[[ "$APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]]
test "$PLAN_SHA" = "$APPROVED_SHA"
test "$GITHUB_SHA" = "$APPROVED_COMMIT"
test "$PLAN_VERSION" != "None"
test "$PLAN_VERSION" != "null"

plan_file="environments/$TARGET_ENV/tfplan"
aws s3api get-object --bucket "$STATE_BUCKET" --key "$PLAN_KEY" \
  --version-id "$PLAN_VERSION" --expected-bucket-owner 326553917564 "$plan_file" > /dev/null
printf '%s  %s\n' "$PLAN_SHA" "$plan_file" | sha256sum --check --status
