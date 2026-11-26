#!/usr/bin/env python3
"""Create and verify the Terraform plan artifact for one environment."""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

SCHEMA = 1
ALLOWED_ENVIRONMENTS = {"dev", "test", "prod"}
REPOSITORY = "drghassen/cloud5drghassen"
SHA256_PATTERN = re.compile(r"^[a-f0-9]{64}$")
COMMIT_PATTERN = re.compile(r"^[a-f0-9]{40}$")
RUN_ID_PATTERN = re.compile(r"^[0-9]+$")


class PlanArtifactError(Exception):
    """The plan artifact failed an integrity check."""


def artifact_name(environment: str, run_id: str) -> str:
    if environment not in ALLOWED_ENVIRONMENTS:
        raise PlanArtifactError("Unsupported environment.")
    if not RUN_ID_PATTERN.fullmatch(run_id):
        raise PlanArtifactError("Invalid workflow run id.")
    return f"terraform-{environment}-plan-{run_id}"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(plan_dir: Path) -> str:
    environment = os.environ["ENVIRONMENT"]
    repository = os.environ["REPOSITORY"]
    commit = os.environ["COMMIT"]
    run_id = os.environ["RUN_ID"]
    run_attempt = os.environ["RUN_ATTEMPT"]
    workflow_name = os.environ["WORKFLOW_NAME"]

    if repository != REPOSITORY:
        raise PlanArtifactError(f"Refusing to record a plan for {repository}.")
    if not COMMIT_PATTERN.fullmatch(commit):
        raise PlanArtifactError("Invalid commit SHA.")
    if not RUN_ID_PATTERN.fullmatch(run_attempt):
        raise PlanArtifactError("Invalid workflow run attempt.")

    plan_file = f"{environment}.tfplan"
    readable_plan = f"{environment}-plan.txt"
    binary_path = plan_dir / plan_file
    readable_path = plan_dir / readable_plan
    if not binary_path.is_file() or binary_path.stat().st_size == 0:
        raise PlanArtifactError("Binary Terraform plan is missing.")
    if not readable_path.is_file() or readable_path.stat().st_size == 0:
        raise PlanArtifactError("Readable Terraform plan is missing.")

    digest = _sha256(binary_path)
    checksum_path = plan_dir / f"{environment}.tfplan.sha256"
    checksum_path.write_text(f"{digest}  {plan_file}\n", encoding="utf-8")
    manifest = {
        "schema": SCHEMA,
        "environment": environment,
        "repository": repository,
        "commit": commit,
        "run_id": run_id,
        "run_attempt": run_attempt,
        "workflow": workflow_name,
        "artifact_name": artifact_name(environment, run_id),
        "plan_file": plan_file,
        "readable_plan": readable_plan,
        "sha256": digest,
    }
    (plan_dir / "plan-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return digest


def verify_manifest(plan_dir: Path) -> dict[str, object]:
    environment = os.environ["ENVIRONMENT"]
    repository = os.environ["REPOSITORY"]
    commit = os.environ["COMMIT"]
    run_id = os.environ["RUN_ID"]
    expected_sha256 = os.environ["EXPECTED_SHA256"].strip().lower()

    if environment not in ALLOWED_ENVIRONMENTS:
        raise PlanArtifactError("Unsupported environment.")
    if repository != REPOSITORY:
        raise PlanArtifactError(f"Refusing to apply a plan for {repository}.")
    if not COMMIT_PATTERN.fullmatch(commit):
        raise PlanArtifactError("Invalid commit SHA.")
    if not SHA256_PATTERN.fullmatch(expected_sha256):
        raise PlanArtifactError("Plan digest from the plan job is invalid.")

    expected_name = artifact_name(environment, run_id)
    plan_file = f"{environment}.tfplan"
    binary_path = plan_dir / plan_file
    checksum_path = plan_dir / f"{environment}.tfplan.sha256"
    readable_path = plan_dir / f"{environment}-plan.txt"
    manifest_path = plan_dir / "plan-manifest.json"
    for path in (binary_path, checksum_path, readable_path, manifest_path):
        if not path.is_file():
            raise PlanArtifactError(f"Missing plan artifact file {path.name}.")

    plans = sorted(path.name for path in plan_dir.glob("*.tfplan"))
    if plans != [plan_file]:
        raise PlanArtifactError("Plan directory contains an unexpected plan file.")

    recorded_checksum = checksum_path.read_text(encoding="utf-8").strip()
    actual_digest = _sha256(binary_path)
    checksum_digest = recorded_checksum.split()[0].lower() if recorded_checksum else ""
    if checksum_digest != actual_digest:
        raise PlanArtifactError("SHA-256 checksum does not match the binary plan.")
    if actual_digest != expected_sha256:
        raise PlanArtifactError(
            "Binary plan does not match the digest published by the plan job."
        )

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise PlanArtifactError("Plan manifest is not valid JSON.") from error
    if not isinstance(manifest, dict):
        raise PlanArtifactError("Plan manifest has the wrong structure.")

    expected = {
        "schema": SCHEMA,
        "environment": environment,
        "repository": repository,
        "commit": commit,
        "run_id": run_id,
        "artifact_name": expected_name,
        "plan_file": plan_file,
        "readable_plan": f"{environment}-plan.txt",
        "sha256": expected_sha256,
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            raise PlanArtifactError(f"Plan manifest field {key} does not match this run.")
    if not RUN_ID_PATTERN.fullmatch(str(manifest.get("run_attempt", ""))):
        raise PlanArtifactError("Plan manifest run attempt is invalid.")
    if manifest.get("workflow") != "terraform-infrastructure":
        raise PlanArtifactError("Plan manifest workflow identity does not match.")
    return manifest


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    plan_dir = Path(os.environ.get("PLAN_DIR", ""))
    try:
        if command == "write":
            digest = write_manifest(plan_dir)
            sys.stdout.write(digest + "\n")
            return 0
        if command == "verify":
            verify_manifest(plan_dir)
            return 0
    except (PlanArtifactError, KeyError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1
    print("Usage: plan_artifact.py write|verify", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
