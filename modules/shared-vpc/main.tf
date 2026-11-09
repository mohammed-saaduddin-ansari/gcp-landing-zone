locals {
  regions = toset([for s in values(var.subnets) : s.region])
}

resource "google_compute_shared_vpc_host_project" "this" {
  project = var.project_id
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  description             = "Shared VPC for ${var.project_id}. Managed by Terraform."

  depends_on = [google_compute_shared_vpc_host_project.this]
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  project                  = var.project_id
  name                     = each.key
  network                  = google_compute_network.this.id
  region                   = each.value.region
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = each.value.private_google_access
  description              = each.value.description

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "log_config" {
    for_each = each.value.flow_logs.enabled ? [each.value.flow_logs] : []
    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.flow_sampling
      metadata             = log_config.value.metadata
    }
  }
}

# --- Egress: Cloud NAT per region (VMs have no external IPs; see the org policy baseline) -----------

resource "google_compute_router" "this" {
  for_each = var.nat.enabled ? local.regions : toset([])

  project = var.project_id
  name    = "${var.network_name}-${each.value}-cr"
  region  = each.value
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  for_each = google_compute_router.this

  project = var.project_id
  name    = "${var.network_name}-${each.key}-nat"
  router  = each.value.name
  region  = each.key

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # Dynamic port allocation scales ports per VM with demand; it requires endpoint-independent mapping off.
  enable_dynamic_port_allocation      = true
  enable_endpoint_independent_mapping = false
  min_ports_per_vm                    = var.nat.min_ports_per_vm
  max_ports_per_vm                    = var.nat.max_ports_per_vm

  log_config {
    enable = true
    filter = var.nat.log_filter
  }
}

# --- DNS server policy: query logging and optional inbound forwarding ------------------------------

resource "google_dns_policy" "this" {
  count = var.dns_logging || var.dns_inbound_forwarding ? 1 : 0

  project                   = var.project_id
  name                      = "${var.network_name}-dns-policy"
  enable_logging            = var.dns_logging
  enable_inbound_forwarding = var.dns_inbound_forwarding

  networks {
    network_url = google_compute_network.this.id
  }
}
