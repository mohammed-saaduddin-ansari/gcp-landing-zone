variable "project_id" {
  description = "Host project for this environment's Shared VPC. The project must already exist with compute.googleapis.com enabled."
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.network_name))
    error_message = "network_name must be a valid RFC 1035 name."
  }
}

variable "routing_mode" {
  description = "`GLOBAL` lets Cloud Routers advertise every region's subnets over hybrid links; `REGIONAL` limits each router to its own region."
  type        = string
  default     = "GLOBAL"

  validation {
    condition     = contains(["GLOBAL", "REGIONAL"], var.routing_mode)
    error_message = "routing_mode must be GLOBAL or REGIONAL."
  }
}

variable "subnets" {
  description = <<-EOT
    Subnets keyed by name. Private Google Access and VPC flow logs are on by default. `secondary_ranges` maps
    range name to CIDR (for GKE Pods and Services). Flow log sampling is a cost lever: 0.5 halves the volume
    of the default 1.0.
  EOT
  type = map(object({
    region                = string
    ip_cidr_range         = string
    secondary_ranges      = optional(map(string), {})
    private_google_access = optional(bool, true)
    description           = optional(string)
    flow_logs = optional(object({
      enabled              = optional(bool, true)
      aggregation_interval = optional(string, "INTERVAL_5_SEC")
      flow_sampling        = optional(number, 0.5)
      metadata             = optional(string, "INCLUDE_ALL_METADATA")
    }), {})
  }))

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrhost(s.ip_cidr_range, 0))])
    error_message = "Every subnet needs a valid IPv4 CIDR."
  }

  validation {
    condition     = alltrue(flatten([for s in values(var.subnets) : [for c in values(s.secondary_ranges) : can(cidrhost(c, 0))]]))
    error_message = "Every secondary range needs a valid IPv4 CIDR."
  }

  validation {
    condition     = alltrue([for s in values(var.subnets) : s.flow_logs.flow_sampling >= 0 && s.flow_logs.flow_sampling <= 1])
    error_message = "flow_sampling must be between 0 and 1."
  }
}

variable "nat" {
  description = "Cloud NAT settings. One router and one NAT gateway are created in each region that has a subnet."
  type = object({
    enabled          = optional(bool, true)
    min_ports_per_vm = optional(number, 64)
    max_ports_per_vm = optional(number, 4096)
    log_filter       = optional(string, "ERRORS_ONLY")
  })
  default = {}

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.nat.log_filter)
    error_message = "nat.log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}

variable "dns_logging" {
  description = "Create a Cloud DNS server policy that logs queries from this network."
  type        = bool
  default     = true
}

variable "dns_inbound_forwarding" {
  description = "Allow on-premises resolvers to forward queries into this network (needs hybrid connectivity)."
  type        = bool
  default     = false
}
