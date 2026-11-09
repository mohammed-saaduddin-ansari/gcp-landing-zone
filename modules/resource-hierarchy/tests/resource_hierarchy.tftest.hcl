# Runs entirely offline: the google provider is mocked, so no credentials are needed.
mock_provider "google" {}

variables {
  parent = "organizations/123456789012"
}

run "creates_default_folders" {
  command = plan

  assert {
    condition     = length(google_folder.top) == 5
    error_message = "Expected the five default top-level folders."
  }

  assert {
    condition     = toset(keys(google_folder.top)) == toset(["bootstrap", "common", "prod", "nonprod", "sandbox"])
    error_message = "Unexpected set of top-level folders."
  }

  assert {
    condition     = alltrue([for f in google_folder.top : f.deletion_protection])
    error_message = "Folders must be deletion-protected by default."
  }
}

run "display_name_override_and_subfolders" {
  command = apply

  variables {
    folders       = ["prod", "nonprod"]
    display_names = { prod = "Production" }
    subfolders    = { prod = ["payments", "data"] }
  }

  assert {
    condition     = google_folder.top["prod"].display_name == "Production"
    error_message = "Display name override was not applied."
  }

  assert {
    condition     = google_folder.top["nonprod"].display_name == "nonprod"
    error_message = "Folder key should be the default display name."
  }

  assert {
    condition     = google_folder.sub["prod/payments"].parent == google_folder.top["prod"].name
    error_message = "Subfolder should be parented to its top-level folder."
  }

  assert {
    condition     = length(output.subfolder_ids) == 2
    error_message = "Expected two subfolders in the output."
  }
}

run "rejects_bad_parent" {
  command = plan

  variables {
    parent = "123456789012"
  }

  expect_failures = [var.parent]
}

run "rejects_duplicate_folders" {
  command = plan

  variables {
    folders = ["prod", "prod"]
  }

  expect_failures = [var.folders]
}

run "rejects_subfolder_with_unknown_parent" {
  command = plan

  variables {
    folders    = ["prod"]
    subfolders = { staging = ["team-a"] }
  }

  # The subfolder resource has no parent folder to reference; Terraform reports the bad key.
  expect_failures = [google_folder.sub]
}
