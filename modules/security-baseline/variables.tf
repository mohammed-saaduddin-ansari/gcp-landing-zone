variable "org_id" {
  description = "Numeric organisation ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "org_id must be numeric."
  }
}

variable "project_id" {
  description = "Central security project that owns the findings topic."
  type        = string
}

variable "scc_notifications" {
  description = <<-EOT
    Stream Security Command Center findings to Pub/Sub for paging or ticketing. Requires Security Command
    Center to be activated for the organisation, which is done once in the console and is not managed here.
    The default filter forwards active, unmuted HIGH and CRITICAL findings only.
  EOT
  type = object({
    enabled           = optional(bool, true)
    config_id         = optional(string, "high-and-critical-findings")
    topic_name        = optional(string, "scc-findings")
    filter            = optional(string, "state = \"ACTIVE\" AND mute != \"MUTED\" AND (severity = \"HIGH\" OR severity = \"CRITICAL\")")
    message_retention = optional(string, "604800s")
    kms_key_name      = optional(string)
  })
  default = {}
}

variable "essential_contacts" {
  description = <<-EOT
    Organisation-level Essential Contacts: email => notification categories. Use group mailboxes, not
    individuals, so notifications survive people leaving.
  EOT
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue(flatten([
      for _, cats in var.essential_contacts : [
        for c in cats : contains(["ALL", "SUSPENSION", "SECURITY", "TECHNICAL", "BILLING", "LEGAL", "PRODUCT_UPDATES", "TECHNICAL_INCIDENTS"], c)
      ]
    ]))
    error_message = "Unknown notification category. Valid: ALL, SUSPENSION, SECURITY, TECHNICAL, BILLING, LEGAL, PRODUCT_UPDATES, TECHNICAL_INCIDENTS."
  }
}

variable "essential_contacts_language" {
  description = "Language tag for Essential Contacts notifications."
  type        = string
  default     = "en-GB"
}

variable "labels" {
  description = "Labels applied to the findings topic."
  type        = map(string)
  default     = {}
}
