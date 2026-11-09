mock_provider "google" {}

variables {
  project_id    = "prj-p-net-host-1a2b"
  network_id    = "projects/prj-p-net-host-1a2b/global/networks/vpc-prod"
  endpoint_name = "pscprod"
  endpoint_ip   = "10.255.255.254"
}

run "endpoint_and_dns" {
  command = plan

  assert {
    condition     = google_compute_global_address.psc.purpose == "PRIVATE_SERVICE_CONNECT" && google_compute_global_address.psc.address_type == "INTERNAL"
    error_message = "Endpoint address must be an internal PSC address."
  }

  assert {
    condition     = google_compute_global_forwarding_rule.psc.target == "all-apis"
    error_message = "Default bundle should be all-apis."
  }

  assert {
    condition     = google_dns_managed_zone.psc["googleapis.com."].name == "psc-googleapis-com"
    error_message = "Zone names should be derived from the domain."
  }

  assert {
    condition     = google_dns_record_set.wildcard["googleapis.com."].name == "*.googleapis.com." && google_dns_record_set.wildcard["googleapis.com."].rrdatas == tolist(["10.255.255.254"])
    error_message = "Wildcard record should point Google API hostnames at the endpoint."
  }

  assert {
    condition     = length(google_dns_managed_zone.psc) == 3
    error_message = "Expected zones for googleapis.com, gcr.io and pkg.dev."
  }
}

run "rejects_hyphenated_endpoint_name" {
  command = plan

  variables {
    endpoint_name = "psc-prod"
  }

  expect_failures = [var.endpoint_name]
}

run "rejects_unqualified_domain" {
  command = plan

  variables {
    dns_domains = ["googleapis.com"]
  }

  expect_failures = [var.dns_domains]
}
