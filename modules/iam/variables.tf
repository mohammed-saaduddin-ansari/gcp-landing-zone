variable "org_id" {
  description = "Numeric organisation ID. Required when `org_bindings` is non-empty."
  type        = string
  default     = null

  validation {
    condition     = var.org_id == null || can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be the numeric organisation ID."
  }
}

variable "org_bindings" {
  description = "Organisation-level grants: role => list of members. Members must be `group:` principals."
  type        = map(list(string))
  default     = {}

  validation {
    condition     = alltrue(flatten([for _, m in var.org_bindings : [for x in m : startswith(x, "group:")]]))
    error_message = "Only group: principals may be granted roles here. Grant humans access through groups."
  }
}

variable "folder_bindings" {
  description = <<-EOT
    Folder-level grants, keyed by a stable label of your choice:
    `{ prod = { folder = "folders/123", bindings = { "roles/viewer" = ["group:prod-readers@example.com"] } } }`.
    Members must be `group:` principals.
  EOT
  type = map(object({
    folder   = string
    bindings = map(list(string))
  }))
  default = {}

  validation {
    condition     = alltrue(flatten([for _, f in var.folder_bindings : [for _, m in f.bindings : [for x in m : startswith(x, "group:")]]]))
    error_message = "Only group: principals may be granted roles here. Grant humans access through groups."
  }

  validation {
    condition     = alltrue([for _, f in var.folder_bindings : can(regex("^folders/[0-9]+$", f.folder))])
    error_message = "folder must be a folder resource name such as folders/123456789012."
  }
}

variable "project_bindings" {
  description = "Project-level grants: `{ label = { project = \"my-project\", bindings = { role = [members] } } }`. Members must be `group:` principals."
  type = map(object({
    project  = string
    bindings = map(list(string))
  }))
  default = {}

  validation {
    condition     = alltrue(flatten([for _, p in var.project_bindings : [for _, m in p.bindings : [for x in m : startswith(x, "group:")]]]))
    error_message = "Only group: principals may be granted roles here. Grant humans access through groups."
  }
}

variable "denied_roles" {
  description = "Basic roles that must never be granted through this module, even to groups."
  type        = list(string)
  default     = ["roles/owner", "roles/editor"]
}
