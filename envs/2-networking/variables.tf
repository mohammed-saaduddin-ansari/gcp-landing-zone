variable "billing_account" {
  description = "Billing account ID for the host projects."
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
  description = "Folder IDs from the 1-org stage output `folder_ids` (needs at least the environment keys)."
  type        = map(string)
}

variable "environments" {
  description = <<-EOT
    One Shared VPC per environment. Each environment gets its own host project in the folder of the same
    name, a custom-mode VPC, Cloud NAT in every region with a subnet, and a PSC endpoint for Google APIs.
  EOT
  type = map(object({
    host_project_id = string
    network_name    = string
    psc_endpoint_ip = string
    subnets = map(object({
      region           = string
      ip_cidr_range    = string
      secondary_ranges = optional(map(string), {})
      flow_sampling    = optional(number, 0.5)
    }))
  }))

  validation {
    condition     = length(var.environments) > 0
    error_message = "Define at least one environment."
  }
}

variable "network_admins_group" {
  description = "Group email granted network administration on the host projects."
  type        = string
}
