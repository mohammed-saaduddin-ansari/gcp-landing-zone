output "projects" {
  description = "Created projects keyed by project ID, with number, folder and labels."
  value = {
    for id, p in google_project.this : id => {
      project_id = p.project_id
      number     = p.number
      folder_id  = p.folder_id
      labels     = p.labels
    }
  }
}

output "project_numbers" {
  description = "Project numbers keyed by project ID (useful for VPC Service Controls perimeters)."
  value       = { for id, p in google_project.this : id => p.number }
}

output "budget_ids" {
  description = "Budget resource IDs keyed by project ID."
  value       = { for id, b in google_billing_budget.this : id => b.id }
}
