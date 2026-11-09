mock_provider "google" {
  mock_resource "google_logging_project_bucket_config" {
    defaults = {
      id = "projects/prj-c-logging/locations/global/buckets/audit"
    }
  }

  mock_resource "google_logging_organization_sink" {
    defaults = {
      writer_identity = "serviceAccount:o123456789012-000000@gcp-sa-logging.iam.gserviceaccount.com"
    }
  }
}

variables {
  org_id     = "123456789012"
  project_id = "prj-c-logging"
}

run "default_audit_sink" {
  command = apply

  assert {
    condition     = google_logging_organization_sink.this["audit"].include_children
    error_message = "The aggregated sink must include child folders and projects."
  }

  assert {
    condition     = google_logging_organization_sink.this["audit"].destination == "logging.googleapis.com/projects/prj-c-logging/locations/global/buckets/audit"
    error_message = "Audit sink should write to the central audit log bucket."
  }

  assert {
    condition     = strcontains(google_logging_organization_sink.this["audit"].filter, "cloudaudit.googleapis.com/activity")
    error_message = "Audit sink filter should capture Admin Activity logs."
  }

  assert {
    condition     = google_project_iam_member.sink_writer["audit"].role == "roles/logging.bucketWriter"
    error_message = "Sink writer identity must be granted bucketWriter."
  }

  assert {
    condition     = google_logging_project_bucket_config.this["audit"].retention_days == 400
    error_message = "Default audit retention should be 400 days."
  }

  assert {
    condition     = length(google_storage_bucket.archive) == 0 && output.archive_bucket == null
    error_message = "Archive must be off by default."
  }
}

run "archive_enabled" {
  command = apply

  variables {
    archive = {
      bucket_name    = "example-log-archive"
      location       = "EU"
      retention_days = 2555
      filter         = "log_id(\"cloudaudit.googleapis.com/activity\")"
    }
  }

  assert {
    condition     = google_storage_bucket.archive[0].retention_policy[0].retention_period == "220752000"
    error_message = "Retention period should be retention_days in seconds."
  }

  assert {
    condition     = google_storage_bucket.archive[0].storage_class == "ARCHIVE"
    error_message = "Archive bucket should default to the ARCHIVE storage class."
  }

  assert {
    condition     = google_logging_organization_sink.archive[0].destination == "storage.googleapis.com/example-log-archive"
    error_message = "Archive sink should write to the archive bucket."
  }
}

run "data_access_logs_opt_in" {
  command = plan

  variables {
    data_access_audit_services = ["storage.googleapis.com"]
  }

  assert {
    condition     = length(google_organization_iam_audit_config.data_access) == 1
    error_message = "Data Access logs should be enabled only for the listed services."
  }
}

run "rejects_sink_to_unknown_bucket" {
  command = plan

  variables {
    sinks = {
      network = {
        filter     = "log_id(\"compute.googleapis.com/vpc_flows\")"
        log_bucket = "network"
      }
    }
  }

  expect_failures = [google_logging_organization_sink.this]
}

run "rejects_excessive_retention" {
  command = plan

  variables {
    log_buckets = { audit = { location = "global", retention_days = 4000 } }
  }

  expect_failures = [var.log_buckets]
}
