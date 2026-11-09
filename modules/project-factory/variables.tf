variable "billing_account" {
  description = "Default billing account for new projects, in the form `XXXXXX-XXXXXX-XXXXXX`."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-Z]{6}-[0-9A-Z]{6}-[0-9A-Z]{6}$", var.billing_account))
    error_message = "billing_account must look like 012345-6789AB-CDEF01 (upper case)."
  }
}

variable "default_labels" {
  description = "Labels added to every project. Per-project labels win on conflict."
  type        = map(string)
  default     = {}
}

variable "required_labels" {
  description = "Label keys every project must carry after defaults are merged. Used for cost allocation and ownership."
  type        = list(string)
  default     = ["environment", "owner", "cost_centre"]
}

variable "projects" {
  description = <<-EOT
    Projects to create, keyed by project ID. Normally produced by decoding the YAML files under
    `envs/3-projects/projects/`. See the module README for the full schema.
  EOT
  type = map(object({
    name            = optional(string)
    folder_id       = string
    billing_account = optional(string)
    labels          = optional(map(string), {})
    services        = optional(list(string), [])
    deletion_policy = optional(string, "PREVENT")
    iam             = optional(map(list(string)), {})

    budget = optional(object({
      amount                = number
      currency_code         = optional(string)
      alert_thresholds      = optional(list(number), [0.5, 0.9, 1.0])
      forecast_threshold    = optional(number, 1.0)
      pubsub_topic          = optional(string)
      notification_channels = optional(list(string), [])
    }))

    shared_vpc = optional(object({
      host_project  = string
      subnets       = optional(list(string), [])
      network_users = optional(list(string), [])
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for id in keys(var.projects) : can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", id))])
    error_message = "Project IDs (map keys) must be 6-30 characters of lowercase letters, digits and hyphens, starting with a letter."
  }

  validation {
    # Cloud Resource Manager rule for project display names.
    condition     = alltrue([for p in values(var.projects) : p.name == null || can(regex("^[A-Za-z0-9 '\"!-]{4,30}$", p.name))])
    error_message = "Project names must be 4-30 characters of letters, digits, spaces, hyphens, quotes or exclamation marks."
  }

  validation {
    condition     = alltrue([for p in values(var.projects) : can(regex("^folders/[0-9]+$", p.folder_id))])
    error_message = "folder_id must be a folder resource name such as folders/123456789012."
  }

  validation {
    condition = alltrue(flatten([
      for p in values(var.projects) : [
        for k, v in p.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
      ]
    ]))
    error_message = "Label keys must start with a lowercase letter; keys and values may contain only lowercase letters, digits, underscores and hyphens (max 63)."
  }

  validation {
    condition     = alltrue([for p in values(var.projects) : contains(["PREVENT", "ABANDON", "DELETE"], p.deletion_policy)])
    error_message = "deletion_policy must be PREVENT, ABANDON or DELETE."
  }

  validation {
    condition     = alltrue(flatten([for p in values(var.projects) : [for _, m in p.iam : [for x in m : startswith(x, "group:")]]]))
    error_message = "Project IAM members must be group: principals."
  }

  validation {
    condition     = alltrue(flatten([for p in values(var.projects) : p.shared_vpc == null ? [true] : [for x in p.shared_vpc.network_users : startswith(x, "group:")]]))
    error_message = "Shared VPC network_users must be group: principals; service agents are added automatically."
  }

  validation {
    condition     = alltrue(flatten([for p in values(var.projects) : p.shared_vpc == null ? [true] : [for s in p.shared_vpc.subnets : can(regex("^projects/[^/]+/regions/[^/]+/subnetworks/[^/]+$", s))]]))
    error_message = "Shared VPC subnets must be IDs in the form projects/<host>/regions/<region>/subnetworks/<name>."
  }

  validation {
    condition = alltrue(flatten([
      for p in values(var.projects) : p.budget == null ? [true] : concat(
        [p.budget.amount > 0],
        [for t in p.budget.alert_thresholds : t > 0 && t <= 10],
      )
    ]))
    error_message = "Budgets need a positive amount, and thresholds are fractions such as 0.5 or 1.0."
  }
}
