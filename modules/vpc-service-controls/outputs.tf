output "access_policy_id" {
  description = "Numeric ID of the access policy in use."
  value       = local.policy_id
}

output "perimeter_name" {
  description = "Full resource name of the service perimeter."
  value       = google_access_context_manager_service_perimeter.this.name
}

output "mode" {
  description = "Whether the perimeter is in dry_run or enforced mode."
  value       = var.mode
}
