mock_provider "google" {
  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/100000000001/locations/global/workloadIdentityPools/github"
    }
  }

  # Mocked computed values are random strings, which the provider rejects as IAM members.
  mock_resource "google_service_account" {
    defaults = {
      name   = "projects/prj-b-seed-1a2b/serviceAccounts/tf-mock@prj-b-seed-1a2b.iam.gserviceaccount.com"
      member = "serviceAccount:tf-mock@prj-b-seed-1a2b.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_folder" {
    defaults = {
      name = "folders/100000000009"
    }
  }
}

variables {
  org_id            = "123456789012"
  billing_account   = "012345-6789AB-CDEF01"
  seed_project_id   = "prj-b-seed-1a2b"
  state_bucket_name = "example-org-tfstate-1a2b"
  github_repository = "example-org/gcp-landing-zone"
}

run "plan_and_apply_identities_per_stage" {
  command = apply

  assert {
    condition     = toset(keys(output.ci_service_accounts)) == toset(["org", "org-plan", "networking", "networking-plan", "projects", "projects-plan"])
    error_message = "Expected a plan and an apply identity for each of the three stages."
  }

  assert {
    condition     = module.bootstrap.backend_configs["networking-plan"].prefix == "networking"
    error_message = "Plan identities must read the same state prefix as their stage."
  }
}

run "apply_identities_require_environment" {
  command = plan

  assert {
    condition     = contains(keys(module.bootstrap.service_account_emails), "org")
    error_message = "Apply identity missing."
  }

  # With apply_environments (the default) the apply identity is bound to the GitHub environment only.
  assert {
    condition     = length(local.identities["org"].wif_subjects) == 1 && local.identities["org"].wif_subjects[0] == "repo:example-org/gcp-landing-zone:environment:org"
    error_message = "Apply identity should be bound to the org environment."
  }

  assert {
    condition     = length(local.identities["org-plan"].wif_subjects) == 0 && local.identities["org-plan"].state_bucket_role == "roles/storage.objectViewer"
    error_message = "Plan identity should be repository-wide and read-only on state."
  }
}
