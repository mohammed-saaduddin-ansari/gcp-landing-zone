output "policy_id" {
  description = "ID of the hierarchical firewall policy (`locations/global/firewallPolicies/<numeric id>`)."
  value       = google_compute_firewall_policy.this.id
}

output "policy_name" {
  description = "Numeric name of the policy, as used by rules."
  value       = google_compute_firewall_policy.this.name
}

output "rule_priorities" {
  description = "Rule priorities, keyed by rule name."
  value       = { for k, r in google_compute_firewall_policy_rule.this : k => r.priority }
}
