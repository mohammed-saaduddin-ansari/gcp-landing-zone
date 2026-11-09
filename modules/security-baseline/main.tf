locals {
  scc_enabled = var.scc_notifications.enabled
}

# --- Security Command Center findings to Pub/Sub ---------------------------------------------------

resource "google_pubsub_topic" "scc" {
  count = local.scc_enabled ? 1 : 0

  project                    = var.project_id
  name                       = var.scc_notifications.topic_name
  labels                     = var.labels
  message_retention_duration = var.scc_notifications.message_retention
  kms_key_name               = var.scc_notifications.kms_key_name
}

# The organisation's SCC notification service agent publishes to the topic. Granting it explicitly means
# the module does not rely on the caller being allowed to set topic IAM implicitly.
resource "google_pubsub_topic_iam_member" "scc_publisher" {
  count = local.scc_enabled ? 1 : 0

  project = var.project_id
  topic   = google_pubsub_topic.scc[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-org-${var.org_id}@gcp-sa-scc-notification.iam.gserviceaccount.com"
}

resource "google_scc_v2_organization_notification_config" "this" {
  count = local.scc_enabled ? 1 : 0

  organization = var.org_id
  config_id    = var.scc_notifications.config_id
  location     = "global"
  description  = "Active, unmuted findings forwarded for alerting."
  pubsub_topic = google_pubsub_topic.scc[0].id

  streaming_config {
    filter = var.scc_notifications.filter
  }

  depends_on = [google_pubsub_topic_iam_member.scc_publisher]
}

# --- Essential Contacts -----------------------------------------------------------------------------

resource "google_essential_contacts_contact" "this" {
  for_each = var.essential_contacts

  parent                              = "organizations/${var.org_id}"
  email                               = each.key
  language_tag                        = var.essential_contacts_language
  notification_category_subscriptions = each.value
}
