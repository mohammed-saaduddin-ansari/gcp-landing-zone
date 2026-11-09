variable "parent" {
  description = "Where the policies are set: `organizations/<id>`, `folders/<id>` or `projects/<project id>`."
  type        = string

  validation {
    condition     = can(regex("^(organizations/[0-9]+|folders/[0-9]+|projects/[a-z][a-z0-9-]{4,28}[a-z0-9])$", var.parent))
    error_message = "parent must be organizations/<id>, folders/<id> or projects/<project id>."
  }
}

variable "boolean_policies" {
  description = <<-EOT
    Boolean constraints, mapped to `true` (enforce) or `false` (explicitly not enforced, used for
    folder- or project-level exceptions). The default is the baseline applied at organisation level.
  EOT
  type        = map(bool)
  default = {
    # Compute
    "compute.disableSerialPortAccess"            = true
    "compute.requireOsLogin"                     = true
    "compute.skipDefaultNetworkCreation"         = true
    "compute.restrictXpnProjectLienRemoval"      = true
    "compute.disableVpcExternalIpv6"             = true
    "compute.setNewProjectDefaultToZonalDNSOnly" = true
    # IAM: no long-lived service account keys, no automatic Editor grants to default service accounts
    "iam.disableServiceAccountKeyCreation"            = true
    "iam.disableServiceAccountKeyUpload"              = true
    "iam.automaticIamGrantsForDefaultServiceAccounts" = true
    # Storage
    "storage.uniformBucketLevelAccess" = true
    "storage.publicAccessPrevention"   = true
    # Cloud SQL
    "sql.restrictPublicIp"           = true
    "sql.restrictAuthorizedNetworks" = true
  }
}

variable "list_policies" {
  description = <<-EOT
    List constraints. For each constraint set exactly one of `allow`, `deny`, `allow_all` or `deny_all`.
    `inherit_from_parent = true` merges the values with the parent's policy instead of replacing it.
    The default is the baseline applied at organisation level; organisation-specific constraints such as
    `iam.allowedPolicyMemberDomains` and `gcp.resourceLocations` are supplied by the caller.
  EOT
  type = map(object({
    allow               = optional(list(string), [])
    deny                = optional(list(string), [])
    allow_all           = optional(bool, false)
    deny_all            = optional(bool, false)
    inherit_from_parent = optional(bool, false)
  }))
  default = {
    # No external IPs on VMs; egress goes through Cloud NAT and ingress through load balancers.
    "compute.vmExternalIpAccess" = { deny_all = true }
    # VMs may not act as routers unless a folder or project opts in.
    "compute.vmCanIpForward" = { deny_all = true }
    # Only internal protocol forwarding.
    "compute.restrictProtocolForwardingCreationForTypes" = { allow = ["is:INTERNAL"] }
  }

  validation {
    condition = alltrue([
      for c in values(var.list_policies) :
      length(compact([
        length(c.allow) > 0 ? "allow" : "",
        length(c.deny) > 0 ? "deny" : "",
        c.allow_all ? "allow_all" : "",
        c.deny_all ? "deny_all" : "",
      ])) == 1
    ])
    error_message = "Each list policy must set exactly one of allow, deny, allow_all or deny_all."
  }

  validation {
    condition     = alltrue([for c in values(var.list_policies) : !(c.inherit_from_parent && (c.allow_all || c.deny_all))])
    error_message = "inherit_from_parent cannot be combined with allow_all or deny_all."
  }
}

variable "allowed_policy_member_domains" {
  description = <<-EOT
    Cloud Identity / Workspace customer IDs (for example `C0abc1234`) allowed in IAM policies. Setting this
    enforces domain-restricted sharing via `iam.allowedPolicyMemberDomains`. Leave empty to skip.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.allowed_policy_member_domains : can(regex("^(is:)?C[0-9a-z]+$", id))])
    error_message = "Use directory customer IDs such as C0abc1234, not domain names."
  }
}

variable "allowed_resource_locations" {
  description = <<-EOT
    Values for `gcp.resourceLocations`, for example `["in:eu-locations"]` or `["in:europe-west2-locations"]`.
    Leave empty to skip. Global services are unaffected by this constraint.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for l in var.allowed_resource_locations : can(regex("^(in:|under:)?[a-z0-9-]+$", l))])
    error_message = "Use value groups such as in:eu-locations or individual locations such as europe-west2."
  }
}
