module "host_projects" {
  source = "../../modules/project-factory"

  billing_account = var.billing_account

  projects = {
    for env, cfg in var.environments : cfg.host_project_id => {
      name      = "${env} network host"
      folder_id = var.folder_ids[env]
      labels = {
        environment = env
        owner       = "platform-network"
        cost_centre = "platform"
      }
      services = ["compute.googleapis.com", "dns.googleapis.com"]
      iam      = { "roles/compute.networkAdmin" = ["group:${var.network_admins_group}"] }
    }
  }
}

module "shared_vpc" {
  source   = "../../modules/shared-vpc"
  for_each = var.environments

  project_id   = module.host_projects.projects[each.value.host_project_id].project_id
  network_name = each.value.network_name

  subnets = {
    for name, s in each.value.subnets : name => {
      region           = s.region
      ip_cidr_range    = s.ip_cidr_range
      secondary_ranges = s.secondary_ranges
      flow_logs        = { flow_sampling = s.flow_sampling }
    }
  }
}

module "psc" {
  source   = "../../modules/private-service-connect"
  for_each = var.environments

  project_id    = module.host_projects.projects[each.value.host_project_id].project_id
  network_id    = module.shared_vpc[each.key].network_id
  endpoint_name = "psc${replace(each.key, "-", "")}"
  endpoint_ip   = each.value.psc_endpoint_ip
}
