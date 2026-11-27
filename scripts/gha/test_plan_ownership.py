import copy
import unittest

from check_plan_ownership import validate_plan

COMMIT = "a" * 40
DIGEST = "b" * 64
ADDRESS = "module.network.aws_vpc.this"
TAGS = {"Owner": "drghassen", "Project": "terraform-cloud-project", "Environment": "dev", "ManagedBy": "Terraform"}


def make_plan(actions=None):
    return {"resource_changes": [{
        "mode": "managed", "address": ADDRESS, "type": "aws_vpc",
        "change": {"actions": actions or ["create"], "before": None,
                   "after": {"tags_all": dict(TAGS)}, "after_unknown": {}},
    }]}


class PlanOwnershipTest(unittest.TestCase):
    def check(self, plan, approval=None):
        validate_plan(plan, "dev", COMMIT, DIGEST, approval)

    def test_creation_with_valid_tags(self):
        self.check(make_plan())

    def test_missing_and_foreign_owner(self):
        for value in (None, "dhiablk"):
            plan = make_plan()
            if value is None:
                del plan["resource_changes"][0]["change"]["after"]["tags_all"]["Owner"]
            else:
                plan["resource_changes"][0]["change"]["after"]["tags_all"]["Owner"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.check(plan)

    def test_unknown_tags_are_rejected(self):
        for unknown_value in (True, {"Owner": True}, {"Name": True}):
            plan = make_plan()
            plan["resource_changes"][0]["change"]["after_unknown"]["tags_all"] = unknown_value
            with self.subTest(value=unknown_value), self.assertRaises(ValueError):
                self.check(plan)

    def test_foreign_resource_cannot_be_retagged(self):
        plan = make_plan(["update"])
        plan["resource_changes"][0]["change"]["before"] = {"tags_all": {**TAGS, "Owner": "dhiablk"}}
        with self.assertRaises(ValueError):
            self.check(plan)

    def test_owner_cannot_be_removed_or_changed(self):
        for owner in (None, "dhiablk"):
            plan = make_plan(["update"])
            plan["resource_changes"][0]["change"]["before"] = {"tags_all": dict(TAGS)}
            plan["resource_changes"][0]["change"]["after"]["tags_all"]["Owner"] = owner
            with self.subTest(owner=owner), self.assertRaises(ValueError):
                self.check(plan)

    def test_out_of_scope_and_nontaggable_child_fail_closed(self):
        for address, kind in (("module.network.aws_vpc.other", "aws_vpc"),
                              ("module.network.aws_route.public_internet", "aws_route")):
            plan = make_plan()
            plan["resource_changes"][0].update(address=address, type=kind)
            with self.subTest(address=address), self.assertRaises(ValueError):
                self.check(plan)

    def test_deletion_requires_matching_plan_specific_approval(self):
        plan = make_plan(["delete"])
        plan["resource_changes"][0]["change"]["before"] = {"tags_all": dict(TAGS)}
        approval = {"environment": "dev", "commit": COMMIT, "sha256": DIGEST, "addresses": [ADDRESS]}
        with self.assertRaises(ValueError):
            self.check(plan)
        self.check(plan, approval)
        for field, value in (("environment", "prod"), ("commit", "c" * 40), ("sha256", "d" * 64), ("addresses", [])):
            wrong = copy.deepcopy(approval)
            wrong[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.check(plan, wrong)

    def test_replacement_requires_approval_and_owned_before_and_after(self):
        approval = {"environment": "dev", "commit": COMMIT, "sha256": DIGEST, "addresses": [ADDRESS]}
        for actions in (["delete", "create"], ["create", "delete"]):
            plan = make_plan(actions)
            plan["resource_changes"][0]["change"]["before"] = {"tags_all": dict(TAGS)}
            with self.subTest(actions=actions):
                with self.assertRaises(ValueError):
                    self.check(plan)
                self.check(plan, approval)
                plan["resource_changes"][0]["change"]["before"]["tags_all"]["Owner"] = "dhiablk"
                with self.assertRaises(ValueError):
                    self.check(plan, approval)

    def test_autoscaling_policy_requires_matching_owned_parent(self):
        group = {"mode": "managed", "address": "module.compute.aws_autoscaling_group.web", "type": "aws_autoscaling_group",
                 "change": {"actions": ["create"], "before": None,
                            "after": {"name": "cloud5-infra-dev-web-asg", "tag": [{"key": k, "value": v} for k, v in TAGS.items()]}, "after_unknown": {}}}
        child = {"mode": "managed", "address": "module.compute.aws_autoscaling_policy.cpu_target", "type": "aws_autoscaling_policy",
                 "change": {"actions": ["create"], "before": None,
                            "after": {"autoscaling_group_name": "cloud5-infra-dev-web-asg"}, "after_unknown": {}}}
        self.check({"resource_changes": [group, child]})
        other = copy.deepcopy(group)
        other["change"]["after"]["tag"][0]["value"] = "dhiablk"
        with self.assertRaises(ValueError):
            self.check({"resource_changes": [other, child]})
        with self.assertRaises(ValueError):
            self.check({"resource_changes": [child]})
        other_child = copy.deepcopy(child)
        other_child["change"]["after"]["autoscaling_group_name"] = "foreign-asg"
        with self.assertRaises(ValueError):
            self.check({"resource_changes": [group, other_child]})

    def test_import_or_move_is_rejected(self):
        for key, value in (("previous_address", "other"), ("importing", {"id": "foreign"})):
            plan = make_plan(["no-op"])
            target = plan["resource_changes"][0]
            (target["change"] if key == "importing" else target)[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.check(plan)

    def test_full_dev_plan_requires_exact_listener_approval(self):
        specs = [
            ("aws_vpc_security_group_egress_rule.web_to_database", "aws_vpc_security_group_egress_rule", ["create"]),
            ("module.database.aws_vpc_security_group_ingress_rule.from_web", "aws_vpc_security_group_ingress_rule", ["create"]),
            ("module.security.aws_vpc_security_group_egress_rule.alb_to_web", "aws_vpc_security_group_egress_rule", ["create"]),
            ("module.security.aws_vpc_security_group_egress_rule.web_https", "aws_vpc_security_group_egress_rule", ["create"]),
            ("module.security.aws_vpc_security_group_ingress_rule.alb_http", "aws_vpc_security_group_ingress_rule", ["create"]),
            ("module.security.aws_vpc_security_group_ingress_rule.web_from_alb", "aws_vpc_security_group_ingress_rule", ["create"]),
            ("module.database.aws_db_instance.this", "aws_db_instance", ["create"]),
            ("module.compute.aws_launch_template.web", "aws_launch_template", ["update"]),
            ("module.load_balancer.aws_lb_listener.http", "aws_lb_listener", ["delete", "create"]),
        ]
        changes = []
        for address, kind, actions in specs:
            changes.append({"mode": "managed", "address": address, "type": kind,
                            "change": {"actions": actions, "before": {"tags_all": dict(TAGS)},
                                       "after": {"tags_all": dict(TAGS)}, "after_unknown": {}}})
        changes.append({"mode": "managed", "address": "module.compute.aws_autoscaling_group.web",
                        "type": "aws_autoscaling_group", "change": {"actions": ["create"], "before": None,
                        "after": {"name": "cloud5-infra-dev-web-asg", "tag": [{"key": k, "value": v} for k, v in TAGS.items()]}, "after_unknown": {}}})
        changes.append({"mode": "managed", "address": "module.compute.aws_autoscaling_policy.cpu_target",
                        "type": "aws_autoscaling_policy", "change": {"actions": ["create"], "before": None,
                        "after": {"autoscaling_group_name": "cloud5-infra-dev-web-asg"}, "after_unknown": {}}})
        plan = {"resource_changes": changes}
        approval = {"environment": "dev", "commit": COMMIT, "sha256": DIGEST,
                    "addresses": ["module.load_balancer.aws_lb_listener.http"]}
        with self.assertRaises(ValueError):
            self.check(plan)
        self.check(plan, approval)
        approval["sha256"] = "d" * 64
        with self.assertRaises(ValueError):
            self.check(plan, approval)


if __name__ == "__main__":
    unittest.main()
