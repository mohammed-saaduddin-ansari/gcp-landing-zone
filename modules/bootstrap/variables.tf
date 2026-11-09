variable "org_id" {
  description = "Numeric organisation ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be numeric."
  }
}

variable "folder_id" {
  description = "Folder that will hold the seed project (`folders/123...`), normally the `bootstrap` folder."
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.folder_id))
    error_message = "folder_id must look like folders/<numeric id>."
  }
}

variable "billing_account" {
  description = "Billing account ID in the form `XXXXXX-XXXXXX-XXXXXX`."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-Z]{6}-[0-9A-Z]{6}-[0-9A-Z]{6}$", var.billing_account))
    error_message = "billing_account must look like 012345-6789AB-CDEF01 (upper case)."
  }
}

variable "project_id" {
  description = "ID of the seed project that holds Terraform state and the CI identities."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 characters of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "labels" {
  description = "Labels applied to the seed project and state bucket."
  type        = map(string)
  default     = {}
}

variable "activate_apis" {
  description = "APIs enabled on the seed project. The CI identities use this project for quota, so it needs every API the later stages call."
  type        = list(string)
  default = [
    "accesscontextmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "essentialcontacts.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "orgpolicy.googleapis.com",
    "pubsub.googleapis.com",
    "securitycenter.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]
}

variable "state_bucket_name" {
  description = "Globally unique name of the Terraform state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket names are 3-63 characters of lowercase letters, digits, hyphens and underscores."
  }
}

variable "state_bucket_location" {
  description = "Location of the state bucket. A multi-region or dual-region keeps state readable through a regional outage."
  type        = string
  default     = "EU"
}

variable "state_versions_to_keep" {
  description = "Number of noncurrent state object versions kept for rollback before they are deleted."
  type        = number
  default     = 50

  validation {
    condition     = var.state_versions_to_keep >= 1
    error_message = "Keep at least one noncurrent version."
  }
}

variable "state_bucket_kms_key" {
  description = "Optional Cloud KMS key for CMEK on the state bucket. Null uses Google-managed encryption."
  type        = string
  default     = null
}

variable "github_repositories" {
  description = <<-EOT
    GitHub repositories (`owner/name`) allowed to exchange OIDC tokens through the workload identity pool.
    Any token from another repository is rejected by the provider's attribute condition.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.github_repositories) > 0 && alltrue([for r in var.github_repositories : can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", r))])
    error_message = "Provide at least one repository in owner/name form."
  }
}

variable "workload_identity_pool_id" {
  description = "ID of the workload identity pool."
  type        = string
  default     = "github"
}

variable "service_accounts" {
  description = <<-EOT
    CI service accounts, one per stage so that each pipeline holds only the roles its stage needs.
    `wif_subjects` binds the account to exact OIDC subjects (for example
    `repo:owner/name:environment:production`); when empty, the account is bound to every workflow in
    `repository`. `state_prefix` is informational and is surfaced in the outputs for backend configuration.
  EOT
  type = map(object({
    display_name  = string
    repository    = string
    wif_subjects  = optional(list(string), [])
    org_roles     = optional(list(string), [])
    billing_roles = optional(list(string), [])
    state_prefix  = optional(string)
  }))

  validation {
    condition     = alltrue([for k, _ in var.service_accounts : can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", "tf-${k}"))])
    error_message = "Service account keys must produce valid account IDs (tf-<key>, 6-30 characters)."
  }
}
