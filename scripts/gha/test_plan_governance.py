#!/usr/bin/env python3
"""Contract tests for the single .github/workflows/terraform.yml CI/CD pipeline."""

from __future__ import annotations

import unittest
from pathlib import Path


class WorkflowContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(__file__).resolve().parents[2]
        self.workflows = self.root / ".github" / "workflows"
        self.terraform_yml = self.workflows / "terraform.yml"

    def read_workflow(self) -> str:
        return self.terraform_yml.read_text(encoding="utf-8")

    def test_single_workflow_file_matches_spec_layout(self) -> None:
        files = sorted(p.name for p in self.workflows.glob("*.y*ml"))
        self.assertEqual(files, ["terraform.yml"])

    def test_security_controls_remain_explicit(self) -> None:
        text = self.read_workflow()
        self.assertNotIn("pull_request_target", text)
        self.assertNotIn("continue-on-error", text)
        self.assertNotIn("AWS_ACCESS_KEY", text)
        self.assertNotIn("secrets: inherit", text)
        self.assertNotIn("terraform destroy", text)
        self.assertIn("persist-credentials: false", text)

    def test_current_scans_are_preserved(self) -> None:
        text = self.read_workflow()
        self.assertIn("gitleaks dir --redact --no-banner .", text)
        self.assertIn("pre-commit run checkov --all-files", text)
        self.assertIn("tflint --recursive --minimum-failure-severity=error", text)
        self.assertIn("zizmorcore/zizmor-action@", text)

    def test_pdf_mandatory_steps_and_commands_present(self) -> None:
        text = self.read_workflow()
        self.assertIn("pull_request:", text)
        self.assertIn("workflow_dispatch:", text)
        self.assertIn("aws-actions/configure-aws-credentials@", text)
        self.assertIn("terraform fmt -check -recursive", text)
        self.assertIn("init -input=false", text)
        self.assertIn("validate", text)
        self.assertIn("-out=tfplan", text)
        self.assertIn("aws s3api put-object", text)
        handoff = (self.root / "scripts/gha/verify_plan_handoff.sh").read_text(encoding="utf-8")
        self.assertIn("aws s3api get-object", handoff)
        self.assertIn("--version-id", handoff)
        self.assertIn("sha256sum --check", handoff)
        self.assertIn("apply -input=false tfplan", text)

    def test_environments_and_oidc_gates(self) -> None:
        text = self.read_workflow()
        for env in ("dev", "test", "prod"):
            self.assertIn(f"environment: {env}-plan", text)
            self.assertIn(f"environment: {env}", text)
            self.assertIn(f"environments/{env}", text)
        self.assertIn("github.ref == 'refs/heads/main'", text)

    def test_generated_apply_policy_size_is_checked(self) -> None:
        self.assertIn("python3 scripts/gha/check_iam_apply.py", self.read_workflow())

    def test_public_repository_does_not_publish_or_apply_plan_artifacts(self) -> None:
        text = self.read_workflow()
        self.assertNotIn("actions/upload-artifact", text)
        self.assertNotIn("actions/download-artifact", text)
        self.assertNotIn("plan.txt", text)
        self.assertNotIn("TERRAFORM_S3_PLAN_HANDOFF_ENABLED", text)
        self.assertEqual(text.count("vars.TERRAFORM_APPROVED_PLAN_SHA256"), 3)
        self.assertEqual(text.count("vars.TERRAFORM_APPROVED_COMMIT_SHA"), 3)
        for env in ("dev", "test", "prod"):
            self.assertEqual(text.count(f"vars.TERRAFORM_{env.upper()}_S3_PLAN_HANDOFF_ENABLED == 'true'"), 3)
            self.assertIn(f"github.event_name == 'workflow_dispatch' && inputs.environment == '{env}' && inputs.apply", text)
            self.assertIn(f'-out=tfplan > "$RUNNER_TEMP/terraform-{env}-plan.log" 2>&1', text)
            self.assertIn(f'cloud5/ci-plans/v1/{env}/${{GITHUB_RUN_ID}}/${{GITHUB_RUN_ATTEMPT}}/tfplan', text)
            self.assertIn(f'cloud5/ci-plans/v1/{env}/${{GITHUB_RUN_ID}}/${{GITHUB_RUN_ATTEMPT}}/diagnostics/plan.log', text)
        self.assertEqual(text.count("bash scripts/gha/verify_plan_handoff.sh"), 3)
        for env in ("dev", "test", "prod"):
            job = text.split(f"  plan-{env}:", 1)[1].split(f"  apply-{env}:", 1)[0]
            condition = job.split("    if: >-", 1)[1].split("    runs-on:", 1)[0]
            self.assertNotIn("pull_request", condition)
            self.assertIn("github.ref == 'refs/heads/main'", condition)

    def test_ownership_gate_precedes_each_saved_plan_apply(self) -> None:
        text = self.read_workflow()
        for env in ("dev", "test", "prod"):
            gate = f"python3 scripts/gha/check_plan_ownership.py --environment {env} --plan environments/{env}/tfplan"
            apply = f"terraform -chdir=environments/{env} apply -input=false tfplan"
            self.assertIn(gate, text)
            self.assertLess(text.index(gate), text.index(apply))
            job = text.split(f"  apply-{env}:", 1)[1].split("\n  plan-", 1)[0]
            if env == "dev":
                self.assertNotIn("Require private Apply diagnostics (dev)", job)
                preflight = "bash scripts/gha/dev_diagnostics.sh preflight"
                self.assertIn(preflight, job)
                self.assertLess(job.index("Configure AWS credentials (OIDC)"), job.index(preflight))
                self.assertLess(job.index(preflight), job.index("bash scripts/gha/verify_plan_handoff.sh"))
                self.assertLess(job.index(preflight), job.index(gate))
                self.assertLess(job.index(gate), job.index(apply))
                self.assertIn("bash scripts/gha/dev_diagnostics.sh gate", job)
                self.assertIn("bash scripts/gha/dev_diagnostics.sh apply", job)
            else:
                self.assertLess(job.index("Require private Apply diagnostics"), job.index("Configure AWS credentials (OIDC)"))
                self.assertIn("Apply is blocked until confidential diagnostic retention is implemented.", job)


if __name__ == "__main__":
    unittest.main()
