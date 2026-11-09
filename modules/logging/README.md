# logging

Centralises logs from the whole organisation into one logging project.

* **Organisation-level aggregated sinks** (`include_children = true`) route matching logs from every folder
  and project into **Cloud Logging buckets** in the logging project. Projects cannot opt out, and the
  copy survives a project being deleted.
* Each bucket has its own **retention**. The default audit bucket keeps 400 days; a separate bucket for
  noisy network logs can keep 30.
* Each sink's writer identity gets `roles/logging.bucketWriter` with an IAM condition limiting it to its
  own bucket.
* An optional **Cloud Storage archive** sink writes to a bucket with a retention policy (optionally locked,
  which is irreversible) and a lifecycle rule that deletes objects after the retention period.
* **Data Access audit logs** can be switched on per service at organisation level. They are off by default
  because they are high-volume and billed as ingestion.

Admin Activity and System Event audit logs are always written by Google into each project's `_Required`
bucket (400 days, no charge). The aggregated sink copies them centrally so that investigators have one place
to look.

## Usage

```hcl
module "logging" {
  source = "../../modules/logging"

  org_id     = "123456789012"
  project_id = "prj-c-logging-1a2b"

  log_buckets = {
    audit   = { location = "europe-west2", retention_days = 400 }
    network = { location = "europe-west2", retention_days = 30 }
  }

  sinks = {
    org-audit   = { log_bucket = "audit", filter = "log_id(\"cloudaudit.googleapis.com/activity\")" }
    org-network = { log_bucket = "network", filter = "log_id(\"compute.googleapis.com/vpc_flows\")" }
  }
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| google | >= 8.10.0, < 9.0.0 |

### Providers

| Name | Version |
| ---- | ------- |
| google | >= 8.10.0, < 9.0.0 |

### Modules

No modules.

### Resources

| Name | Type |
| ---- | ---- |
| [google_logging_organization_sink.archive](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_organization_sink) | resource |
| [google_logging_organization_sink.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_organization_sink) | resource |
| [google_logging_project_bucket_config.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_bucket_config) | resource |
| [google_organization_iam_audit_config.data_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_audit_config) | resource |
| [google_project_iam_member.sink_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_storage_bucket.archive](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.archive_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| org\_id | Numeric organisation ID whose logs are aggregated. | `string` | n/a | yes |
| project\_id | Central logging project that owns the log buckets and the optional archive bucket. | `string` | n/a | yes |
| archive | Optional long-term archive: an aggregated sink that writes matching logs to a Cloud Storage bucket with a retention policy. Use it when retention must exceed what you want to pay for in Cloud Logging, or when auditors want write-once storage. `lock_retention = true` is irreversible. | ```object({ bucket_name = string location = string retention_days = number lock_retention = optional(bool, false) storage_class = optional(string, "ARCHIVE") filter = string kms_key_name = optional(string) })``` | `null` | no |
| data\_access\_audit\_services | Services for which Data Access audit logs (DATA\_READ, DATA\_WRITE, ADMIN\_READ) are switched on at organisation level, for example `["allServices"]` or `["storage.googleapis.com"]`. These logs can be very high volume and are billed as ingestion, so the default is none. | `list(string)` | `[]` | no |
| labels | Labels applied to the archive bucket. | `map(string)` | `{}` | no |
| log\_buckets | Cloud Logging buckets to create in the logging project, keyed by bucket ID. `locked = true` makes the retention period permanent and cannot be undone; turn it on only once the retention figure has been agreed with whoever owns compliance. `enable_analytics` upgrades the bucket to Log Analytics, which also cannot be reversed. | ```map(object({ location = string retention_days = number locked = optional(bool, false) enable_analytics = optional(bool, false) description = optional(string) }))``` | ```{ "audit": { "description": "Organisation-wide audit logs.", "location": "global", "retention_days": 400 } }``` | no |
| sinks | Organisation-level aggregated sinks, keyed by sink name. `log_bucket` is a key of `log_buckets`. `exclusions` maps an exclusion name to a filter that is dropped from this sink only. | ```map(object({ filter = string log_bucket = string description = optional(string) include_children = optional(bool, true) exclusions = optional(map(string), {}) }))``` | ```{ "audit": { "description": "Admin Activity, System Event, Policy Denied, Data Access and Access Transparency logs.", "filter": "log_id(\"cloudaudit.googleapis.com/activity\") OR\nlog_id(\"cloudaudit.googleapis.com/system_event\") OR\nlog_id(\"cloudaudit.googleapis.com/policy\") OR\nlog_id(\"cloudaudit.googleapis.com/data_access\") OR\nlog_id(\"cloudaudit.googleapis.com/access_transparency\")\n", "log_bucket": "audit" } }``` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| archive\_bucket | Name of the archive bucket, or null when the archive is disabled. |
| log\_bucket\_ids | Resource names of the log buckets, keyed by bucket ID. |
| sink\_writer\_identities | Writer identities of the aggregated sinks, keyed by sink name (including `archive-to-gcs` when enabled). |
<!-- END_TF_DOCS -->
