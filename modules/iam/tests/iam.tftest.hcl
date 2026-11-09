mock_provider "google" {}

variables {
  org_id = "123456789012"
}

run "expands_bindings_per_member" {
  command = plan

  variables {
    org_bindings = {
      "roles/resourcemanager.organizationViewer" = ["group:gcp-auditors@example.com", "group:gcp-security-admins@example.com"]
      "roles/securitycenter.admin"               = ["group:gcp-security-admins@example.com"]
    }
    folder_bindings = {
      prod = {
        folder   = "folders/111111111111"
        bindings = { "roles/viewer" = ["group:prod-readers@example.com"] }
      }
    }
  }

  assert {
    condition     = length(google_organization_iam_member.this) == 3
    error_message = "Expected one grant per role/member pair."
  }

  assert {
    condition     = google_folder_iam_member.this["prod|roles/viewer|group:prod-readers@example.com"].folder == "folders/111111111111"
    error_message = "Folder grant should target the given folder."
  }

  assert {
    condition     = output.binding_count.organization == 3 && output.binding_count.folder == 1
    error_message = "binding_count output is wrong."
  }
}

run "rejects_user_principals" {
  command = plan

  variables {
    org_bindings = { "roles/viewer" = ["user:someone@example.com"] }
  }

  expect_failures = [var.org_bindings]
}

run "rejects_service_accounts_on_folders" {
  command = plan

  variables {
    folder_bindings = {
      prod = {
        folder   = "folders/111111111111"
        bindings = { "roles/viewer" = ["serviceAccount:ci@seed.iam.gserviceaccount.com"] }
      }
    }
  }

  expect_failures = [var.folder_bindings]
}

run "rejects_basic_roles" {
  command = plan

  variables {
    project_bindings = {
      app = {
        project  = "prj-app-1234"
        bindings = { "roles/editor" = ["group:devs@example.com"] }
      }
    }
  }

  expect_failures = [google_project_iam_member.this]
}
