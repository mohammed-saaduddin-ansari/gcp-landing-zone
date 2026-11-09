output "endpoint_ip" {
  description = "IP address of the PSC endpoint."
  value       = google_compute_global_address.psc.address
}

output "forwarding_rule_id" {
  description = "ID of the PSC forwarding rule."
  value       = google_compute_global_forwarding_rule.psc.id
}

output "dns_zones" {
  description = "Private DNS zone names, keyed by domain."
  value       = { for k, z in google_dns_managed_zone.psc : k => z.name }
}
