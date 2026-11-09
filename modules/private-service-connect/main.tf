resource "google_compute_global_address" "psc" {
  project      = var.project_id
  name         = "${var.endpoint_name}-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = var.network_id
  address      = var.endpoint_ip
}

resource "google_compute_global_forwarding_rule" "psc" {
  project    = var.project_id
  name       = var.endpoint_name
  target     = var.api_bundle
  network    = var.network_id
  ip_address = google_compute_global_address.psc.id

  # Google API endpoints are not load balancers: the scheme must be empty.
  load_balancing_scheme = ""

  # DNS is managed explicitly below rather than through an automatic Service Directory zone.
  no_automate_dns_zone = true
}

resource "google_dns_managed_zone" "psc" {
  for_each = toset(var.dns_domains)

  project     = var.project_id
  name        = "psc-${trimsuffix(replace(each.value, ".", "-"), "-")}"
  dns_name    = each.value
  description = "Routes ${each.value} to the Private Service Connect endpoint ${var.endpoint_name}."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.network_id
    }
  }
}

resource "google_dns_record_set" "apex" {
  for_each = google_dns_managed_zone.psc

  project      = var.project_id
  managed_zone = each.value.name
  name         = each.value.dns_name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.endpoint_ip]
}

resource "google_dns_record_set" "wildcard" {
  for_each = google_dns_managed_zone.psc

  project      = var.project_id
  managed_zone = each.value.name
  name         = "*.${each.value.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [var.endpoint_ip]
}
