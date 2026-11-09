output "network_id" {
  description = "ID of the Shared VPC network (`projects/<p>/global/networks/<name>`)."
  value       = google_compute_network.this.id
}

output "network_self_link" {
  description = "Self link of the Shared VPC network."
  value       = google_compute_network.this.self_link
}

output "subnets" {
  description = "Subnets keyed by name, with the attributes service projects need."
  value = {
    for k, s in google_compute_subnetwork.this : k => {
      id            = s.id
      self_link     = s.self_link
      region        = s.region
      ip_cidr_range = s.ip_cidr_range
    }
  }
}

output "nat_regions" {
  description = "Regions with a Cloud NAT gateway."
  value       = sort(keys(google_compute_router_nat.this))
}
