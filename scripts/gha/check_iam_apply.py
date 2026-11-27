#!/usr/bin/env python3
"""Inspect mock Terraform plans and optionally simulate the generated DEV policy.

Runs only mock-provider plan tests. Never reads or writes Terraform state or AWS
resources. The IAM API calls validate/simulate a supplied policy, not a live role.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path


def policies_from_tests():
    root = Path(__file__).resolve().parents[2]
    result = subprocess.run(
        ["terraform", "-chdir=modules/github-terraform-apply", "test", "-json", "-verbose"],
        cwd=root, capture_output=True, text=True, encoding="utf-8", check=True,
    )
    found = []
    for line in result.stdout.splitlines():
        event = json.loads(line)
        if event.get("type") != "test_plan":
            continue
        resources = {change["address"]: change for change in event["test_plan"]["resource_changes"]}
        try:
            found.append((resources["aws_iam_role_policy.this"]["change"]["after"]["policy"],
                          resources["aws_iam_policy.create_tags"]["change"]["after"]["policy"]))
        except KeyError as exc:
            raise ValueError("Generated IAM policy missing from test plan") from exc
    if len(found) != 3:
        raise ValueError(f"Expected three generated policies, got {len(found)}")
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--aws", action="store_true", help="validate and simulate against AWS IAM APIs")
    args = parser.parse_args()
    policies = policies_from_tests()
    for environment, (inline, managed) in zip(("dev", "test", "prod"), policies):
        print(f"{environment}: {len(inline)}/10240 inline, {len(managed)}/6144 managed policy characters")
        if len(inline) > 10240 or len(managed) > 6144:
            raise ValueError(f"{environment} policy exceeds the IAM policy quota")
    if not args.aws:
        return

    import boto3
    session = boto3.Session(region_name="eu-west-1")
    iam = session.client("iam")
    analyzer = session.client("accessanalyzer")
    role = "arn:aws:iam::326553917564:role/cloud5-infra-dev-web-instance-role"
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    state = "arn:aws:s3:::cloud5-terraform-drghassen-state-326553917564/cloud5/infrastructure/"
    cases = [
        ("attach SSM", "iam:AttachRolePolicy", role, "iam:PolicyARN", ssm, "allowed"),
        ("attach administrator", "iam:AttachRolePolicy", role, "iam:PolicyARN", "arn:aws:iam::aws:policy/AdministratorAccess", "implicitDeny"),
        ("attach SSM to other role", "iam:AttachRolePolicy", role + "-other", "iam:PolicyARN", ssm, "implicitDeny"),
        ("pass project role to EC2", "iam:PassRole", role, "iam:PassedToService", "ec2.amazonaws.com", "allowed"),
        ("pass other role", "iam:PassRole", role + "-other", "iam:PassedToService", "ec2.amazonaws.com", "implicitDeny"),
        ("pass project role to Lambda", "iam:PassRole", role, "iam:PassedToService", "lambda.amazonaws.com", "implicitDeny"),
        ("read DEV state", "s3:GetObject", state + "dev/terraform.tfstate", None, None, "allowed"),
        ("read TEST state", "s3:GetObject", state + "test/terraform.tfstate", None, None, "implicitDeny"),
    ]
    for policy in policies[0]:
        findings = analyzer.validate_policy(policyDocument=policy, policyType="IDENTITY_POLICY")["findings"]
        for finding in findings:
            print(f"Access Analyzer {finding['findingType']}: {finding['issueCode']}: {finding['findingDetails']}")
    failed = False
    for label, action, resource, key, value, expected in cases:
        contexts = [] if key is None else [{"ContextKeyName": key, "ContextKeyValues": [value], "ContextKeyType": "string"}]
        if action in ("iam:AttachRolePolicy", "iam:DetachRolePolicy"):
            contexts.extend([
                {"ContextKeyName": "aws:ResourceTag/Owner", "ContextKeyValues": ["drghassen"], "ContextKeyType": "string"},
                {"ContextKeyName": "aws:ResourceTag/Project", "ContextKeyValues": ["terraform-cloud-project"], "ContextKeyType": "string"},
                {"ContextKeyName": "aws:ResourceTag/Environment", "ContextKeyValues": ["dev"], "ContextKeyType": "string"},
            ])
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=[action], ResourceArns=[resource], ContextEntries=contexts)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"{label}: {actual} (expected {expected})")
        failed |= actual != expected
    foreign_context = [
        {"ContextKeyName": "iam:PolicyARN", "ContextKeyValues": [ssm], "ContextKeyType": "string"},
        {"ContextKeyName": "aws:ResourceTag/Owner", "ContextKeyValues": ["dhiablk"], "ContextKeyType": "string"},
        {"ContextKeyName": "aws:ResourceTag/Project", "ContextKeyValues": ["terraform-cloud-project"], "ContextKeyType": "string"},
        {"ContextKeyName": "aws:ResourceTag/Environment", "ContextKeyValues": ["dev"], "ContextKeyType": "string"},
    ]
    result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=["iam:AttachRolePolicy"], ResourceArns=[role], ContextEntries=foreign_context)
    actual = result["EvaluationResults"][0]["EvalDecision"]
    print(f"attach SSM to foreign-owned role: {actual} (expected implicitDeny)")
    failed |= actual != "implicitDeny"
    requested_tags = {"aws:RequestedRegion": "eu-west-1", "aws:RequestTag/Owner": "drghassen",
                      "aws:RequestTag/Project": "terraform-cloud-project", "aws:RequestTag/Environment": "dev"}
    for label, overrides, expected in (
        ("create VPC with owner", {}, "allowed"),
        ("create VPC without owner", {"aws:RequestTag/Owner": None}, "implicitDeny"),
        ("create VPC with foreign owner", {"aws:RequestTag/Owner": "dhiablk"}, "implicitDeny"),
    ):
        context = {**requested_tags, **overrides}
        contexts = [{"ContextKeyName": k, "ContextKeyValues": [v], "ContextKeyType": "string"} for k, v in context.items() if v is not None]
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=["ec2:CreateVpc"],
                                            ResourceArns=["arn:aws:ec2:eu-west-1:326553917564:vpc/vpc-0123456789abcdef0"], ContextEntries=contexts)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"{label}: {actual} (expected {expected})")
        failed |= actual != expected
    for label, action_name, expected in (
        ("tag VPC during creation", "CreateVpc", "allowed"),
        ("tag existing VPC", None, "implicitDeny"),
    ):
        context = {**requested_tags, "ec2:CreateAction": action_name}
        contexts = [{"ContextKeyName": k, "ContextKeyValues": [v], "ContextKeyType": "string"} for k, v in context.items() if v is not None]
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=["ec2:CreateTags"],
                                            ResourceArns=["arn:aws:ec2:eu-west-1:326553917564:vpc/vpc-0123456789abcdef0"], ContextEntries=contexts)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"{label}: {actual} (expected {expected})")
        failed |= actual != expected
    launch_values = {
        **requested_tags,
        "aws:ResourceTag/Owner": "drghassen",
        "aws:ResourceTag/Project": "terraform-cloud-project",
        "aws:ResourceTag/Environment": "dev",
        "ec2:LaunchTemplate": "arn:aws:ec2:eu-west-1:326553917564:launch-template/lt-0123456789abcdef0",
        "ec2:Owner": "amazon",
        "ec2:MetadataHttpTokens": "required",
    }
    launch_context = [{"ContextKeyName": k, "ContextKeyValues": [v], "ContextKeyType": "string"} for k, v in launch_values.items()]
    launch_context.append({"ContextKeyName": "ec2:AssociatePublicIpAddress", "ContextKeyValues": ["false"], "ContextKeyType": "boolean"})
    for label, resource in (
        ("instance", "arn:aws:ec2:eu-west-1:326553917564:instance/i-0123456789abcdef0"),
        ("volume", "arn:aws:ec2:eu-west-1:326553917564:volume/vol-0123456789abcdef0"),
        ("network interface", "arn:aws:ec2:eu-west-1:326553917564:network-interface/eni-0123456789abcdef0"),
        ("subnet", "arn:aws:ec2:eu-west-1:326553917564:subnet/subnet-0123456789abcdef0"),
        ("security group", "arn:aws:ec2:eu-west-1:326553917564:security-group/sg-0123456789abcdef0"),
        ("launch template", launch_values["ec2:LaunchTemplate"]),
        ("Amazon image", "arn:aws:ec2:eu-west-1::image/ami-0123456789abcdef0"),
    ):
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=["ec2:RunInstances"], ResourceArns=[resource], ContextEntries=launch_context)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"launch {label}: {actual} (expected allowed)")
        failed |= actual != "allowed"
    for action in ("ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress"):
        for resource in ("arn:aws:ec2:eu-west-1:326553917564:security-group/sg-0123456789abcdef0",
                         "arn:aws:ec2:eu-west-1:326553917564:security-group-rule/sgr-0123456789abcdef0"):
            result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=[action], ResourceArns=[resource], ContextEntries=launch_context)
            actual = result["EvaluationResults"][0]["EvalDecision"]
            print(f"{action} on {resource.split(':')[-1].split('/')[0]}: {actual} (expected allowed)")
            failed |= actual != "allowed"
    rule_context = launch_context + [{"ContextKeyName": "ec2:CreateAction", "ContextKeyValues": ["AuthorizeSecurityGroupIngress"], "ContextKeyType": "string"}]
    result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=["ec2:CreateTags"],
                                        ResourceArns=["arn:aws:ec2:eu-west-1:326553917564:security-group-rule/sgr-0123456789abcdef0"], ContextEntries=rule_context)
    actual = result["EvaluationResults"][0]["EvalDecision"]
    print(f"tag new security group rule: {actual} (expected allowed)")
    failed |= actual != "allowed"
    cases_create = [
        ("create ASG", "autoscaling:CreateAutoScalingGroup", "arn:aws:autoscaling:eu-west-1:326553917564:autoScalingGroup:01234567-0123-0123-0123-012345678901:autoScalingGroupName/cloud5-infra-dev-web-asg", "autoscaling:LaunchTemplateVersionSpecified", "true", "boolean"),
        ("tag ASG", "autoscaling:CreateOrUpdateTags", "arn:aws:autoscaling:eu-west-1:326553917564:autoScalingGroup:01234567-0123-0123-0123-012345678901:autoScalingGroupName/cloud5-infra-dev-web-asg", None, None, None),
        ("tag new RDS", "rds:AddTagsToResource", "arn:aws:rds:eu-west-1:326553917564:db:cloud5-infra-dev-postgres", None, None, None),
        ("tag new listener", "elasticloadbalancing:AddTags", "arn:aws:elasticloadbalancing:eu-west-1:326553917564:listener/app/cloud5-infra-dev-alb/0123456789abcdef/0123456789abcdef", "elasticloadbalancing:CreateAction", "CreateListener", "string"),
        ("create RDS-managed secret", "secretsmanager:CreateSecret", "arn:aws:secretsmanager:eu-west-1:326553917564:secret:rds!db-test-123456", None, None, None),
        ("tag RDS-managed secret", "secretsmanager:TagResource", "arn:aws:secretsmanager:eu-west-1:326553917564:secret:rds!db-test-123456", None, None, None),
    ]
    for label, action, resource, key, value, kind in cases_create:
        contexts = [{"ContextKeyName": k, "ContextKeyValues": [v], "ContextKeyType": "string"} for k, v in requested_tags.items()]
        if key:
            contexts.append({"ContextKeyName": key, "ContextKeyValues": [value], "ContextKeyType": kind})
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=[action], ResourceArns=[resource], ContextEntries=contexts)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"{label}: {actual} (expected allowed)")
        failed |= actual != "allowed"
    for alias, expected in (("alias/aws/secretsmanager", "allowed"), ("alias/other", "implicitDeny")):
        context = [
            {"ContextKeyName": "aws:RequestedRegion", "ContextKeyValues": ["eu-west-1"], "ContextKeyType": "string"},
            {"ContextKeyName": "kms:ResourceAliases", "ContextKeyValues": [alias], "ContextKeyType": "stringList"},
        ]
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=["kms:DescribeKey"],
                                            ResourceArns=["arn:aws:kms:eu-west-1:326553917564:key/01234567-0123-0123-0123-012345678901"], ContextEntries=context)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"describe KMS {alias}: {actual} (expected {expected})")
        failed |= actual != expected
    # Synthetic ARNs and tags exercise only the supplied policy; AWS does not
    # read or modify either resource. An allow demonstrates a known open gap.
    probes = [
        ("retag foreign subnet", "ec2:CreateTags", "arn:aws:ec2:eu-west-1:326553917564:subnet/subnet-0123456789abcdef0"),
        ("use foreign launch template", "ec2:RunInstances", "arn:aws:ec2:eu-west-1:326553917564:launch-template/lt-0123456789abcdef0"),
        ("use foreign subnet", "ec2:RunInstances", "arn:aws:ec2:eu-west-1:326553917564:subnet/subnet-0123456789abcdef0"),
        ("use foreign security group", "ec2:RunInstances", "arn:aws:ec2:eu-west-1:326553917564:security-group/sg-0123456789abcdef0"),
        ("remove protected RDS tag", "rds:RemoveTagsFromResource", "arn:aws:rds:eu-west-1:326553917564:db:cloud5-infra-dev-postgres"),
        ("remove protected load balancer tag", "elasticloadbalancing:RemoveTags", "arn:aws:elasticloadbalancing:eu-west-1:326553917564:loadbalancer/app/cloud5-infra-dev-alb/0123456789abcdef"),
        ("remove protected role tag", "iam:UntagRole", role),
        ("replace bucket tags", "s3:PutBucketTagging", "arn:aws:s3:::cloud5-infra-dev-storage-326553917564"),
        ("change instance role trust", "iam:UpdateAssumeRolePolicy", role),
        ("create instance role with arbitrary trust", "iam:CreateRole", role),
        ("add role to instance profile", "iam:AddRoleToInstanceProfile", "arn:aws:iam::326553917564:instance-profile/cloud5-infra-dev-web-instance-profile"),
        ("read RDS secret value", "secretsmanager:GetSecretValue", "arn:aws:secretsmanager:eu-west-1:326553917564:secret:rds!db-test-123456"),
        ("create unrelated secret", "secretsmanager:CreateSecret", "arn:aws:secretsmanager:eu-west-1:326553917564:secret:other-aaaaaa"),
    ]
    for label, action, resource in probes:
        contexts = [
            {"ContextKeyName": "aws:RequestedRegion", "ContextKeyValues": ["eu-west-1"], "ContextKeyType": "string"},
            {"ContextKeyName": "aws:ResourceTag/Owner", "ContextKeyValues": ["dhiablk"], "ContextKeyType": "string"},
            {"ContextKeyName": "aws:TagKeys", "ContextKeyValues": ["Owner"], "ContextKeyType": "stringList"},
            {"ContextKeyName": "aws:RequestTag/Owner", "ContextKeyValues": ["drghassen"], "ContextKeyType": "string"},
            {"ContextKeyName": "aws:RequestTag/Project", "ContextKeyValues": ["terraform-cloud-project"], "ContextKeyType": "string"},
            {"ContextKeyName": "aws:RequestTag/Environment", "ContextKeyValues": ["dev"], "ContextKeyType": "string"},
            {"ContextKeyName": "aws:ResourceTag/Project", "ContextKeyValues": ["terraform-cloud-project"], "ContextKeyType": "string"},
            {"ContextKeyName": "aws:ResourceTag/Environment", "ContextKeyValues": ["dev"], "ContextKeyType": "string"},
            {"ContextKeyName": "ec2:LaunchTemplate", "ContextKeyValues": ["arn:aws:ec2:eu-west-1:326553917564:launch-template/lt-0123456789abcdef0"], "ContextKeyType": "string"},
            {"ContextKeyName": "ec2:MetadataHttpTokens", "ContextKeyValues": ["required"], "ContextKeyType": "string"},
        ]
        result = iam.simulate_custom_policy(PolicyInputList=list(policies[0]), ActionNames=[action], ResourceArns=[resource], ContextEntries=contexts)
        actual = result["EvaluationResults"][0]["EvalDecision"]
        print(f"SECURITY PROBE {label}: {actual} (required: denied)")
        failed |= actual == "allowed"
    if failed:
        raise ValueError("IAM policy does not satisfy all expected security decisions")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"IAM audit failed: {exc}", file=sys.stderr)
        sys.exit(1)
