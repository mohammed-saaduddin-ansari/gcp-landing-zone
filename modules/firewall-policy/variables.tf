variable "parent" {
  description = "Owner of the hierarchical firewall policy: `organizations/<id>` or `folders/<id>`."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent must be organizations/<id> or folders/<id>."
  }
}

variable "short_name" {
  description = "Short name of the policy, unique within the organisation."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.short_name))
    error_message = "short_name must be a valid RFC 1035 name."
  }
}

variable "description" {
  description = "Description of the policy."
  type        = string
  default     = "Managed by Terraform."
}

variable "attachment_targets" {
  description = "Nodes the policy is associated with (`organizations/<id>` or `folders/<id>`). A node can have only one associated hierarchical policy."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for t in var.attachment_targets : can(regex("^(organizations|folders)/[0-9]+$", t))])
    error_message = "attachment_targets must be organizations/<id> or folders/<id>."
  }
}

variable "rules" {
  description = <<-EOT
    Rules keyed by a short name. Lower `priority` numbers are evaluated first. `goto_next` hands evaluation to
    the next level down (folder policy, then VPC firewall rules), which is how the organisation delegates
    decisions it does not want to make centrally. Each `layer4` entry is `{ protocol = "tcp", ports = ["22"] }`.
  EOT
  type = map(object({
    priority                = number
    direction               = string
    action                  = string
    description             = optional(string)
    src_ip_ranges           = optional(list(string), [])
    dest_ip_ranges          = optional(list(string), [])
    layer4                  = optional(list(object({ protocol = string, ports = optional(list(string), []) })), [{ protocol = "all" }])
    target_service_accounts = optional(list(string), [])
    target_resources        = optional(list(string), [])
    enable_logging          = optional(bool, false)
    disabled                = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.rules) : contains(["INGRESS", "EGRESS"], r.direction)])
    error_message = "direction must be INGRESS or EGRESS."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : contains(["allow", "deny", "goto_next"], r.action)])
    error_message = "action must be allow, deny or goto_next."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : r.priority >= 0 && r.priority <= 2147483647 && floor(r.priority) == r.priority])
    error_message = "priority must be an integer between 0 and 2147483647."
  }

  validation {
    condition     = length(values(var.rules)) == length(distinct([for r in values(var.rules) : r.priority]))
    error_message = "Rule priorities must be unique within a policy."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      r.direction == "INGRESS" ? length(r.src_ip_ranges) > 0 : length(r.dest_ip_ranges) > 0
    ])
    error_message = "INGRESS rules need src_ip_ranges and EGRESS rules need dest_ip_ranges."
  }
}
