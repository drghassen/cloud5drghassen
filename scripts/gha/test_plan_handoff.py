import hashlib
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
        stub.write_text('#!/usr/bin/env bash\nprintf called > called\nprintf fixture > "${@: -1}"\n', encoding="utf-8")
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
        }

    def run_check(self, values=None, remove=None):
        env = self.env.copy()
        env.update(values or {})
        if remove:
            env.pop(remove, None)
        return subprocess.run(
            [BASH, str(ROOT / "scripts/gha/verify_plan_handoff.sh")],
            cwd=self.cwd, env=env, capture_output=True, text=True,
        )

    def test_valid_handoff_downloads_and_checks_binary(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cwd / "called").exists())

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
            "PLAN_SHA": "b" * 64, "APPROVED_SHA": "b" * 64,
            "GITHUB_SHA": "b" * 40, "APPROVED_COMMIT": "b" * 40,
            "GITHUB_RUN_ID": "0", "GITHUB_RUN_ATTEMPT": "2",
        }
        for key, value in wrong.items():
            with self.subTest(key=key, value=value):
                self.assertNotEqual(self.run_check({key: value}).returncode, 0)
                self.assertFalse((self.cwd / "called").exists())
        for key in self.env.keys() - {"PATH"} - os.environ.keys():
            with self.subTest(missing=key):
                self.assertNotEqual(self.run_check(remove=key).returncode, 0)
                self.assertFalse((self.cwd / "called").exists())

    def test_bad_download_hash_blocks(self):
        digest = hashlib.sha256(b"different").hexdigest()
        self.assertNotEqual(self.run_check({"PLAN_SHA": digest, "APPROVED_SHA": digest}).returncode, 0)
        self.assertTrue((self.cwd / "called").exists())


if __name__ == "__main__":
    unittest.main()
