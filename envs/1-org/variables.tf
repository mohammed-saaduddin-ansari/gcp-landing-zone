variable "org_id" {
  description = "Numeric organisation ID."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID (`XXXXXX-XXXXXX-XXXXXX`)."
  type        = string
}

variable "quota_project" {
  description = "Project used for API quota and billing of API calls (the seed project)."
  type        = string
}

variable "impersonate_service_account" {
  description = "Service account to impersonate for local runs. Leave null in CI."
  type        = string
  default     = null
}

variable "directory_customer_ids" {
  description = "Cloud Identity / Workspace customer IDs allowed in IAM policies (domain-restricted sharing)."
  type        = list(string)
}

variable "allowed_resource_locations" {
  description = "Value groups or locations for gcp.resourceLocations, for example `[\"in:eu-locations\"]`."
  type        = list(string)
  default     = ["in:eu-locations"]
}

variable "project_ids" {
  description = "IDs of the shared projects created in the common folder."
  type = object({
    logging  = string
    security = string
  })
}

variable "groups" {
  description = "Google group emails for the standard administrative personas."
  type = object({
    org_admins      = string
    billing_admins  = string
    network_admins  = string
    security_admins = string
    auditors        = string
    developers      = string
  })
}

variable "audit_log_retention_days" {
  description = "Retention of the central audit log bucket."
  type        = number
  default     = 400
}

variable "log_archive" {
  description = "Optional long-term archive bucket for audit logs. See modules/logging."
  type = object({
    bucket_name    = string
    location       = string
    retention_days = number
    lock_retention = optional(bool, false)
  })
  default = null
}

variable "essential_contacts" {
  description = "Organisation Essential Contacts: group email => categories."
  type        = map(list(string))
  default     = {}
}

variable "default_region" {
  description = "Region for regional resources such as log buckets."
  type        = string
  default     = "europe-west2"
}
