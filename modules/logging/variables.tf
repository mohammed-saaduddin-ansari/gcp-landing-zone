variable "org_id" {
  description = "Numeric organisation ID whose logs are aggregated."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be numeric."
  }
}

variable "project_id" {
  description = "Central logging project that owns the log buckets and the optional archive bucket."
  type        = string
}

variable "log_buckets" {
  description = <<-EOT
    Cloud Logging buckets to create in the logging project, keyed by bucket ID.
    `locked = true` makes the retention period permanent and cannot be undone; turn it on only once the
    retention figure has been agreed with whoever owns compliance. `enable_analytics` upgrades the bucket to
    Log Analytics, which also cannot be reversed.
  EOT
  type = map(object({
    location         = string
    retention_days   = number
    locked           = optional(bool, false)
    enable_analytics = optional(bool, false)
    description      = optional(string)
  }))
  default = {
    audit = {
      location       = "global"
      retention_days = 400
      description    = "Organisation-wide audit logs."
    }
  }

  validation {
    condition     = alltrue([for b in values(var.log_buckets) : b.retention_days >= 1 && b.retention_days <= 3650])
    error_message = "Cloud Logging bucket retention must be between 1 and 3650 days."
  }
}

variable "sinks" {
  description = <<-EOT
    Organisation-level aggregated sinks, keyed by sink name. `log_bucket` is a key of `log_buckets`.
    `exclusions` maps an exclusion name to a filter that is dropped from this sink only.
  EOT
  type = map(object({
    filter           = string
    log_bucket       = string
    description      = optional(string)
    include_children = optional(bool, true)
    exclusions       = optional(map(string), {})
  }))
  default = {
    audit = {
      log_bucket  = "audit"
      description = "Admin Activity, System Event, Policy Denied, Data Access and Access Transparency logs."
      filter      = <<-EOT
        log_id("cloudaudit.googleapis.com/activity") OR
        log_id("cloudaudit.googleapis.com/system_event") OR
        log_id("cloudaudit.googleapis.com/policy") OR
        log_id("cloudaudit.googleapis.com/data_access") OR
        log_id("cloudaudit.googleapis.com/access_transparency")
      EOT
    }
  }
}

variable "archive" {
  description = <<-EOT
    Optional long-term archive: an aggregated sink that writes matching logs to a Cloud Storage bucket with a
    retention policy. Use it when retention must exceed what you want to pay for in Cloud Logging, or when
    auditors want write-once storage. `lock_retention = true` is irreversible.
  EOT
  type = object({
    bucket_name    = string
    location       = string
    retention_days = number
    lock_retention = optional(bool, false)
    storage_class  = optional(string, "ARCHIVE")
    filter         = string
    kms_key_name   = optional(string)
  })
  default = null

  validation {
    condition     = var.archive == null || try(var.archive.retention_days >= 1, false)
    error_message = "archive.retention_days must be at least 1."
  }

  validation {
    condition     = var.archive == null || contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], try(var.archive.storage_class, ""))
    error_message = "archive.storage_class must be STANDARD, NEARLINE, COLDLINE or ARCHIVE."
  }
}

variable "data_access_audit_services" {
  description = <<-EOT
    Services for which Data Access audit logs (DATA_READ, DATA_WRITE, ADMIN_READ) are switched on at organisation
    level, for example `["allServices"]` or `["storage.googleapis.com"]`. These logs can be very high volume and
    are billed as ingestion, so the default is none.
  EOT
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels applied to the archive bucket."
  type        = map(string)
  default     = {}
}
