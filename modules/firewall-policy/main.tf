resource "google_compute_firewall_policy" "this" {
  parent      = var.parent
  short_name  = var.short_name
  description = var.description
}

resource "google_compute_firewall_policy_rule" "this" {
  for_each = var.rules

  firewall_policy = google_compute_firewall_policy.this.name
  priority        = each.value.priority
  direction       = each.value.direction
  action          = each.value.action
  description     = coalesce(each.value.description, each.key)
  enable_logging  = each.value.enable_logging
  disabled        = each.value.disabled

  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null
  target_resources        = length(each.value.target_resources) > 0 ? each.value.target_resources : null

  match {
    src_ip_ranges  = length(each.value.src_ip_ranges) > 0 ? each.value.src_ip_ranges : null
    dest_ip_ranges = length(each.value.dest_ip_ranges) > 0 ? each.value.dest_ip_ranges : null

    dynamic "layer4_configs" {
      for_each = each.value.layer4
      content {
        ip_protocol = layer4_configs.value.protocol
        ports       = length(layer4_configs.value.ports) > 0 ? layer4_configs.value.ports : null
      }
    }
  }
}

resource "google_compute_firewall_policy_association" "this" {
  for_each = toset(var.attachment_targets)

  name              = "${var.short_name}-${replace(each.value, "/", "-")}"
  firewall_policy   = google_compute_firewall_policy.this.id
  attachment_target = each.value
}
