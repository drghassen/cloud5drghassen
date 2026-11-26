#!/usr/bin/env python3
"""Decide which Terraform environments a workflow run may deploy.

The workflow calls this module. Pull requests never deploy. A push to main
promotes dev, then test, then prod. A manual run must select validate, deploy,
or promote, and deploy selects exactly one environment.
"""

from __future__ import annotations

import os
import sys

ALLOWED_TARGETS = ("dev", "test", "prod")
MAIN_REF = "refs/heads/main"


class DeploymentPolicyError(Exception):
    """The manual dispatch inputs cannot be executed safely."""


def decide(
    event_name: str,
    git_ref: str,
    operation: str = "",
    target_environment: str = "",
) -> dict[str, bool]:
    """Return the environments selected for this run.

    A selected environment still waits for CI success and, during promotion,
    for the previous environment. This function does not grant AWS access.
    """

    decision = {f"deploy_{name}": False for name in ALLOWED_TARGETS}
    if event_name == "pull_request":
        return decision
    if event_name == "push":
        if git_ref == MAIN_REF:
            return {f"deploy_{name}": True for name in ALLOWED_TARGETS}
        return decision
    if event_name != "workflow_dispatch":
        return decision

    if operation == "validate":
        return decision
    if git_ref != MAIN_REF:
        raise DeploymentPolicyError(
            "Manual deploy and promote run only from refs/heads/main."
        )
    if operation == "promote":
        return {f"deploy_{name}": True for name in ALLOWED_TARGETS}
    if operation == "deploy":
        if target_environment not in ALLOWED_TARGETS:
            raise DeploymentPolicyError(
                "Manual deploy requires target environment dev, test, or prod."
            )
        decision[f"deploy_{target_environment}"] = True
        return decision
    raise DeploymentPolicyError(
        "Manual operation must be validate, deploy, or promote."
    )


def stage_should_run(
    *,
    ci_success: bool,
    selected: bool,
    predecessor_selected: bool,
    predecessor_result: str,
) -> bool:
    """Return whether an environment stage may start.

    Independent deployment does not require a predecessor that was not
    selected. Promotion requires the predecessor stage to succeed.
    """

    if not ci_success or not selected:
        return False
    if not predecessor_selected:
        return True
    return predecessor_result == "success"


def _value(name: str) -> str:
    return os.environ.get(name, "").strip()


def main() -> int:
    try:
        decision = decide(
            _value("EVENT_NAME"),
            _value("GIT_REF"),
            _value("OPERATION"),
            _value("TARGET_ENVIRONMENT"),
        )
    except DeploymentPolicyError as error:
        print(str(error), file=sys.stderr)
        return 1

    lines = [f"{key}={str(value).lower()}" for key, value in decision.items()]
    output_path = os.environ.get("GITHUB_OUTPUT")
    payload = "\n".join(lines) + "\n"
    if output_path:
        with open(output_path, "a", encoding="utf-8") as handle:
            handle.write(payload)
    else:
        sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
