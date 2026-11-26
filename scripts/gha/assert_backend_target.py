#!/usr/bin/env python3
"""Validate the environment, region, and state bucket before Terraform init."""

from __future__ import annotations

import os
import re
import sys

ALLOWED_ENVIRONMENTS = {"dev", "test", "prod"}
AWS_REGION = "eu-west-1"
BUCKET_PATTERN = re.compile(r"^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$")


class BackendTargetError(Exception):
    """The remote backend target is not acceptable."""


def assert_backend_target(environment: str, aws_region: str, state_bucket: str) -> None:
    if environment not in ALLOWED_ENVIRONMENTS:
        raise BackendTargetError(
            "Environment must be dev, test, or prod before Terraform runs."
        )
    if aws_region != AWS_REGION:
        raise BackendTargetError(f"AWS region must be {AWS_REGION}.")
    if not BUCKET_PATTERN.fullmatch(state_bucket):
        raise BackendTargetError(
            "TERRAFORM_STATE_BUCKET is missing or is not a valid S3 bucket name."
        )


def main() -> int:
    try:
        assert_backend_target(
            os.environ.get("ENVIRONMENT", ""),
            os.environ.get("AWS_REGION", ""),
            os.environ.get("STATE_BUCKET", ""),
        )
    except BackendTargetError as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
