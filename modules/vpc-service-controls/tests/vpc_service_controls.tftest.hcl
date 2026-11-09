mock_provider "google" {}

variables {
  access_policy_id = "987654321"
  perimeter_name   = "prod_data"
  resources        = ["projects/100000000042", "projects/100000000043"]
}

run "dry_run_by_default" {
  command = plan

  assert {
    condition     = google_access_context_manager_service_perimeter.this.use_explicit_dry_run_spec
    error_message = "Dry-run must use the explicit dry-run spec."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.this.spec) == 1 && length(google_access_context_manager_service_perimeter.this.status) == 0
    error_message = "In dry-run, configuration must be in spec only and nothing enforced."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter.this.name == "accessPolicies/987654321/servicePerimeters/prod_data"
    error_message = "Perimeter name is wrong."
  }
}

run "enforced" {
  command = plan

  variables {
    mode = "enforced"
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.this.status) == 1 && length(google_access_context_manager_service_perimeter.this.spec) == 0
    error_message = "Enforced mode must write the live status."
  }

  assert {
    condition     = contains(google_access_context_manager_service_perimeter.this.status[0].restricted_services, "storage.googleapis.com")
    error_message = "Cloud Storage should be restricted by default."
  }
}

run "rejects_project_ids" {
  command = plan

  variables {
    resources = ["projects/prj-p-payments-api"]
  }

  expect_failures = [var.resources]
}

run "requires_a_policy" {
  command = plan

  variables {
    access_policy_id = null
  }

  expect_failures = [google_access_context_manager_service_perimeter.this]
}
