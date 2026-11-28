#!/usr/bin/env python3
"""Conservative ownership gate for the exact saved Terraform plan.

Only the known Auto Scaling policy child is accepted after its parent group is
verified in the same plan. No plan JSON or tag values are logged.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ALLOWED = {
    "module.monitoring.aws_cloudwatch_metric_alarm.this": "aws_cloudwatch_metric_alarm",
    "module.network.aws_vpc.this": "aws_vpc",
    "module.network.aws_default_security_group.this": "aws_default_security_group",
    "module.network.aws_subnet.public": "aws_subnet",
    "module.network.aws_subnet.private_app": "aws_subnet",
    "module.network.aws_subnet.private_db": "aws_subnet",
    "module.network.aws_internet_gateway.this": "aws_internet_gateway",
    "module.network.aws_route_table.public": "aws_route_table",
    "module.network.aws_route_table.private_app": "aws_route_table",
    "module.network.aws_route_table.private_db": "aws_route_table",
    "module.network.aws_eip.nat": "aws_eip",
    "module.network.aws_nat_gateway.this": "aws_nat_gateway",
    "module.security.aws_security_group.alb": "aws_security_group",
    "module.security.aws_security_group.web": "aws_security_group",
    "module.security.aws_vpc_security_group_ingress_rule.alb_http": "aws_vpc_security_group_ingress_rule",
    "module.security.aws_vpc_security_group_ingress_rule.alb_https": "aws_vpc_security_group_ingress_rule",
    "module.security.aws_vpc_security_group_ingress_rule.web_from_alb": "aws_vpc_security_group_ingress_rule",
    "module.security.aws_vpc_security_group_egress_rule.alb_to_web": "aws_vpc_security_group_egress_rule",
    "module.security.aws_vpc_security_group_egress_rule.web_https": "aws_vpc_security_group_egress_rule",
    "module.security.aws_iam_role.web_instance": "aws_iam_role",
    "module.security.aws_iam_instance_profile.web_instance": "aws_iam_instance_profile",
    "module.load_balancer.aws_lb.this": "aws_lb",
    "module.load_balancer.aws_lb_target_group.web": "aws_lb_target_group",
    "module.load_balancer.aws_lb_listener.http": "aws_lb_listener",
    "module.load_balancer.aws_lb_listener.https": "aws_lb_listener",
    "module.compute.aws_launch_template.web": "aws_launch_template",
    "module.compute.aws_autoscaling_group.web": "aws_autoscaling_group",
    "module.database.aws_db_subnet_group.this": "aws_db_subnet_group",
    "module.database.aws_security_group.database": "aws_security_group",
    "module.database.aws_vpc_security_group_ingress_rule.from_web": "aws_vpc_security_group_ingress_rule",
    "module.database.aws_db_instance.this": "aws_db_instance",
    "module.storage.aws_s3_bucket.this": "aws_s3_bucket",
    "aws_vpc_security_group_egress_rule.web_to_database": "aws_vpc_security_group_egress_rule",
}
INDEX = re.compile(r'\[(?:\d+|"[^"\[\]]+")\]$')


def unknown(value):
    if isinstance(value, dict):
        return any(unknown(v) for v in value.values())
    if isinstance(value, list):
        return any(unknown(v) for v in value)
    return value is True


def tags(value, resource_type):
    if not isinstance(value, dict):
        return None
    if resource_type == "aws_autoscaling_group":
        entries = value.get("tag")
        if not isinstance(entries, list) or any(not isinstance(e, dict) or not isinstance(e.get("key"), str) for e in entries):
            return None
        keys = [e["key"] for e in entries]
        if len(set(keys)) != len(keys):
            return None
        return {e["key"]: e.get("value") for e in entries}
    result = value.get("tags_all")
    return result if isinstance(result, dict) else None


def approved(approval, environment, commit, digest, address):
    if not isinstance(approval, dict) or set(approval) != {"environment", "commit", "sha256", "addresses"}:
        return False
    addresses = approval["addresses"]
    return (approval["environment"] == environment and approval["commit"] == commit
            and approval["sha256"] == digest and isinstance(addresses, list)
            and all(isinstance(a, str) for a in addresses) and address in addresses)


def validate_plan(plan, environment, commit, digest, approval=None):
    if environment not in {"dev", "test", "prod"} or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("invalid environment or commit")
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("invalid plan digest")
    if not isinstance(plan, dict) or not isinstance(plan.get("resource_changes"), list):
        raise ValueError("resource changes missing")
    required = {"Owner": "drghassen", "Project": "terraform-cloud-project", "Environment": environment, "ManagedBy": "Terraform"}
    for resource in plan["resource_changes"]:
        if resource.get("mode") == "data":
            continue
        if resource.get("mode") != "managed":
            raise ValueError("unrecognized resource mode")
        address = resource.get("address")
        if not isinstance(address, str):
            raise ValueError("resource address missing")
        change = resource.get("change")
        if not isinstance(change, dict):
            raise ValueError(f"{address}: change missing")
        if change.get("importing") is not None or resource.get("previous_address") is not None:
            raise ValueError(f"{address}: import and move require separate review")
        actions = change.get("actions")
        if actions == ["no-op"]:
            continue
        if actions not in (["create"], ["update"], ["delete"], ["delete", "create"], ["create", "delete"]):
            raise ValueError(f"{address}: unsupported actions")
        base = INDEX.sub("", address)
        resource_type = resource.get("type")
        if base == "module.compute.aws_autoscaling_policy.cpu_target" and resource_type == "aws_autoscaling_policy":
            if "delete" in actions and not approved(approval, environment, commit, digest, address):
                raise ValueError(f"{address}: deletion or replacement not specifically approved")
            parents = [r for r in plan["resource_changes"] if r.get("address") == "module.compute.aws_autoscaling_group.web" and r.get("type") == "aws_autoscaling_group"]
            if len(parents) != 1 or not isinstance(parents[0].get("change"), dict):
                raise ValueError(f"{address}: parent group is missing or ambiguous")
            for side in (["before"] if "delete" in actions or "create" not in actions else []) + (["after"] if "create" in actions or "update" in actions else []):
                child = change.get(side)
                parent = parents[0]["change"].get(side)
                if side == "after" and (unknown(change.get("after_unknown", {}).get("autoscaling_group_name")) or unknown(parents[0]["change"].get("after_unknown", {}).get("name"))):
                    raise ValueError(f"{address}: parent name is unknown")
                parent_tags = tags(parent, "aws_autoscaling_group")
                if not isinstance(child, dict) or not isinstance(parent, dict) or not child.get("autoscaling_group_name") or child["autoscaling_group_name"] != parent.get("name") or parent_tags is None or any(parent_tags.get(k) != v for k, v in required.items()):
                    raise ValueError(f"{address}: parent group or tags not verified")
            continue
        # Monitoring resources are restricted to the DEV environment
        # until TEST and PROD monitoring are explicitly integrated.
        if base == "module.monitoring.aws_cloudwatch_dashboard.operations":
            if environment != "dev" or resource_type != "aws_cloudwatch_dashboard":
                raise ValueError(f"{address}: invalid dashboard scope")
            if address != base:
                raise ValueError(f"{address}: unexpected dashboard address")
            if "delete" in actions and not approved(approval, environment, commit, digest, address):
                raise ValueError(f"{address}: dashboard deletion not approved")
            expected_name = "cloud5-infra-dev-operations"
            sides = []
            if "delete" in actions or "create" not in actions:
                sides.append("before")
            if "create" in actions or "update" in actions:
                sides.append("after")
            for side in sides:
                value = change.get(side)
                if not isinstance(value, dict) or value.get("dashboard_name") != expected_name:
                    raise ValueError(f"{address}: dashboard ownership not verified")
                if side == "after":
                    metadata = change.get("after_unknown")
                    if not isinstance(metadata, dict) or unknown(metadata.get("dashboard_name")):
                        raise ValueError(f"{address}: dashboard name is unknown")
            continue

        if base == "module.monitoring.aws_cloudwatch_metric_alarm.this":
            if environment != "dev" or resource_type != "aws_cloudwatch_metric_alarm":
                raise ValueError(f"{address}: invalid alarm scope")
            allowed_keys = {
                "healthy-hosts-low",
                "alb-5xx-high",
                "ec2-cpu-high",
                "rds-storage-low",
            }
            expected_names = {
                f'{base}["{key}"]': f"cloud5-infra-dev-{key}"
                for key in allowed_keys
            }
            expected_name = expected_names.get(address)
            if expected_name is None:
                raise ValueError(f"{address}: unexpected alarm address")
            sides = []
            if "delete" in actions or "create" not in actions:
                sides.append("before")
            if "create" in actions or "update" in actions:
                sides.append("after")
            for side in sides:
                value = change.get(side)
                if not isinstance(value, dict) or value.get("alarm_name") != expected_name:
                    raise ValueError(f"{address}: alarm name not verified")
                if side == "after":
                    metadata = change.get("after_unknown")
                    if not isinstance(metadata, dict) or unknown(metadata.get("alarm_name")):
                        raise ValueError(f"{address}: alarm name is unknown")

        if ALLOWED.get(base) != resource_type:
            raise ValueError(f"{address}: outside the verified taggable scope")
        if "delete" in actions and not approved(approval, environment, commit, digest, address):
            raise ValueError(f"{address}: deletion or replacement not specifically approved")
        if "create" not in actions or "delete" in actions:
            before = tags(change.get("before"), resource_type)
            if before is None or any(before.get(k) != v for k, v in required.items()):
                raise ValueError(f"{address}: prior ownership not verified")
        if "create" in actions or "update" in actions:
            after_unknown = change.get("after_unknown")
            if not isinstance(after_unknown, dict):
                raise ValueError(f"{address}: unknown metadata missing")
            field = "tag" if resource_type == "aws_autoscaling_group" else "tags_all"
            if unknown(after_unknown.get(field, False)) or unknown(after_unknown.get("tags", False)):
                raise ValueError(f"{address}: tags are unknown")
            after = tags(change.get("after"), resource_type)
            if after is None or any(after.get(k) != v for k, v in required.items()):
                raise ValueError(f"{address}: mandatory tags not verified")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True, choices=("dev", "test", "prod"))
    parser.add_argument("--plan", required=True)
    args = parser.parse_args()
    commit = os.environ.get("GITHUB_SHA", "")
    with open(args.plan, "rb") as binary:
        digest = hashlib.file_digest(binary, "sha256").hexdigest()
    checked_out = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if commit != checked_out:
        raise ValueError("checked out commit does not match workflow commit")
    raw = os.environ.get("TERRAFORM_DESTRUCTION_APPROVAL", "")
    approval = json.loads(raw) if raw else None
    plan_path = Path(args.plan).resolve(strict=True)
    environment_dir = Path(__file__).resolve().parents[2] / "environments" / args.environment
    shown = subprocess.run(["terraform", f"-chdir={environment_dir}", "show", "-json", str(plan_path)], capture_output=True, text=True, check=True)
    validate_plan(json.loads(shown.stdout), args.environment, commit, digest, approval)
    with open(args.plan, "rb") as binary:
        if hashlib.file_digest(binary, "sha256").hexdigest() != digest:
            raise ValueError("plan changed during validation")
    print(f"Ownership gate passed for {args.environment} commit {commit} plan {digest}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f"Ownership gate rejected plan: {exc}", file=sys.stderr)
        sys.exit(1)
