mock_provider "google" {
  mock_resource "google_pubsub_topic" {
    defaults = {
      id = "projects/prj-c-security/topics/scc-findings"
    }
  }
}

variables {
  org_id     = "123456789012"
  project_id = "prj-c-security"
  essential_contacts = {
    "gcp-security@example.com" = ["SECURITY", "TECHNICAL_INCIDENTS"]
    "gcp-billing@example.com"  = ["BILLING"]
  }
}

run "findings_are_streamed" {
  command = apply

  assert {
    condition     = google_scc_v2_organization_notification_config.this[0].pubsub_topic == "projects/prj-c-security/topics/scc-findings"
    error_message = "Notification config should publish to the findings topic."
  }

  assert {
    condition     = strcontains(google_scc_v2_organization_notification_config.this[0].streaming_config[0].filter, "CRITICAL")
    error_message = "Default filter should include critical findings."
  }

  assert {
    condition     = google_pubsub_topic_iam_member.scc_publisher[0].member == "serviceAccount:service-org-123456789012@gcp-sa-scc-notification.iam.gserviceaccount.com"
    error_message = "SCC service agent should be allowed to publish."
  }

  assert {
    condition     = google_essential_contacts_contact.this["gcp-security@example.com"].parent == "organizations/123456789012"
    error_message = "Essential contacts should be set at organisation level."
  }
}

run "notifications_disabled" {
  command = plan

  variables {
    scc_notifications = { enabled = false }
  }

  assert {
    condition     = length(google_pubsub_topic.scc) == 0 && length(google_scc_v2_organization_notification_config.this) == 0
    error_message = "Nothing SCC-related should be created when disabled."
  }
}

run "rejects_unknown_contact_category" {
  command = plan

  variables {
    essential_contacts = { "x@example.com" = ["EVERYTHING"] }
  }

  expect_failures = [var.essential_contacts]
}
