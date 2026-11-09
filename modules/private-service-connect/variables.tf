variable "project_id" {
  description = "Host project of the network that gets the endpoint."
  type        = string
}

variable "network_id" {
  description = "ID or self link of the VPC network (the Shared VPC of one environment)."
  type        = string
}

variable "endpoint_name" {
  description = "Name of the PSC endpoint. Google requires 1-20 lowercase letters and digits, starting with a letter (no hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,19}$", var.endpoint_name))
    error_message = "endpoint_name must be 1-20 lowercase letters and digits, starting with a letter."
  }
}

variable "endpoint_ip" {
  description = "Internal IPv4 address for the endpoint. It must not fall inside any subnet of the network."
  type        = string

  validation {
    condition     = can(cidrhost("${var.endpoint_ip}/32", 0))
    error_message = "endpoint_ip must be an IPv4 address."
  }
}

variable "api_bundle" {
  description = "`all-apis` reaches every supported Google API; `vpc-sc` reaches only APIs that support VPC Service Controls, which is the safer choice once a perimeter is enforced."
  type        = string
  default     = "all-apis"

  validation {
    condition     = contains(["all-apis", "vpc-sc"], var.api_bundle)
    error_message = "api_bundle must be all-apis or vpc-sc."
  }
}

variable "dns_domains" {
  description = <<-EOT
    Private DNS zones that send Google API hostnames to the endpoint. Each zone gets an apex and a wildcard A
    record pointing at `endpoint_ip`, so default hostnames such as `storage.googleapis.com` resolve to the
    endpoint without changing client configuration.
  EOT
  type        = list(string)
  default     = ["googleapis.com.", "gcr.io.", "pkg.dev."]

  validation {
    condition     = alltrue([for d in var.dns_domains : endswith(d, ".")])
    error_message = "DNS domains must be fully qualified and end with a dot."
  }
}
