mock_provider "aws" {}

run "reject_other_owner" {
  command = plan
  variables {
    owner = "dhiablk"
  }
  expect_failures = [var.owner]
}

run "reject_missing_owner" {
  command = plan
  variables {
    owner = null
  }
  expect_failures = [var.owner]
}

run "reject_other_project" {
  command = plan
  variables {
    project_name = "other-project"
  }
  expect_failures = [var.project_name]
}
