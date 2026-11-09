output "projects" {
  description = "Projects created from the YAML definitions."
  value       = module.projects.projects
}

output "vpc_sc_perimeter" {
  description = "Service perimeter name and mode, or null when VPC Service Controls are disabled."
  value       = var.vpc_sc.enabled ? { name = module.vpc_sc[0].perimeter_name, mode = module.vpc_sc[0].mode } : null
}
