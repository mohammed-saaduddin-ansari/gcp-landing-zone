mock_provider "google" {
  mock_resource "google_project" {
    defaults = {
      number = "100000000042"
    }
  }
}

variables {
  billing_account = "0A0A0A-0B0B0B-0C0C0C"
  default_labels  = { managed_by = "terraform" }

  projects = {
    "prj-p-payments-api" = {
      folder_id = "folders/333333333333"
      labels    = { environment = "prod", owner = "payments", cost_centre = "cc-1234" }
      services  = ["container.googleapis.com"]
      iam       = { "roles/viewer" = ["group:payments-devs@example.com"] }
      budget    = { amount = 2500, currency_code = "GBP" }
      shared_vpc = {
        host_project  = "prj-p-net-host-1a2b"
        subnets       = ["projects/prj-p-net-host-1a2b/regions/europe-west2/subnetworks/sb-prod-ew2-app"]
        network_users = ["group:payments-devs@example.com"]
      }
    }
    "prj-n-payments-api" = {
      folder_id = "folders/444444444444"
      labels    = { environment = "nonprod", owner = "payments", cost_centre = "cc-1234" }
    }
  }
}

run "projects_are_created_with_labels" {
  command = plan

  assert {
    condition     = google_project.this["prj-p-payments-api"].labels["managed_by"] == "terraform" && google_project.this["prj-p-payments-api"].labels["owner"] == "payments"
    error_message = "Default and per-project labels should be merged."
  }

  assert {
    condition     = !google_project.this["prj-n-payments-api"].auto_create_network
    error_message = "Projects must not get a default network."
  }

  assert {
    condition     = google_project.this["prj-p-payments-api"].deletion_policy == "PREVENT"
    error_message = "Projects should be deletion-protected by default."
  }

  assert {
    condition     = contains(keys(google_project_service.this), "prj-p-payments-api|compute.googleapis.com")
    error_message = "Shared VPC service projects must have the Compute API enabled automatically."
  }
}

run "shared_vpc_and_gke_grants" {
  command = apply

  assert {
    condition     = google_compute_shared_vpc_service_project.this["prj-p-payments-api"].host_project == "prj-p-net-host-1a2b"
    error_message = "Service project should be attached to the host."
  }

  assert {
    condition     = length(google_compute_subnetwork_iam_member.network_user) == 3
    error_message = "Expected networkUser for the group, the Google APIs agent and the GKE agent."
  }

  assert {
    condition     = google_project_iam_member.gke_host_agent["prj-p-payments-api"].member == "serviceAccount:service-100000000042@container-engine-robot.iam.gserviceaccount.com"
    error_message = "GKE service agent should get hostServiceAgentUser on the host project."
  }

  assert {
    condition     = google_compute_subnetwork_iam_member.network_user["prj-p-payments-api|projects/prj-p-net-host-1a2b/regions/europe-west2/subnetworks/sb-prod-ew2-app|group:payments-devs@example.com"].region == "europe-west2"
    error_message = "Subnet ID should be parsed into project, region and name."
  }
}

run "budget_has_actual_and_forecast_alerts" {
  command = apply

  assert {
    condition     = length(google_billing_budget.this) == 1
    error_message = "Only projects with a budget block get a budget."
  }

  assert {
    condition     = length(google_billing_budget.this["prj-p-payments-api"].threshold_rules) == 4
    error_message = "Expected three actual-spend thresholds and one forecast threshold."
  }

  assert {
    condition     = google_billing_budget.this["prj-p-payments-api"].budget_filter[0].projects == toset(["projects/100000000042"])
    error_message = "Budget must be scoped to the project number."
  }

  assert {
    condition     = google_billing_budget.this["prj-p-payments-api"].amount[0].specified_amount[0].units == "2500"
    error_message = "Budget amount not rendered."
  }
}

run "rejects_missing_required_labels" {
  command = plan

  variables {
    projects = {
      "prj-s-scratch-01" = {
        folder_id = "folders/555555555555"
        labels    = { environment = "sandbox" }
      }
    }
  }

  expect_failures = [google_project.this]
}

run "rejects_user_principals" {
  command = plan

  variables {
    projects = {
      "prj-s-scratch-01" = {
        folder_id = "folders/555555555555"
        labels    = { environment = "sandbox", owner = "me", cost_centre = "cc-1" }
        iam       = { "roles/viewer" = ["user:someone@example.com"] }
      }
    }
  }

  expect_failures = [var.projects]
}

run "rejects_uppercase_labels" {
  command = plan

  variables {
    projects = {
      "prj-s-scratch-01" = {
        folder_id = "folders/555555555555"
        labels    = { Environment = "Sandbox" }
      }
    }
  }

  expect_failures = [var.projects]
}
