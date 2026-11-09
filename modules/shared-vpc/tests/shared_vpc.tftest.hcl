mock_provider "google" {}

variables {
  project_id   = "prj-p-net-host-1a2b"
  network_name = "vpc-prod"
  subnets = {
    "sb-prod-ew2-app" = {
      region           = "europe-west2"
      ip_cidr_range    = "10.10.0.0/20"
      secondary_ranges = { pods = "100.64.0.0/14", services = "100.68.0.0/20" }
    }
    "sb-prod-ew1-app" = {
      region        = "europe-west1"
      ip_cidr_range = "10.10.16.0/20"
      flow_logs     = { flow_sampling = 1.0 }
    }
    "sb-prod-ew2-data" = {
      region        = "europe-west2"
      ip_cidr_range = "10.10.32.0/20"
      flow_logs     = { enabled = false }
    }
  }
}

run "network_and_subnets" {
  command = plan

  assert {
    condition     = !google_compute_network.this.auto_create_subnetworks && google_compute_network.this.routing_mode == "GLOBAL"
    error_message = "Custom-mode network with global routing expected."
  }

  assert {
    condition     = alltrue([for s in google_compute_subnetwork.this : s.private_ip_google_access])
    error_message = "Private Google Access should be on for every subnet by default."
  }

  assert {
    condition     = length(google_compute_subnetwork.this["sb-prod-ew2-app"].secondary_ip_range) == 2
    error_message = "Secondary ranges for GKE should be created."
  }

  assert {
    condition     = google_compute_subnetwork.this["sb-prod-ew2-app"].log_config[0].flow_sampling == 0.5
    error_message = "Default flow log sampling should be 0.5."
  }

  assert {
    condition     = google_compute_subnetwork.this["sb-prod-ew1-app"].log_config[0].flow_sampling == 1.0
    error_message = "Per-subnet flow sampling override not applied."
  }

  assert {
    condition     = length(google_compute_subnetwork.this["sb-prod-ew2-data"].log_config) == 0
    error_message = "Flow logs should be off when disabled."
  }
}

run "one_nat_per_region" {
  command = plan

  assert {
    condition     = length(google_compute_router_nat.this) == 2
    error_message = "Expected one NAT gateway per region with subnets (two regions)."
  }

  assert {
    condition     = google_compute_router_nat.this["europe-west2"].enable_dynamic_port_allocation && !google_compute_router_nat.this["europe-west2"].enable_endpoint_independent_mapping
    error_message = "NAT should use dynamic port allocation."
  }

  assert {
    condition     = google_dns_policy.this[0].enable_logging
    error_message = "DNS query logging should be on by default."
  }
}

run "nat_disabled" {
  command = plan

  variables {
    nat = { enabled = false }
  }

  assert {
    condition     = length(google_compute_router.this) == 0 && length(google_compute_router_nat.this) == 0
    error_message = "No routers or NAT when disabled."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    subnets = { bad = { region = "europe-west2", ip_cidr_range = "10.0.0.0/33" } }
  }

  expect_failures = [var.subnets]
}
