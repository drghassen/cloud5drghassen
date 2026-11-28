import copy
import json
import unittest

from check_plan_ownership import (
    SNS_ADDRESS,
    SNS_ARN,
    SNS_KMS_ARN,
    SNS_NAME,
    expected_sns_policy,
    validate_plan,
)

COMMIT = "a" * 40
DIGEST = "b" * 64

TAGS = {
    "Owner": "drghassen",
    "Project": "terraform-cloud-project",
    "Environment": "dev",
    "ManagedBy": "Terraform",
}


def topic():
    return {
        "address": SNS_ADDRESS,
        "mode": "managed",
        "type": "aws_sns_topic",
        "change": {
            "actions": ["create"],
            "before": None,
            "after": {
                "name": SNS_NAME,
                "fifo_topic": False,
                "kms_master_key_id": SNS_KMS_ARN,
                "policy": json.dumps(expected_sns_policy()),
                "tags_all": dict(TAGS),
            },
            "after_unknown": {
                "arn": True,
            },
        },
    }


def alarm():
    return {
        "address": (
            'module.monitoring.aws_cloudwatch_metric_alarm.this'
            '["healthy-hosts-low"]'
        ),
        "mode": "managed",
        "type": "aws_cloudwatch_metric_alarm",
        "change": {
            "actions": ["create"],
            "before": None,
            "after": {
                "alarm_name": "cloud5-infra-dev-healthy-hosts-low",
                "actions_enabled": True,
                "alarm_actions": [SNS_ARN],
                "ok_actions": [SNS_ARN],
                "insufficient_data_actions": [],
                "tags_all": dict(TAGS),
            },
            "after_unknown": {},
        },
    }


class NotificationsOwnershipTest(unittest.TestCase):

    def check(self, resource, environment="dev", approval=None):
        validate_plan(
            {"resource_changes": [resource]},
            environment,
            COMMIT,
            DIGEST,
            approval,
        )

    def test_valid_topic(self):
        self.check(topic())

    def test_valid_alarm(self):
        self.check(alarm())

    def test_foreign_topic_name(self):
        resource = topic()
        resource["change"]["after"]["name"] = "foreign-alerts"
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_unexpected_topic_address(self):
        resource = topic()
        resource["address"] += "[0]"
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_foreign_kms_key(self):
        resource = topic()
        resource["change"]["after"]["kms_master_key_id"] = "alias/aws/sns"
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_fifo_topic_rejected(self):
        resource = topic()
        resource["change"]["after"]["fifo_topic"] = True
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_unknown_security_fields(self):
        for field in (
            "name", "kms_master_key_id", "policy", "fifo_topic"
        ):
            with self.subTest(field=field):
                resource = topic()
                resource["change"]["after_unknown"][field] = True
                with self.assertRaises(ValueError):
                    self.check(resource)

    def test_foreign_owner(self):
        resource = topic()
        resource["change"]["after"]["tags_all"]["Owner"] = "foreign"
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_missing_tags(self):
        resource = topic()
        del resource["change"]["after"]["tags_all"]
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_permissive_policy(self):
        resource = topic()
        policy = expected_sns_policy()
        policy["Statement"].append({
            "Effect": "Allow",
            "Principal": "*",
            "Action": "sns:Publish",
            "Resource": SNS_ARN,
        })
        resource["change"]["after"]["policy"] = json.dumps(policy)
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_foreign_alarm_in_topic_policy(self):
        resource = topic()
        policy = expected_sns_policy()
        policy["Statement"][1]["Condition"]["ArnEquals"][
            "aws:SourceArn"
        ].append("arn:aws:cloudwatch:eu-west-1:111122223333:alarm:foreign")
        resource["change"]["after"]["policy"] = json.dumps(policy)
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_policy_order_independent(self):
        resource = topic()
        policy = expected_sns_policy()
        policy["Statement"].reverse()
        resource["change"]["after"]["policy"] = json.dumps(policy)
        self.check(resource)

    def test_non_dev_topic_rejected(self):
        for environment in ("test", "prod"):
            with self.subTest(environment=environment):
                with self.assertRaises(ValueError):
                    self.check(topic(), environment)

    def test_foreign_alarm_destination(self):
        for field in ("alarm_actions", "ok_actions"):
            with self.subTest(field=field):
                resource = alarm()
                resource["change"]["after"][field] = [
                    "arn:aws:sns:eu-west-1:111122223333:foreign-alerts"
                ]
                with self.assertRaises(ValueError):
                    self.check(resource)

    def test_unknown_alarm_destination(self):
        resource = alarm()
        resource["change"]["after_unknown"]["alarm_actions"] = [True]
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_insufficient_data_destination_rejected(self):
        resource = alarm()
        resource["change"]["after"]["insufficient_data_actions"] = [
            SNS_ARN
        ]
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_controlled_alarm_disable(self):
        resource = alarm()
        resource["change"]["after"].update(
            actions_enabled=False,
            alarm_actions=[],
            ok_actions=[],
        )
        self.check(resource)

    def test_disabled_alarm_with_destination_rejected(self):
        resource = alarm()
        resource["change"]["after"]["actions_enabled"] = False
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_missing_alarm_action_field(self):
        resource = alarm()
        del resource["change"]["after"]["alarm_actions"]
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_valid_topic_update(self):
        resource = topic()
        before = copy.deepcopy(resource["change"]["after"])
        before["arn"] = SNS_ARN
        resource["change"].update(
            actions=["update"],
            before=before,
        )
        self.check(resource)

    def test_foreign_prior_topic(self):
        resource = topic()
        before = copy.deepcopy(resource["change"]["after"])
        before["arn"] = SNS_ARN
        before["tags_all"]["Owner"] = "foreign"
        resource["change"].update(
            actions=["update"],
            before=before,
        )
        with self.assertRaises(ValueError):
            self.check(resource)

    def test_deletion_requires_approval(self):
        resource = topic()
        before = copy.deepcopy(resource["change"]["after"])
        before["arn"] = SNS_ARN

        resource["change"] = {
            "actions": ["delete"],
            "before": before,
            "after": None,
            "after_unknown": {},
        }

        with self.assertRaises(ValueError):
            self.check(resource)

        self.check(resource, approval={
            "environment": "dev",
            "commit": COMMIT,
            "sha256": DIGEST,
            "addresses": [SNS_ADDRESS],
        })


if __name__ == "__main__":
    unittest.main()
