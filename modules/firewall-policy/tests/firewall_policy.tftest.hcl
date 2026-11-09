mock_provider "google" {}

variables {
  parent             = "organizations/123456789012"
  short_name         = "org-baseline"
  attachment_targets = ["organizations/123456789012"]

  rules = {
    allow-iap-ingress = {
      priority       = 1000
      direction      = "INGRESS"
      action         = "allow"
      src_ip_ranges  = ["35.235.240.0/20"]
      layer4         = [{ protocol = "tcp", ports = ["22", "3389"] }]
      enable_logging = true
    }
    deny-internet-admin-ingress = {
      priority       = 2000
      direction      = "INGRESS"
      action         = "deny"
      src_ip_ranges  = ["0.0.0.0/0"]
      layer4         = [{ protocol = "tcp", ports = ["22", "3389"] }]
      enable_logging = true
    }
    delegate-egress = {
      priority       = 9000
      direction      = "EGRESS"
      action         = "goto_next"
      dest_ip_ranges = ["0.0.0.0/0"]
    }
  }
}

run "rules_and_association" {
  command = plan

  assert {
    condition     = google_compute_firewall_policy_rule.this["allow-iap-ingress"].match[0].layer4_configs[0].ports == tolist(["22", "3389"])
    error_message = "IAP rule ports not rendered."
  }

  assert {
    condition     = google_compute_firewall_policy_rule.this["delegate-egress"].match[0].layer4_configs[0].ip_protocol == "all"
    error_message = "layer4 should default to all protocols."
  }

  assert {
    condition     = google_compute_firewall_policy_association.this["organizations/123456789012"].name == "org-baseline-organizations-123456789012"
    error_message = "Association name should be derived from the policy and target."
  }
}

run "rejects_duplicate_priorities" {
  command = plan

  variables {
    rules = {
      a = { priority = 100, direction = "INGRESS", action = "allow", src_ip_ranges = ["10.0.0.0/8"] }
      b = { priority = 100, direction = "INGRESS", action = "deny", src_ip_ranges = ["0.0.0.0/0"] }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_ingress_without_source" {
  command = plan

  variables {
    rules = {
      a = { priority = 100, direction = "INGRESS", action = "allow" }
    }
  }

  expect_failures = [var.rules]
}

run "rejects_unknown_action" {
  command = plan

  variables {
    rules = {
      a = { priority = 100, direction = "INGRESS", action = "permit", src_ip_ranges = ["10.0.0.0/8"] }
    }
  }

  expect_failures = [var.rules]
}
