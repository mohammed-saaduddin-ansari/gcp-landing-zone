locals {
  projects = {
    for id, p in var.projects : id => merge(p, {
      labels = merge(var.default_labels, p.labels)
      # Shared VPC service projects need the Compute API before they can be attached.
      services = distinct(concat(
        p.services,
        p.shared_vpc != null ? ["compute.googleapis.com"] : [],
      ))
    })
  }

  services = merge([
    for id, p in local.projects : { for s in p.services : "${id}|${s}" => { project = id, service = s } }
  ]...)

  iam = merge(flatten([
    for id, p in local.projects : [
      for role, members in p.iam : { for m in members : "${id}|${role}|${m}" => { project = id, role = role, member = m } }
    ]
  ])...)

  shared_vpc_projects = { for id, p in local.projects : id => p if p.shared_vpc != null }

  uses_gke = { for id, p in local.shared_vpc_projects : id => contains(p.services, "container.googleapis.com") }

  # Members that need compute.networkUser on each shared subnet: the requested groups, the Google APIs
  # service agent (used by managed instance groups) and, for GKE projects, the GKE service agent.
  # Keys use static labels ("cloudservices", "gke") because project numbers are unknown until apply.
  subnet_grants = merge(flatten([
    for id, p in local.shared_vpc_projects : [
      for subnet in p.shared_vpc.subnets : merge(
        { for m in p.shared_vpc.network_users : "${id}|${subnet}|${m}" => { project = id, subnet = subnet, agent = null, member = m } },
        { "${id}|${subnet}|cloudservices" = { project = id, subnet = subnet, agent = "cloudservices", member = null } },
        local.uses_gke[id] ? { "${id}|${subnet}|gke" = { project = id, subnet = subnet, agent = "gke", member = null } } : {},
      )
    ]
  ])...)

  budgets = { for id, p in local.projects : id => p if p.budget != null }
}

resource "google_project" "this" {
  for_each = local.projects

  project_id          = each.key
  name                = coalesce(each.value.name, each.key)
  folder_id           = each.value.folder_id
  billing_account     = coalesce(each.value.billing_account, var.billing_account)
  labels              = each.value.labels
  auto_create_network = false
  deletion_policy     = each.value.deletion_policy

  lifecycle {
    precondition {
      condition     = length(setsubtract(var.required_labels, keys(each.value.labels))) == 0
      error_message = "Project ${each.key} is missing required labels: ${join(", ", setsubtract(var.required_labels, keys(each.value.labels)))}."
    }
  }
}

resource "google_project_service" "this" {
  for_each = local.services

  project            = google_project.this[each.value.project].project_id
  service            = each.value.service
  disable_on_destroy = false
}

resource "google_project_iam_member" "this" {
  for_each = local.iam

  project = google_project.this[each.value.project].project_id
  role    = each.value.role
  member  = each.value.member
}

# --- Shared VPC attachment ----------------------------------------------------------------------

resource "google_compute_shared_vpc_service_project" "this" {
  for_each = local.shared_vpc_projects

  host_project    = each.value.shared_vpc.host_project
  service_project = google_project.this[each.key].project_id

  depends_on = [google_project_service.this]
}

resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = local.subnet_grants

  project    = regex("^projects/([^/]+)/", each.value.subnet)[0]
  region     = regex("/regions/([^/]+)/", each.value.subnet)[0]
  subnetwork = regex("/subnetworks/([^/]+)$", each.value.subnet)[0]
  role       = "roles/compute.networkUser"
  member = (
    each.value.agent == "cloudservices" ? "serviceAccount:${google_project.this[each.value.project].number}@cloudservices.gserviceaccount.com" :
    each.value.agent == "gke" ? "serviceAccount:service-${google_project.this[each.value.project].number}@container-engine-robot.iam.gserviceaccount.com" :
    each.value.member
  )

  depends_on = [google_compute_shared_vpc_service_project.this]
}

# GKE in a service project also needs the Host Service Agent User role on the host project.
resource "google_project_iam_member" "gke_host_agent" {
  for_each = { for id, gke in local.uses_gke : id => local.shared_vpc_projects[id] if gke }

  project = each.value.shared_vpc.host_project
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:service-${google_project.this[each.key].number}@container-engine-robot.iam.gserviceaccount.com"

  depends_on = [google_project_service.this]
}

# --- Budgets ------------------------------------------------------------------------------------

resource "google_billing_budget" "this" {
  for_each = local.budgets

  billing_account = coalesce(each.value.billing_account, var.billing_account)
  display_name    = "${each.key} monthly budget"

  budget_filter {
    projects               = ["projects/${google_project.this[each.key].number}"]
    calendar_period        = "MONTH"
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      units         = tostring(floor(each.value.budget.amount))
      currency_code = each.value.budget.currency_code
    }
  }

  dynamic "threshold_rules" {
    for_each = each.value.budget.alert_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  # Warn before the money is spent, not only after.
  threshold_rules {
    threshold_percent = each.value.budget.forecast_threshold
    spend_basis       = "FORECASTED_SPEND"
  }

  dynamic "all_updates_rule" {
    for_each = each.value.budget.pubsub_topic != null || length(each.value.budget.notification_channels) > 0 ? [1] : []
    content {
      pubsub_topic                     = each.value.budget.pubsub_topic
      monitoring_notification_channels = each.value.budget.notification_channels
      # Billing admins keep their default email alerts alongside the extra channels.
      disable_default_iam_recipients = false
    }
  }
}
