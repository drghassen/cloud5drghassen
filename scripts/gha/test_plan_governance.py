#!/usr/bin/env python3
"""Unit tests for deployment selection and plan artifact integrity."""

from __future__ import annotations

import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import assert_backend_target
import assert_deployment_context
import assert_main_unchanged
import deployment_policy
import plan_artifact

CALLER = (
    "drghassen/cloud5drghassen/.github/workflows/terraform.yml@refs/heads/main"
)
COMMIT = "a" * 40


class DeploymentPolicyTest(unittest.TestCase):
    def test_pull_request_never_selects_an_environment(self) -> None:
        decision = deployment_policy.decide(
            "pull_request",
            "refs/pull/12/merge",
            "promote",
            "prod",
        )
        self.assertEqual(
            decision,
            {"deploy_dev": False, "deploy_test": False, "deploy_prod": False},
        )

    def test_push_to_main_selects_promotion(self) -> None:
        decision = deployment_policy.decide("push", "refs/heads/main")
        self.assertTrue(all(decision.values()))

    def test_push_to_another_branch_does_not_deploy(self) -> None:
        decision = deployment_policy.decide("push", "refs/heads/feature")
        self.assertFalse(any(decision.values()))

    def test_manual_validate_does_not_deploy(self) -> None:
        decision = deployment_policy.decide(
            "workflow_dispatch",
            "refs/heads/main",
            "validate",
            "prod",
        )
        self.assertFalse(any(decision.values()))

    def test_manual_deploy_selects_only_the_requested_environment(self) -> None:
        for target in ("dev", "test", "prod"):
            decision = deployment_policy.decide(
                "workflow_dispatch",
                "refs/heads/main",
                "deploy",
                target,
            )
            self.assertTrue(decision[f"deploy_{target}"])
            self.assertEqual(sum(decision.values()), 1)

    def test_manual_promote_selects_every_environment(self) -> None:
        decision = deployment_policy.decide(
            "workflow_dispatch",
            "refs/heads/main",
            "promote",
            "dev",
        )
        self.assertTrue(all(decision.values()))

    def test_manual_deploy_off_main_fails(self) -> None:
        with self.assertRaises(deployment_policy.DeploymentPolicyError):
            deployment_policy.decide(
                "workflow_dispatch",
                "refs/heads/feature",
                "deploy",
                "dev",
            )

    def test_invalid_manual_operation_fails(self) -> None:
        with self.assertRaises(deployment_policy.DeploymentPolicyError):
            deployment_policy.decide(
                "workflow_dispatch",
                "refs/heads/main",
                "destroy",
                "dev",
            )

    def test_independent_test_does_not_require_dev(self) -> None:
        self.assertTrue(
            deployment_policy.stage_should_run(
                ci_success=True,
                selected=True,
                predecessor_selected=False,
                predecessor_result="skipped",
            )
        )

    def test_promotion_requires_the_previous_stage(self) -> None:
        self.assertFalse(
            deployment_policy.stage_should_run(
                ci_success=True,
                selected=True,
                predecessor_selected=True,
                predecessor_result="failure",
            )
        )
        self.assertTrue(
            deployment_policy.stage_should_run(
                ci_success=True,
                selected=True,
                predecessor_selected=True,
                predecessor_result="success",
            )
        )

    def test_failed_ci_blocks_every_stage(self) -> None:
        self.assertFalse(
            deployment_policy.stage_should_run(
                ci_success=False,
                selected=True,
                predecessor_selected=False,
                predecessor_result="skipped",
            )
        )


