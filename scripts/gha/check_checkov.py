#!/usr/bin/env python3
"""Run Checkov with the accepted exception for the DEV database only."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def dev_zero_backups_configured(root: Path) -> bool:
    variables = (root / "environments/dev/variables.tf").read_text(encoding="utf-8")
    example = (root / "environments/dev/terraform.tfvars.example").read_text(encoding="utf-8")
    variable = re.search(r'variable\s+"db_backup_retention_period"\s*\{([^{}]*)\}', variables, re.S)
    return bool(
        variable
        and re.search(r"^\s*default\s*=\s*0\s*$", variable.group(1), re.M)
        and re.search(r"^\s*db_backup_retention_period\s*=\s*0\s*$", example, re.M)
    )


def is_dev_exception(check: dict, zero_backups: bool) -> bool:
    def normal_path(key: str) -> str:
        return str(check.get(key) or "").replace("\\", "/").lstrip("/")

    return (
        zero_backups
        and check.get("check_id") == "CKV_AWS_133"
        and check.get("resource") == "module.database.aws_db_instance.this"
        and normal_path("file_path") == "modules/database/main.tf"
        and normal_path("caller_file_path") == "environments/dev/main.tf"
    )


def evaluate(report: object, exit_code: int, zero_backups: bool) -> tuple[int, list[dict], int]:
    if exit_code not in (0, 1):
        raise ValueError(f"Checkov exited with unexpected status {exit_code}")
    reports = report if isinstance(report, list) else [report]
    if not reports:
        raise ValueError("Checkov returned no reports")
    failures: list[dict] = []
    exceptions = 0
    for item in reports:
        if not isinstance(item, dict) or not isinstance(item.get("summary"), dict):
            raise ValueError("Invalid Checkov report")
        summary = item["summary"]
        checks = item.get("results", {}).get("failed_checks")
        if not isinstance(checks, list) or summary.get("failed") != len(checks):
            raise ValueError("Incomplete Checkov failure report")
        if summary.get("parsing_errors", 0):
            raise ValueError("Checkov reported parsing errors")
        for check in checks:
            if is_dev_exception(check, zero_backups):
                exceptions += 1
            else:
                failures.append(check)
    if exit_code == 1 and not failures and not exceptions:
        raise ValueError("Checkov failed without a reported finding")
    return len(failures), failures, exceptions


def main() -> int:
    try:
        result = subprocess.run(
            [sys.executable, "-m", "checkov.main", "-d", ".", "--quiet", "-o", "json"],
            cwd=ROOT, text=True, capture_output=True, check=False,
        )
        count, failures, exceptions = evaluate(
            json.loads(result.stdout), result.returncode, dev_zero_backups_configured(ROOT)
        )
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
        print(f"Checkov failed closed: {exc}", file=sys.stderr)
        return 1
    for check in failures:
        print(f"FAILED {check.get('check_id')} {check.get('resource')} {check.get('caller_file_path') or check.get('file_path')}")
    print(f"Checkov: {count} unaccepted finding(s), {exceptions} accepted DEV backup exception(s).")
    return 1 if count else 0


if __name__ == "__main__":
    sys.exit(main())
