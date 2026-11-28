import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GIT_BASH = Path(r"C:\Program Files\Git\bin\bash.exe")
BASH = str(GIT_BASH) if GIT_BASH.exists() else shutil.which("bash")


@unittest.skipUnless(BASH, "bash is required")
class PlanHandoffTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cwd = Path(self.temp.name)
        (self.cwd / "environments/dev").mkdir(parents=True)
        stub = self.cwd / "aws"
        stub.write_text('''#!/usr/bin/env bash
set -eu
[[ "$#" == 11 && "$1" == s3api && "$2" == get-object && "$3" == --bucket && "$4" == cloud5-terraform-drghassen-state-326553917564 && "$5" == --key && "$6" == "cloud5/ci-plans/v1/$TARGET_ENV/123/1/tfplan" && "$7" == --version-id && "$8" == v1 && "$9" == --expected-bucket-owner && "${10}" == 326553917564 && "${11}" == "environments/$TARGET_ENV/tfplan" ]] || exit 2
printf called > called
printf fixture > "${11}"
''', encoding="utf-8")
        stub.chmod(0o755)
        digest = hashlib.sha256(b"fixture").hexdigest()
        self.env = {
            **os.environ, "PATH": str(self.cwd) + os.pathsep + os.environ["PATH"],
            "TARGET_ENV": "dev", "STATE_BUCKET": "cloud5-terraform-drghassen-state-326553917564",
            "PLAN_BUCKET": "cloud5-terraform-drghassen-state-326553917564",
            "PLAN_KEY": "cloud5/ci-plans/v1/dev/123/1/tfplan", "PLAN_VERSION": "v1",
            "PLAN_SHA": digest, "APPROVED_SHA": digest,
            "GITHUB_SHA": "a" * 40, "APPROVED_COMMIT": "a" * 40,
            "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1",
            "PLAN_COMMIT": "a" * 40, "PLAN_RUN_ID": "123",
            "PLAN_RUN_ATTEMPT": "1", "PLAN_ENVIRONMENT": "dev",
        }

    def run_check(self, values=None, remove=None):
        env = self.env.copy()
        env.update(values or {})
        if remove:
            for key in ([remove] if isinstance(remove, str) else remove):
                env.pop(key, None)
        return subprocess.run(
            [BASH, str(ROOT / "scripts/gha/verify_plan_handoff.sh")],
            cwd=self.cwd, env=env, capture_output=True, text=True,
        )

    def test_valid_handoff_downloads_and_checks_binary(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cwd / "called").exists())

    def test_dev_ignores_missing_or_stale_approvals(self):
        result = self.run_check(remove=("APPROVED_SHA", "APPROVED_COMMIT"))
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_check({"APPROVED_SHA": "obsolete", "APPROVED_COMMIT": "obsolete"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_mock_rejects_missing_version_id(self):
        result = subprocess.run([BASH, str(self.cwd / "aws"), "s3api", "get-object", "--bucket",
            self.env["PLAN_BUCKET"], "--key", self.env["PLAN_KEY"], "--expected-bucket-owner",
            "326553917564", "environments/dev/tfplan"], cwd=self.cwd, env=self.env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.cwd / "called").exists())

    def test_all_environment_prefixes_are_bound_to_their_own_run(self):
        for name in ("test", "prod"):
            (self.cwd / "environments" / name).mkdir()
            values = {"TARGET_ENV": name, "PLAN_KEY": f"cloud5/ci-plans/v1/{name}/123/1/tfplan"}
            with self.subTest(environment=name):
                result = self.run_check(values)
                self.assertEqual(result.returncode, 0, result.stderr)
                values["PLAN_KEY"] = "cloud5/ci-plans/v1/dev/123/1/tfplan"
                self.assertNotEqual(self.run_check(values).returncode, 0)

    def test_missing_wrong_or_mismatched_inputs_stop_before_download(self):
        wrong = {
            "TARGET_ENV": "stage", "STATE_BUCKET": "other", "PLAN_BUCKET": "other",
            "PLAN_KEY": "cloud5/ci-plans/v1/test/123/1/tfplan", "PLAN_VERSION": "None",
            "PLAN_SHA": "invalid", "PLAN_COMMIT": "b" * 40,
            "PLAN_RUN_ID": "124", "PLAN_RUN_ATTEMPT": "2", "PLAN_ENVIRONMENT": "test",
            "GITHUB_SHA": "b" * 40,
            "GITHUB_RUN_ID": "0", "GITHUB_RUN_ATTEMPT": "2",
        }
        for key, value in wrong.items():
            with self.subTest(key=key, value=value):
                self.assertNotEqual(self.run_check({key: value}).returncode, 0)
                self.assertFalse((self.cwd / "called").exists())
        for key in {"TARGET_ENV", "STATE_BUCKET", "PLAN_BUCKET", "PLAN_KEY", "PLAN_VERSION", "PLAN_SHA", "PLAN_COMMIT", "PLAN_RUN_ID", "PLAN_RUN_ATTEMPT", "PLAN_ENVIRONMENT", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"}:
            with self.subTest(missing=key):
                self.assertNotEqual(self.run_check(remove=key).returncode, 0)
                self.assertFalse((self.cwd / "called").exists())

    def test_bad_download_hash_blocks(self):
        digest = hashlib.sha256(b"different").hexdigest()
        self.assertNotEqual(self.run_check({"PLAN_SHA": digest, "APPROVED_SHA": digest}).returncode, 0)
        self.assertTrue((self.cwd / "called").exists())

    def test_failed_download_blocks(self):
        (self.cwd / "aws").write_text('#!/usr/bin/env bash\nexit 1\n', encoding="utf-8")
        self.assertNotEqual(self.run_check().returncode, 0)

    def test_summary_excludes_resource_values(self):
        result = subprocess.run(
            [shutil.which("python") or "python", str(ROOT / "scripts/gha/summarize_plan.py")],
            input='{"resource_changes":[{"address":"secret-address","change":{"actions":["delete","create"],"before":{"password":"secret-value"}}}]}',
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Replace (delete then create): 1", result.stdout)
        self.assertNotIn("secret", result.stdout)

    def test_test_prod_still_require_manual_approval(self):
        for name in ("test", "prod"):
            (self.cwd / "environments" / name).mkdir()
            values = {"TARGET_ENV": name, "PLAN_KEY": f"cloud5/ci-plans/v1/{name}/123/1/tfplan"}
            for remove, overrides in [("APPROVED_SHA", {}), ("APPROVED_COMMIT", {}),
                                      (None, {"APPROVED_SHA": "b" * 64}),
                                      (None, {"APPROVED_COMMIT": "b" * 40})]:
                with self.subTest(environment=name, remove=remove, overrides=overrides):
                    marker = self.cwd / "called"
                    marker.unlink(missing_ok=True)
                    self.assertNotEqual(self.run_check({**values, **overrides}, remove=remove).returncode, 0)
                    self.assertFalse(marker.exists())
            self.assertEqual(self.run_check(values).returncode, 0)

    def test_summary_actions_and_invalid_structures(self):
        labels = {("create",): "Create", ("update",): "Update", ("delete",): "Delete",
                  ("read",): "Read", ("no-op",): "No-op",
                  ("delete", "create"): "Replace (delete then create)",
                  ("create", "delete"): "Replace (create then delete)"}
        def summarize(value):
            return subprocess.run([shutil.which("python") or "python", str(ROOT / "scripts/gha/summarize_plan.py")],
                                  input=value, capture_output=True, text=True)
        result = summarize(json.dumps({"resource_changes": [{"change": {"actions": list(k)}} for k in labels]}))
        self.assertEqual(result.returncode, 0, result.stderr)
        for label in labels.values():
            self.assertIn(f"{label}: 1", result.stdout)
        for plan in ({}, {"resource_changes": [{"change": {"actions": ["no-op"]}}]}):
            self.assertIn("No resource-instance changes.", summarize(json.dumps(plan)).stdout)
        for value in ('secret not json', '[]', '{"resource_changes":null}',
                      '{"resource_changes":[{}]}', '{"resource_changes":[{"change":{"actions":["secret"]}}]}'):
            result = summarize(value)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("secret", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
