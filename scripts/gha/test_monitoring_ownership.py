import copy
import unittest

from check_plan_ownership import validate_plan

COMMIT = "a" * 40
DIGEST = "b" * 64

TAGS = {
    "Owner": "drghassen",
    "Project": "terraform-cloud-project",
    "Environment": "dev",
    "ManagedBy": "Terraform",
}

DASHBOARD = "module.monitoring.aws_cloudwatch_dashboard.operations"
ALARM = 'module.monitoring.aws_cloudwatch_metric_alarm.this["healthy-hosts-low"]'


def dashboard():
    return {
        "address": DASHBOARD,
        "mode": "managed",
        "type": "aws_cloudwatch_dashboard",
        "change": {
            "actions": ["create"],
            "before": None,
            "after": {
                "dashboard_name": "cloud5-infra-dev-operations",
            },
            "after_unknown": {},
        },
    }


def alarm():
    return {
        "address": ALARM,
        "mode": "managed",
        "type": "aws_cloudwatch_metric_alarm",
        "change": {
            "actions": ["create"],
            "before": None,
            "after": {
                "alarm_name": "cloud5-infra-dev-healthy-hosts-low",
                "tags_all": dict(TAGS),
            },
            "after_unknown": {},
        },
    }


class MonitoringOwnershipTest(unittest.TestCase):

    def validate(self, resource, environment="dev", approval=None):
        validate_plan(
            {"resource_changes": [resource]},
            environment,
            COMMIT,
            DIGEST,
            approval,
        )

    def test_valid_dashboard(self):
        self.validate(dashboard())

    def test_foreign_dashboard_rejected(self):
        resource = dashboard()
        resource["change"]["after"]["dashboard_name"] = "foreign-dashboard"
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_unknown_dashboard_name_rejected(self):
        resource = dashboard()
        resource["change"]["after_unknown"]["dashboard_name"] = True
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_dashboard_outside_dev_rejected(self):
        for environment in ("test", "prod"):
            with self.subTest(environment=environment):
                with self.assertRaises(ValueError):
                    self.validate(dashboard(), environment)

    def test_dashboard_deletion_requires_approval(self):
        resource = dashboard()
        resource["change"] = {
            "actions": ["delete"],
            "before": resource["change"]["after"],
            "after": None,
            "after_unknown": {},
        }

        with self.assertRaises(ValueError):
            self.validate(resource)

        approval = {
            "environment": "dev",
            "commit": COMMIT,
            "sha256": DIGEST,
            "addresses": [DASHBOARD],
        }

        self.validate(resource, approval=approval)

    def test_valid_alarm(self):
        self.validate(alarm())

    def test_foreign_alarm_rejected(self):
        resource = alarm()
        resource["change"]["after"]["alarm_name"] = "foreign-alarm"
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_unknown_alarm_key_rejected(self):
        resource = alarm()
        resource["address"] = (
            'module.monitoring.aws_cloudwatch_metric_alarm.this["foreign"]'
        )
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_missing_alarm_tags_rejected(self):
        resource = alarm()
        del resource["change"]["after"]["tags_all"]
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_foreign_alarm_owner_rejected(self):
        resource = alarm()
        resource["change"]["after"]["tags_all"]["Owner"] = "foreign"
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_unknown_alarm_tags_rejected(self):
        resource = alarm()
        resource["change"]["after_unknown"]["tags_all"] = True
        with self.assertRaises(ValueError):
            self.validate(resource)

    def test_alarm_retagging_rejected(self):
        resource = alarm()
        resource["change"]["actions"] = ["update"]
        resource["change"]["before"] = copy.deepcopy(
            resource["change"]["after"]
        )
        resource["change"]["before"]["tags_all"]["Owner"] = "foreign"

        with self.assertRaises(ValueError):
            self.validate(resource)


if __name__ == "__main__":
    unittest.main()
