locals {
  sink_exclusions = { for name, s in var.sinks : name => s.exclusions }
}

# --- Log buckets ----------------------------------------------------------------------------------

resource "google_logging_project_bucket_config" "this" {
  for_each = var.log_buckets

  project          = var.project_id
  bucket_id        = each.key
  location         = each.value.location
  retention_days   = each.value.retention_days
  locked           = each.value.locked
  enable_analytics = each.value.enable_analytics
  description      = each.value.description
}

# --- Aggregated organisation sinks -------------------------------------------------------------------

resource "google_logging_organization_sink" "this" {
  for_each = var.sinks

  name             = each.key
  org_id           = var.org_id
  description      = each.value.description
  filter           = trimspace(each.value.filter)
  include_children = each.value.include_children
  # try() lets the precondition below report a missing bucket key with a clear message.
  destination = "logging.googleapis.com/${try(google_logging_project_bucket_config.this[each.value.log_bucket].id, "undefined")}"

  dynamic "exclusions" {
    for_each = local.sink_exclusions[each.key]
    content {
      name   = exclusions.key
      filter = exclusions.value
    }
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.log_buckets), each.value.log_bucket)
      error_message = "Sink ${each.key} targets log bucket ${each.value.log_bucket}, which is not defined in log_buckets."
    }
  }
}

# Each sink has its own writer identity, which needs permission to write to the destination.
resource "google_project_iam_member" "sink_writer" {
  for_each = var.sinks

  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.this[each.key].writer_identity

  condition {
    title       = "only-${each.value.log_bucket}"
    description = "Restrict the sink's writer identity to its own log bucket."
    expression  = "resource.name.endsWith('buckets/${each.value.log_bucket}')"
  }
}

# --- Optional Cloud Storage archive ------------------------------------------------------------------

resource "google_storage_bucket" "archive" {
  count = var.archive == null ? 0 : 1

  name          = var.archive.bucket_name
  project       = var.project_id
  location      = var.archive.location
  storage_class = var.archive.storage_class
  labels        = var.labels

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  # Object versioning is incompatible with a retention policy; the retention policy is the
  # protection against deletion and overwrite here.
  retention_policy {
    retention_period = tostring(var.archive.retention_days * 86400)
    is_locked        = var.archive.lock_retention
  }

  lifecycle_rule {
    condition {
      age = var.archive.retention_days
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = var.archive.kms_key_name == null ? [] : [var.archive.kms_key_name]
    content {
      default_kms_key_name = encryption.value
    }
  }
}

resource "google_logging_organization_sink" "archive" {
  count = var.archive == null ? 0 : 1

  name             = "archive-to-gcs"
  org_id           = var.org_id
  description      = "Long-term archive of logs to Cloud Storage."
  filter           = trimspace(var.archive.filter)
  include_children = true
  destination      = "storage.googleapis.com/${google_storage_bucket.archive[0].name}"
}

resource "google_storage_bucket_iam_member" "archive_writer" {
  count = var.archive == null ? 0 : 1

  bucket = google_storage_bucket.archive[0].name
  role   = "roles/storage.objectCreator"
  member = google_logging_organization_sink.archive[0].writer_identity
}

# --- Data Access audit logs --------------------------------------------------------------------------

resource "google_organization_iam_audit_config" "data_access" {
  for_each = toset(var.data_access_audit_services)

  org_id  = var.org_id
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
