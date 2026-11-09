output "projects" {
  description = "Projects created from the YAML definitions."
  value       = module.projects.projects

  # Validation of the YAML files. File names and project IDs are independent, so duplicates and dangling
  # references are caught here and fail the plan.
  precondition {
    condition     = length(local.raw) == length(distinct([for p in values(local.raw) : p.project_id]))
    error_message = "Two YAML files declare the same project_id."
  }

  precondition {
    condition     = alltrue([for p in values(local.raw) : contains(keys(var.folder_ids), p.folder)])
    error_message = "A project references a folder that is not in folder_ids: ${join(", ", distinct([for p in values(local.raw) : p.folder if !contains(keys(var.folder_ids), p.folder)]))}."
  }

  precondition {
    condition     = alltrue([for p in values(local.raw) : contains(keys(var.host_projects), p.folder) if try(p.shared_vpc, null) != null])
    error_message = "A project asks for Shared VPC in an environment with no entry in host_projects."
  }

  precondition {
    condition     = alltrue(flatten([for p in values(local.raw) : [for s in try(p.shared_vpc.subnets, []) : length(split("/", s)) == 2]]))
    error_message = "Shared VPC subnets must be written as region/subnet-name."
  }
}

output "vpc_sc_perimeter" {
  description = "Service perimeter name and mode, or null when VPC Service Controls are disabled."
  value       = var.vpc_sc.enabled ? { name = module.vpc_sc[0].perimeter_name, mode = module.vpc_sc[0].mode } : null
}
