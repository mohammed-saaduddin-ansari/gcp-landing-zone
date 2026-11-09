locals {
  # GitHub's OIDC issuer for Actions.
  github_issuer = "https://token.actions.githubusercontent.com"

  sa_org_roles = merge([
    for sa, cfg in var.service_accounts : {
      for role in cfg.org_roles : "${sa}|${role}" => { sa = sa, role = role }
    }
  ]...)

  sa_billing_roles = merge([
    for sa, cfg in var.service_accounts : {
      for role in cfg.billing_roles : "${sa}|${role}" => { sa = sa, role = role }
    }
  ]...)

  # Exact-subject bindings where configured, otherwise a repository-wide principal set.
  sa_wif_members = merge([
    for sa, cfg in var.service_accounts : (
      length(cfg.wif_subjects) > 0
      ? { for s in cfg.wif_subjects : "${sa}|${s}" => {
        sa     = sa
        member = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${s}"
      } }
      : { "${sa}|repository" = {
        sa     = sa
        member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${cfg.repository}"
      } }
    )
  ]...)
}

# --- Seed project -----------------------------------------------------------------------------

resource "google_project" "seed" {
  name            = var.project_id
  project_id      = var.project_id
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = var.labels

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "seed" {
  for_each = toset(var.activate_apis)

  project            = google_project.seed.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- Terraform state bucket ---------------------------------------------------------------------

resource "google_storage_bucket" "state" {
  name     = var.state_bucket_name
  project  = google_project.seed.project_id
  location = var.state_bucket_location
  labels   = var.labels

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  # Keep a bounded history of state versions for rollback.
  lifecycle_rule {
    condition {
      num_newer_versions = var.state_versions_to_keep
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = var.state_bucket_kms_key == null ? [] : [var.state_bucket_kms_key]
    content {
      default_kms_key_name = encryption.value
    }
  }

  depends_on = [google_project_service.seed]
}

# --- CI service accounts --------------------------------------------------------------------------

resource "google_service_account" "ci" {
  for_each = var.service_accounts

  project      = google_project.seed.project_id
  account_id   = "tf-${each.key}"
  display_name = each.value.display_name
  description  = "Terraform CI identity for the ${each.key} stage. Used only through workload identity federation; no keys."

  depends_on = [google_project_service.seed]
}

resource "google_organization_iam_member" "ci" {
  for_each = local.sa_org_roles

  org_id = var.org_id
  role   = each.value.role
  member = google_service_account.ci[each.value.sa].member
}

resource "google_billing_account_iam_member" "ci" {
  for_each = local.sa_billing_roles

  billing_account_id = var.billing_account
  role               = each.value.role
  member             = google_service_account.ci[each.value.sa].member
}

# Every stage reads and writes its own state; see docs/DECISIONS.md for per-prefix hardening.
resource "google_storage_bucket_iam_member" "ci_state" {
  for_each = var.service_accounts

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci[each.key].member
}

# Lets each CI identity use the seed project for API quota and billing (user_project_override).
resource "google_project_iam_member" "ci_service_usage" {
  for_each = var.service_accounts

  project = google_project.seed.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = google_service_account.ci[each.key].member
}

# --- Workload identity federation for GitHub Actions ----------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.seed.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "Short-lived credentials for CI. Replaces service account keys."

  depends_on = [google_project_service.seed]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.workflow_ref"     = "assertion.job_workflow_ref"
  }

  # Reject tokens from any repository not explicitly listed, before any IAM binding is consulted.
  attribute_condition = format(
    "assertion.repository in [%s]",
    join(", ", [for r in var.github_repositories : format("'%s'", r)]),
  )

  oidc {
    issuer_uri = local.github_issuer
  }
}

resource "google_service_account_iam_member" "wif" {
  for_each = local.sa_wif_members

  service_account_id = google_service_account.ci[each.value.sa].name
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value.member

  lifecycle {
    precondition {
      condition     = contains(var.github_repositories, var.service_accounts[each.value.sa].repository)
      error_message = "Service account ${each.value.sa} uses repository ${var.service_accounts[each.value.sa].repository}, which is not in github_repositories."
    }
  }
}
