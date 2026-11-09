output "folder_ids" {
  description = "Top-level folder IDs created by this stage. Pass them to 2-networking and 3-projects."
  value       = module.folders.folder_ids
}

output "logging_project_id" {
  description = "Central logging project."
  value       = module.common_projects.projects[var.project_ids.logging].project_id
}

output "security_project_id" {
  description = "Central security project."
  value       = module.common_projects.projects[var.project_ids.security].project_id
}

output "log_bucket_ids" {
  description = "Central log buckets."
  value       = module.logging.log_bucket_ids
}

output "org_firewall_policy" {
  description = "Organisation firewall policy ID."
  value       = module.org_firewall.policy_id
}
