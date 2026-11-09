output "bootstrap_folder_id" {
  description = "Folder that holds the seed project."
  value       = module.bootstrap_folder.folder_ids["bootstrap"]
}

output "seed_project_id" {
  description = "Seed project ID; use it as `quota_project` in later stages."
  value       = module.bootstrap.seed_project_id
}

output "state_bucket" {
  description = "Terraform state bucket for all stages."
  value       = module.bootstrap.state_bucket
}

output "ci_service_accounts" {
  description = "CI service account per stage. Store each as a GitHub Actions variable."
  value       = module.bootstrap.service_account_emails
}

output "workload_identity_provider" {
  description = "WIF provider resource name. Store as the GitHub Actions variable GCP_WIF_PROVIDER."
  value       = module.bootstrap.workload_identity_provider
}

output "backend_configs" {
  description = "Backend bucket and prefix for each later stage."
  value       = module.bootstrap.backend_configs
}
