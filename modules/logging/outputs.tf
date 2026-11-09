output "log_bucket_ids" {
  description = "Resource names of the log buckets, keyed by bucket ID."
  value       = { for k, b in google_logging_project_bucket_config.this : k => b.id }
}

output "sink_writer_identities" {
  description = "Writer identities of the aggregated sinks, keyed by sink name (including `archive-to-gcs` when enabled)."
  value = merge(
    { for k, s in google_logging_organization_sink.this : k => s.writer_identity },
    { for s in google_logging_organization_sink.archive : s.name => s.writer_identity },
  )
}

output "archive_bucket" {
  description = "Name of the archive bucket, or null when the archive is disabled."
  value       = one(google_storage_bucket.archive[*].name)
}
