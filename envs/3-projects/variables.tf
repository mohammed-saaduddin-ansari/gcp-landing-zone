variable "billing_account" {
  description = "Default billing account for new projects."
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

variable "folder_ids" {
  description = "Folder IDs from 1-org, keyed by folder key (`prod`, `nonprod`, `sandbox`, ...)."
  type        = map(string)
}

variable "host_projects" {
  description = "Shared VPC host project per environment, from the 2-networking output `host_projects`."
  type        = map(string)
  default     = {}
}

variable "projects_dir" {
  description = "Directory of project definition YAML files, relative to this stage."
  type        = string
  default     = "projects"
}

variable "budget_currency" {
  description = "Currency of the billing account, used for budgets that do not set one. Must match the billing account."
  type        = string
  default     = null
}

variable "vpc_sc" {
  description = <<-EOT
    Optional VPC Service Controls perimeter around every project whose YAML sets `vpc_sc: true`.
    Starts in dry-run. `extra_resources` adds projects created elsewhere (such as the prod host project) as
    `projects/<number>`.
  EOT
  type = object({
    enabled          = optional(bool, false)
    access_policy_id = optional(string)
    perimeter_name   = optional(string, "prod_data")
    mode             = optional(string, "dry_run")
    extra_resources  = optional(list(string), [])
  })
  default = {}
}
