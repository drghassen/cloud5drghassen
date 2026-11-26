#!/usr/bin/env python3
"""Reject an apply when main no longer points at the planned commit."""

from __future__ import annotations

import json
import os
import sys
import urllib.request

REPOSITORY = "drghassen/cloud5drghassen"


class StalePlanError(Exception):
    """The reviewed commit is no longer the head of main."""


def assert_same_commit(expected_sha: str, current_sha: str) -> None:
    if not expected_sha or expected_sha != current_sha:
        raise StalePlanError(
            "main advanced after this plan was created; refusing to apply "
            f"stale commit {expected_sha or '(empty)'}."
        )


def fetch_main_sha(repository: str, token: str) -> str:
    if repository != REPOSITORY:
        raise StalePlanError(f"Refusing to query commits for {repository}.")
    if not token:
        raise StalePlanError("GitHub token is required to verify main.")
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/commits/main",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "cloud5-terraform-deploy",
        },
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    sha = payload.get("sha")
    if not isinstance(sha, str) or len(sha) != 40:
        raise StalePlanError("GitHub did not return the current main SHA.")
    return sha


def main() -> int:
    try:
        current_sha = fetch_main_sha(
            os.environ.get("REPOSITORY", ""),
            os.environ.get("GH_TOKEN", ""),
        )
        assert_same_commit(os.environ.get("EXPECTED_SHA", ""), current_sha)
    except StalePlanError as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
