output "host_projects" {
  description = "Host project ID per environment. Pass to 3-projects."
  value       = { for env, cfg in var.environments : env => module.host_projects.projects[cfg.host_project_id].project_id }
}

output "networks" {
  description = "Shared VPC network ID per environment."
  value       = { for env, m in module.shared_vpc : env => m.network_id }
}

output "subnets" {
  description = "Subnets per environment, keyed by subnet name."
  value       = { for env, m in module.shared_vpc : env => m.subnets }
}

output "psc_endpoints" {
  description = "PSC endpoint IP per environment."
  value       = { for env, m in module.psc : env => m.endpoint_ip }
}
