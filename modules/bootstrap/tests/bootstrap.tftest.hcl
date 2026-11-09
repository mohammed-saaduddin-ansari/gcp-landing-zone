mock_provider "google" {
  # A realistic pool name so the WIF member strings in the assertions are meaningful.
  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/100000000001/locations/global/workloadIdentityPools/github"
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      name   = "projects/seed-prj/serviceAccounts/tf-mock@seed-prj.iam.gserviceaccount.com"
      member = "serviceAccount:tf-mock@seed-prj.iam.gserviceaccount.com"
    }
  }
}

variables {
  org_id              = "123456789012"
  folder_id           = "folders/222222222222"
  billing_account     = "0A0A0A-0B0B0B-0C0C0C"
  project_id          = "prj-b-seed-1a2b"
  state_bucket_name   = "example-tfstate-1a2b"
  github_repositories = ["example-org/gcp-landing-zone"]

  service_accounts = {
    org = {
      display_name = "Terraform: org stage"
      repository   = "example-org/gcp-landing-zone"
      org_roles    = ["roles/resourcemanager.folderAdmin", "roles/orgpolicy.policyAdmin"]
    }
    projects = {
      display_name  = "Terraform: project factory"
      repository    = "example-org/gcp-landing-zone"
      wif_subjects  = ["repo:example-org/gcp-landing-zone:environment:projects"]
      billing_roles = ["roles/billing.user"]
    }
  }
}

run "state_bucket_is_hardened" {
  command = apply

  assert {
    condition     = google_storage_bucket.state.versioning[0].enabled
    error_message = "State bucket must be versioned."
  }

  assert {
    condition     = google_storage_bucket.state.public_access_prevention == "enforced" && google_storage_bucket.state.uniform_bucket_level_access
    error_message = "State bucket must enforce public access prevention and uniform bucket-level access."
  }

  assert {
    condition     = !google_storage_bucket.state.force_destroy
    error_message = "State bucket must not be force-destroyable."
  }

  assert {
    condition     = google_project.seed.deletion_policy == "PREVENT" && !google_project.seed.auto_create_network
    error_message = "Seed project must be deletion-protected and have no default network."
  }
}

run "wif_is_scoped_to_repositories" {
  command = apply

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.attribute_condition == "assertion.repository in ['example-org/gcp-landing-zone']"
    error_message = "Provider must reject tokens from unlisted repositories."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "Provider must trust the GitHub Actions issuer."
  }

  assert {
    condition     = google_service_account_iam_member.wif["org|repository"].member == "principalSet://iam.googleapis.com/projects/100000000001/locations/global/workloadIdentityPools/github/attribute.repository/example-org/gcp-landing-zone"
    error_message = "Repository-wide binding has the wrong principal set."
  }

  assert {
    condition     = google_service_account_iam_member.wif["projects|repo:example-org/gcp-landing-zone:environment:projects"].member == "principal://iam.googleapis.com/projects/100000000001/locations/global/workloadIdentityPools/github/subject/repo:example-org/gcp-landing-zone:environment:projects"
    error_message = "Subject binding has the wrong principal."
  }

  assert {
    condition     = length(google_service_account_iam_member.wif) == 2
    error_message = "A subject-bound account must not also get a repository-wide binding."
  }
}

run "least_privilege_grants" {
  command = plan

  assert {
    condition     = length(google_organization_iam_member.ci) == 2 && length(google_billing_account_iam_member.ci) == 1
    error_message = "Each stage should get only its own org and billing roles."
  }

  assert {
    condition     = google_service_account.ci["org"].account_id == "tf-org"
    error_message = "Service account IDs should be tf-<stage>."
  }
}

run "rejects_unlisted_repository" {
  command = plan

  variables {
    service_accounts = {
      org = {
        display_name = "Terraform: org stage"
        repository   = "someone-else/fork"
      }
    }
  }

  expect_failures = [google_service_account_iam_member.wif]
}

run "rejects_lowercase_billing_account" {
  command = plan

  variables {
    billing_account = "0a0a0a-0b0b0b-0c0c0c"
  }

  expect_failures = [var.billing_account]
}