class DeploymentContextTest(unittest.TestCase):
    def test_trusted_main_context_passes(self) -> None:
        assert_deployment_context.assert_context(
            event_name="workflow_dispatch",
            git_ref="refs/heads/main",
            repository="drghassen/cloud5drghassen",
            caller_workflow_ref=CALLER,
            workflow_name="terraform-infrastructure",
            job_workflow_file=".github/workflows/terraform-plan.yml",
            expected_job_workflow_file=".github/workflows/terraform-plan.yml",
        )

    def test_pull_request_is_rejected(self) -> None:
        with self.assertRaises(assert_deployment_context.DeploymentContextError):
            assert_deployment_context.assert_context(
                event_name="pull_request",
                git_ref="refs/heads/main",
                repository="drghassen/cloud5drghassen",
                caller_workflow_ref=CALLER,
                workflow_name="terraform-infrastructure",
                job_workflow_file=".github/workflows/terraform-plan.yml",
                expected_job_workflow_file=".github/workflows/terraform-plan.yml",
            )

    def test_wrong_caller_is_rejected(self) -> None:
        with self.assertRaises(assert_deployment_context.DeploymentContextError):
            assert_deployment_context.assert_context(
                event_name="push",
                git_ref="refs/heads/main",
                repository="drghassen/cloud5drghassen",
                caller_workflow_ref=(
                    "drghassen/cloud5drghassen/.github/workflows/"
                    "terraform-plan.yml@refs/heads/main"
                ),
                workflow_name="terraform-infrastructure",
                job_workflow_file=".github/workflows/terraform-plan.yml",
                expected_job_workflow_file=".github/workflows/terraform-plan.yml",
            )


class BackendTargetTest(unittest.TestCase):
    def test_known_bucket_shape_passes(self) -> None:
        assert_backend_target.assert_backend_target(
            "dev",
            "eu-west-1",
            "cloud5-terraform-drghassen-state-326553917564",
        )

    def test_other_region_is_rejected(self) -> None:
        with self.assertRaises(assert_backend_target.BackendTargetError):
            assert_backend_target.assert_backend_target(
                "prod",
                "us-east-1",
                "cloud5-terraform-drghassen-state-326553917564",
            )

    def test_bucket_injection_is_rejected(self) -> None:
        with self.assertRaises(assert_backend_target.BackendTargetError):
            assert_backend_target.assert_backend_target(
                "dev",
                "eu-west-1",
                "bucket;rm -rf /",
            )


class StalePlanTest(unittest.TestCase):
    def test_matching_sha_passes(self) -> None:
        assert_main_unchanged.assert_same_commit(COMMIT, COMMIT)

    def test_moved_main_is_rejected(self) -> None:
        with self.assertRaises(assert_main_unchanged.StalePlanError):
            assert_main_unchanged.assert_same_commit(COMMIT, "b" * 40)

    def test_fetch_refuses_another_repository(self) -> None:
        with self.assertRaises(assert_main_unchanged.StalePlanError):
            assert_main_unchanged.fetch_main_sha("other/repo", "token")


class PlanArtifactTest(unittest.TestCase):
    def _environment(self, plan_dir: Path) -> dict[str, str]:
        return {
            "PLAN_DIR": str(plan_dir),
            "ENVIRONMENT": "test",
            "REPOSITORY": "drghassen/cloud5drghassen",
            "COMMIT": COMMIT,
            "RUN_ID": "1234",
            "RUN_ATTEMPT": "1",
            "WORKFLOW_NAME": "terraform-infrastructure",
            "EXPECTED_SHA256": "",
        }

    def test_round_trip_and_rejection_cases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            plan_dir = Path(temporary)
            binary = plan_dir / "test.tfplan"
            binary.write_bytes(b"binary-plan")
            (plan_dir / "test-plan.txt").write_text("No changes.\n", encoding="utf-8")
            env = self._environment(plan_dir)
            with mock.patch.dict(os.environ, env, clear=False):
                digest = plan_artifact.write_manifest(plan_dir)
                self.assertEqual(digest, hashlib.sha256(b"binary-plan").hexdigest())
                os.environ["EXPECTED_SHA256"] = digest
                manifest = plan_artifact.verify_manifest(plan_dir)
            self.assertEqual(manifest["environment"], "test")
            self.assertEqual(manifest["artifact_name"], "terraform-test-plan-1234")

            binary.write_bytes(b"tampered")
            with mock.patch.dict(os.environ, {**env, "EXPECTED_SHA256": digest}):
                with self.assertRaises(plan_artifact.PlanArtifactError):
                    plan_artifact.verify_manifest(plan_dir)

            binary.write_bytes(b"binary-plan")
            with mock.patch.dict(
                os.environ,
                {**env, "EXPECTED_SHA256": digest, "ENVIRONMENT": "prod"},
            ):
                with self.assertRaises(plan_artifact.PlanArtifactError):
                    plan_artifact.verify_manifest(plan_dir)

            with mock.patch.dict(
                os.environ,
                {**env, "EXPECTED_SHA256": digest, "COMMIT": "c" * 40},
            ):
                with self.assertRaises(plan_artifact.PlanArtifactError):
                    plan_artifact.verify_manifest(plan_dir)

            with mock.patch.dict(
                os.environ,
                {**env, "EXPECTED_SHA256": digest, "RUN_ID": "9999"},
            ):
                with self.assertRaises(plan_artifact.PlanArtifactError):
                    plan_artifact.verify_manifest(plan_dir)

            (plan_dir / "dev.tfplan").write_bytes(b"other-environment")
            with mock.patch.dict(os.environ, {**env, "EXPECTED_SHA256": digest}):
                with self.assertRaises(plan_artifact.PlanArtifactError):
                    plan_artifact.verify_manifest(plan_dir)


class WorkflowContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(__file__).resolve().parents[2]
        self.workflows = self.root / ".github" / "workflows"

    def read(self, name: str) -> str:
        return (self.workflows / name).read_text(encoding="utf-8")

    def test_security_controls_remain_explicit(self) -> None:
        for path in self.workflows.glob("*.yml"):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("pull_request_target", text, path.name)
            self.assertNotIn("continue-on-error", text, path.name)
            self.assertNotIn("AWS_ACCESS_KEY", text, path.name)
            self.assertNotIn("secrets: inherit", text, path.name)
            self.assertNotIn("terraform destroy", text, path.name)

    def test_reusable_workflows_are_not_entry_points(self) -> None:
        for name in (
            "terraform-ci.yml",
            "terraform-plan.yml",
            "terraform-deploy.yml",
            "terraform-environment-stage.yml",
        ):
            text = self.read(name)
            self.assertIn("workflow_call", text, name)
            self.assertNotIn("workflow_dispatch", text, name)
            self.assertNotIn("pull_request:", text, name)

    def test_orchestration_matches_the_three_modes(self) -> None:
        text = self.read("terraform.yml")
        self.assertIn("workflow_dispatch", text)
        self.assertIn("pull_request:", text)
        self.assertIn("./.github/workflows/terraform-ci.yml", text)
        self.assertIn("./.github/workflows/terraform-environment-stage.yml", text)
        self.assertNotIn("./.github/workflows/terraform-plan.yml", text)
        self.assertNotIn("./.github/workflows/terraform-deploy.yml", text)

    def test_stage_calls_plan_then_deploy_without_recursion(self) -> None:
        text = self.read("terraform-environment-stage.yml")
        self.assertIn("./.github/workflows/terraform-plan.yml", text)
        self.assertIn("./.github/workflows/terraform-deploy.yml", text)
        self.assertLess(
            text.index("terraform-plan.yml"),
            text.index("terraform-deploy.yml"),
        )
        self.assertIn("needs: plan", text)
        self.assertNotIn("terraform-environment-stage.yml", text)

    def test_deploy_applies_the_saved_plan_only(self) -> None:
        deploy = self.read("terraform-deploy.yml")
        plan = self.read("terraform-plan.yml")
        self.assertIn("apply -input=false", deploy)
        self.assertNotIn("terraform plan", deploy)
        self.assertNotIn(" plan -input=false", deploy)
        self.assertNotIn(" plan -out=", deploy)
        self.assertIn(" plan -input=false", plan)
        self.assertNotIn("apply -input=false", plan)
        self.assertIn("actions/download-artifact@", deploy)
        self.assertNotIn("run-id:", deploy)

    def test_oidc_permissions_are_not_granted_to_ci(self) -> None:
        ci = self.read("terraform-ci.yml")
        self.assertNotIn("id-token:", ci)
        orchestrator = self.read("terraform.yml")
        ci_block = orchestrator.split("uses: ./.github/workflows/terraform-ci.yml")[0]
        self.assertNotIn("id-token: write", ci_block)


if __name__ == "__main__":
    unittest.main()
