import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from check_checkov import dev_zero_backups_configured, evaluate, is_dev_exception


class CheckovExceptionTest(unittest.TestCase):
    def setUp(self):
        self.dev = {
            "check_id": "CKV_AWS_133",
            "resource": "module.database.aws_db_instance.this",
            "file_path": "/modules/database/main.tf",
            "caller_file_path": "/environments/dev/main.tf",
        }

    def test_only_exact_dev_database_and_accepted_zero_setting(self):
        self.assertTrue(is_dev_exception(self.dev, True))
        self.assertFalse(is_dev_exception(self.dev, False))
        for key, value in (
            ("caller_file_path", "/environments/test/main.tf"),
            ("caller_file_path", "/environments/prod/main.tf"),
            ("caller_file_path", None),
            ("resource", "module.other.aws_db_instance.this"),
            ("check_id", "CKV_AWS_999"),
            ("file_path", "/other/main.tf"),
        ):
            self.assertFalse(is_dev_exception({**self.dev, key: value}, True))

    def test_other_failures_and_scan_errors_fail_closed(self):
        test = {**self.dev, "caller_file_path": "/environments/test/main.tf"}
        report = {"summary": {"failed": 2, "parsing_errors": 0},
                  "results": {"failed_checks": [self.dev, test]}}
        self.assertEqual(evaluate(report, 1, True), (1, [test], 1))
        with self.assertRaises(ValueError):
            evaluate(report, 2, True)
        report["summary"]["parsing_errors"] = 1
        with self.assertRaises(ValueError):
            evaluate(report, 1, True)
        report["summary"]["parsing_errors"] = 0
        report["summary"]["failed"] = 3
        with self.assertRaises(ValueError):
            evaluate(report, 1, True)

    def test_exception_requires_zero_in_both_dev_configuration_files(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            dev = root / "environments/dev"
            dev.mkdir(parents=True)
            variables = dev / "variables.tf"
            example = dev / "terraform.tfvars.example"
            variables.write_text('variable "db_backup_retention_period" {\n  default = 0\n}\n')
            example.write_text("db_backup_retention_period = 0\n")
            self.assertTrue(dev_zero_backups_configured(root))
            example.write_text("db_backup_retention_period = 1\n")
            self.assertFalse(dev_zero_backups_configured(root))
            example.write_text("db_backup_retention_period = 0\n")
            variables.write_text('variable "db_backup_retention_period" {\n  default = 1\n}\n')
            self.assertFalse(dev_zero_backups_configured(root))
if __name__ == "__main__":
    unittest.main()
