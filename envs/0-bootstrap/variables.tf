variable "org_id" {
  description = "Numeric organisation ID."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID (`XXXXXX-XXXXXX-XXXXXX`)."
  type        = string
}

variable "seed_project_id" {
  description = "Globally unique ID for the seed project."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

variable "state_bucket_location" {
  description = "Location of the state bucket."
  type        = string
  default     = "EU"
}

variable "github_repository" {
  description = "Repository (`owner/name`) whose workflows may deploy the landing zone."
  type        = string
}

variable "apply_environments" {
  description = <<-EOT
    When true, each stage's CI identity is bound to the GitHub environment of the same name
    (subject `repo:<owner/name>:environment:<stage>`) instead of to the whole repository, so only jobs that
    passed that environment's protection rules can impersonate it. Requires matching GitHub environments.
  EOT
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels for bootstrap resources."
  type        = map(string)
  default     = {}
}
