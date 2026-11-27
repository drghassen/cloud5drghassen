#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${RUNNER_TEMP:?}"
: "${GITHUB_RUN_ID:?}"
: "${GITHUB_RUN_ATTEMPT:?}"
: "${STATE_BUCKET:?}"
test "$STATE_BUCKET" = 'cloud5-terraform-drghassen-state-326553917564'
[[ "$GITHUB_RUN_ID" =~ ^[1-9][0-9]*$ ]]
[[ "$GITHUB_RUN_ATTEMPT" =~ ^[1-9][0-9]*$ ]]
private_dir="$RUNNER_TEMP/cloud5-dev-diagnostics-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
prefix="cloud5/ci-diagnostics/v1/dev/$GITHUB_RUN_ID/$GITHUB_RUN_ATTEMPT"
operation="${1:?operation required}"
shift

upload() {
  local kind="$1" version
  if ! version="$(aws s3api put-object --bucket "$STATE_BUCKET" --key "$prefix/$kind.log" \
      --body "$private_dir/$kind.log" --server-side-encryption AES256 --if-none-match '*' \
      --expected-bucket-owner 326553917564 --query VersionId --output text \
      2>"$private_dir/$kind-upload.err")"; then
    return 1
  fi
  [[ -n "$version" && "$version" != None && "$version" != null ]] || return 1
  printf 'Private diagnostic: %s; version: %s\n' "$prefix/$kind.log" "$version"
}

case "$operation" in
  preflight)
    test "$#" -eq 0
    mkdir -m 700 "$private_dir"
    printf 'diagnostics preflight\n' > "$private_dir/preflight.log"
    if ! upload preflight; then
      echo '::error::Private diagnostics preflight failed; Terraform Apply was not started.' >&2
      exit 1
    fi
    ;;
  gate|apply)
    test "$#" -gt 0
    test -d "$private_dir"
    command_status=0
    "$@" > "$private_dir/$operation.log" 2>&1 || command_status=$?
    upload_status=0
    upload "$operation" || upload_status=$?
    if (( upload_status != 0 )); then
      echo "::error::Private $operation diagnostic upload failed; do not retry Apply automatically." >&2
    fi
    if (( command_status != 0 )); then
      echo "::error::$operation failed with exit code $command_status." >&2
      exit "$command_status"
    fi
    if (( upload_status != 0 )); then exit 1; fi
    ;;
  *) exit 1 ;;
esac
