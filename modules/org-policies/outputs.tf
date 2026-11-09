output "boolean_policies" {
  description = "Boolean constraints managed at this parent, mapped to whether they are enforced."
  value       = { for k, p in google_org_policy_policy.boolean : k => p.spec[0].rules[0].enforce == "TRUE" }
}

output "list_policy_names" {
  description = "Resource names of the list constraint policies managed at this parent."
  value       = [for p in google_org_policy_policy.list : p.name]
}
