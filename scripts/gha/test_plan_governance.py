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
        self.assertIn("show -no-color tfplan >", text)
        self.assertIn("plan.txt", text)
        self.assertIn("apply -input=false tfplan", text)

    def test_environments_and_oidc_gates(self) -> None:
        text = self.read_workflow()
        for env in ("dev", "test", "prod"):
            self.assertIn(f"environment: {env}-plan", text)
            self.assertIn(f"environment: {env}", text)
            self.assertIn(f"environments/{env}", text)
        self.assertIn("github.ref == 'refs/heads/main'", text)


if __name__ == "__main__":
    unittest.main()
