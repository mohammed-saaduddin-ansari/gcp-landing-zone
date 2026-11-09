locals {
  # Each YAML file under projects/ describes one project. See projects/README.md for the schema.
  project_files = fileset("${path.module}/${var.projects_dir}", "*.yaml")

  raw = {
    for f in local.project_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/${var.projects_dir}/${f}"))
  }

  # Translate the human-friendly YAML into the project-factory input: folder keys become folder IDs, and
  # "region/subnet" references become subnet IDs in the environment's host project.
  projects = {
    for key, p in local.raw : p.project_id => {
      name = try(p.name, null)
      # Unknown keys fall back to placeholders; the preconditions on output "projects" then fail the plan
      # with a message that names the problem instead of an index error.
      folder_id = lookup(var.folder_ids, p.folder, "folders/0")
      labels    = try(p.labels, {})
      services  = try(p.services, [])
      iam       = try(p.iam, {})
      budget = try(p.budget, null) == null ? null : {
        amount             = p.budget.amount
        currency_code      = try(p.budget.currency_code, var.budget_currency)
        alert_thresholds   = try(p.budget.alert_thresholds, [0.5, 0.9, 1.0])
        forecast_threshold = try(p.budget.forecast_threshold, 1.0)
        pubsub_topic       = try(p.budget.pubsub_topic, null)
      }
      shared_vpc = try(p.shared_vpc, null) == null ? null : {
        host_project = lookup(var.host_projects, p.folder, "missing-host-project")
        subnets = [
          for s in try(p.shared_vpc.subnets, []) :
          "projects/${lookup(var.host_projects, p.folder, "missing-host-project")}/regions/${split("/", s)[0]}/subnetworks/${split("/", s)[1]}"
        ]
        network_users = try(p.shared_vpc.network_users, [])
      }
    }
  }

  vpc_sc_projects = [for key, p in local.raw : p.project_id if try(p.vpc_sc, false)]
}

module "projects" {
  source = "../../modules/project-factory"

  billing_account = var.billing_account
  projects        = local.projects
}

module "vpc_sc" {
  source = "../../modules/vpc-service-controls"
  count  = var.vpc_sc.enabled ? 1 : 0

  access_policy_id = var.vpc_sc.access_policy_id
  perimeter_name   = var.vpc_sc.perimeter_name
  mode             = var.vpc_sc.mode
  resources = concat(
    [for id in local.vpc_sc_projects : "projects/${module.projects.project_numbers[id]}"],
    var.vpc_sc.extra_resources,
  )
}
