variable "access_policy_id" {
  description = "Numeric ID of the existing organisation access policy. Leave null and set `create_access_policy` to create one."
  type        = string
  default     = null

  validation {
    condition     = var.access_policy_id == null || can(regex("^[0-9]+$", var.access_policy_id))
    error_message = "access_policy_id must be numeric."
  }
}

variable "create_access_policy" {
  description = "Create the organisation-level access policy. An organisation can have only one, so this is usually false."
  type        = bool
  default     = false
}

variable "org_id" {
  description = "Numeric organisation ID. Required only when `create_access_policy` is true."
  type        = string
  default     = null
}

variable "perimeter_name" {
  description = "Short name of the service perimeter (letters, digits and underscores)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,49}$", var.perimeter_name))
    error_message = "perimeter_name must start with a letter and contain only letters, digits and underscores (max 50)."
  }
}

variable "mode" {
  description = <<-EOT
    `dry_run` writes the configuration to the perimeter's dry-run spec: violations are logged but nothing is
    blocked. `enforced` writes it to the live status. Always run in dry-run first and review the
    violation logs before switching.
  EOT
  type        = string
  default     = "dry_run"

  validation {
    condition     = contains(["dry_run", "enforced"], var.mode)
    error_message = "mode must be dry_run or enforced."
  }
}

variable "resources" {
  description = "Projects inside the perimeter, as `projects/<project number>` (numbers, not IDs)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.resources : can(regex("^projects/[0-9]+$", r))])
    error_message = "resources must be projects/<project number>."
  }
}

variable "restricted_services" {
  description = "Services whose APIs are protected by the perimeter."
  type        = list(string)
  default = [
    "bigquery.googleapis.com",
    "bigtable.googleapis.com",
    "cloudkms.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "spanner.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ]
}

variable "restrict_vpc_accessible_services" {
  description = "Limit which APIs can be called from networks inside the perimeter to the restricted services."
  type        = bool
  default     = true
}

variable "access_levels" {
  description = "Access level resource names allowed to cross the perimeter (for example a corporate IP range level)."
  type        = list(string)
  default     = []
}
