"""Report only fixed labels and counts of resource-instance actions."""
import json
import sys
from collections import Counter

LABELS = {
    ("create",): "Create", ("update",): "Update", ("delete",): "Delete",
    ("read",): "Read", ("no-op",): "No-op",
    ("delete", "create"): "Replace (delete then create)",
    ("create", "delete"): "Replace (create then delete)",
}


def main():
    try:
        plan = json.load(sys.stdin)
        if not isinstance(plan, dict) or not isinstance(plan.get("resource_changes", []), list):
            raise ValueError()
        counts = Counter()
        for item in plan.get("resource_changes", []):
            actions = item["change"]["actions"]
            if not isinstance(actions, list) or not all(isinstance(x, str) for x in actions):
                raise ValueError()
            key = tuple(actions)
            if key not in LABELS:
                raise ValueError()
            counts[key] += 1
    except (ValueError, TypeError, KeyError):
        print("Invalid or unsupported plan structure.", file=sys.stderr)
        return 1
    print("\n### Resource-instance action counts\n")
    for actions, label in LABELS.items():
        print(f"- {label}: {counts[actions]}")
    if not any(counts[key] for key in LABELS if key != ("no-op",)):
        print("\nNo resource-instance changes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
