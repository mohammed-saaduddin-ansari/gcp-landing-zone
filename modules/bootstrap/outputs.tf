output "seed_project_id" {
  description = "Seed project ID."
  value       = google_project.seed.project_id
}

output "seed_project_number" {
  description = "Seed project number."
  value       = google_project.seed.number
}

output "state_bucket" {
  description = "Name of the Terraform state bucket."
  value       = google_storage_bucket.state.name
}

output "service_account_emails" {
  description = "CI service account emails, keyed by stage."
  value       = { for k, sa in google_service_account.ci : k => sa.email }
}

output "workload_identity_provider" {
  description = "Full resource name of the WIF provider; pass it to google-github-actions/auth as `workload_identity_provider`."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "backend_configs" {
  description = "Suggested GCS backend settings per stage, for `terraform init -backend-config=...`."
  value = {
    for k, cfg in var.service_accounts : k => {
      bucket = google_storage_bucket.state.name
      prefix = coalesce(cfg.state_prefix, k)
    }
  }
}
