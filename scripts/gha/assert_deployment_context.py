#!/usr/bin/env python3
"""Reject deployment jobs that are not the trusted main-branch orchestration."""

from __future__ import annotations

import os
import sys

REPOSITORY = "drghassen/cloud5drghassen"
MAIN_REF = "refs/heads/main"
CALLER_WORKFLOW_REF = (
    "drghassen/cloud5drghassen/.github/workflows/terraform.yml@refs/heads/main"
)
WORKFLOW_NAME = "terraform-infrastructure"
ALLOWED_EVENTS = {"push", "workflow_dispatch"}


class DeploymentContextError(Exception):
    """The job is not allowed to obtain AWS credentials."""


def assert_context(
    *,
    event_name: str,
    git_ref: str,
    repository: str,
    caller_workflow_ref: str,
    workflow_name: str,
    job_workflow_file: str,
    expected_job_workflow_file: str,
) -> None:
    if event_name in {"pull_request", "pull_request_target"}:
        raise DeploymentContextError(
            "Refusing AWS credentials for a pull request event."
        )
    if event_name not in ALLOWED_EVENTS:
        raise DeploymentContextError(f"Refusing unsupported event {event_name}.")
    if git_ref != MAIN_REF:
        raise DeploymentContextError(
            f"Refusing ref {git_ref}; AWS jobs run only from {MAIN_REF}."
        )
    if repository != REPOSITORY:
        raise DeploymentContextError(f"Refusing repository {repository}.")
    if caller_workflow_ref != CALLER_WORKFLOW_REF:
        raise DeploymentContextError(
            "Refusing caller "
            f"{caller_workflow_ref}. AWS jobs run only from "
            f"{CALLER_WORKFLOW_REF}."
        )
    if workflow_name != WORKFLOW_NAME:
        raise DeploymentContextError(
            f"Refusing workflow name {workflow_name or '(empty)'}."
        )
    if not job_workflow_file:
        raise DeploymentContextError(
            "job.workflow_file_path is empty. Refusing to deploy without a "
            "verified workflow identity."
        )
    actual_file = job_workflow_file.replace("\\", "/").lstrip("/")
    expected_file = expected_job_workflow_file.replace("\\", "/").lstrip("/")
    if actual_file != expected_file:
        raise DeploymentContextError(
            f"Refusing job workflow {job_workflow_file}; expected "
            f"{expected_job_workflow_file}."
        )


def main() -> int:
    try:
        assert_context(
            event_name=os.environ.get("EVENT_NAME", ""),
            git_ref=os.environ.get("GIT_REF", ""),
            repository=os.environ.get("REPOSITORY", ""),
            caller_workflow_ref=os.environ.get("CALLER_WORKFLOW_REF", ""),
            workflow_name=os.environ.get("WORKFLOW_NAME", ""),
            job_workflow_file=os.environ.get("JOB_WORKFLOW_FILE", ""),
            expected_job_workflow_file=os.environ.get(
                "EXPECTED_JOB_WORKFLOW_FILE", ""
            ),
        )
    except DeploymentContextError as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
