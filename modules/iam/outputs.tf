output "granted_roles" {
  description = "Distinct roles granted by this module, across all scopes."
  value       = sort(distinct(local.all_roles))
}

output "binding_count" {
  description = "Number of individual role/member grants managed, by scope."
  value = {
    organization = length(google_organization_iam_member.this)
    folder       = length(google_folder_iam_member.this)
    project      = length(google_project_iam_member.this)
  }
}
