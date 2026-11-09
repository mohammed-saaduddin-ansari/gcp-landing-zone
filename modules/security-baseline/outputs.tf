output "scc_topic_id" {
  description = "ID of the Pub/Sub topic that receives SCC findings, or null when disabled."
  value       = one(google_pubsub_topic.scc[*].id)
}

output "scc_notification_config" {
  description = "Resource name of the SCC notification config, or null when disabled."
  value       = one(google_scc_v2_organization_notification_config.this[*].name)
}

output "essential_contacts" {
  description = "Essential Contacts created, keyed by email."
  value       = { for k, c in google_essential_contacts_contact.this : k => c.notification_category_subscriptions }
}
