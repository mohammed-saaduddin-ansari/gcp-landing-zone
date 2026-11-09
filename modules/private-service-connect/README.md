# private-service-connect

A Private Service Connect endpoint for Google APIs inside a VPC, plus the private DNS that makes it
transparent to clients.

* A global internal address and a forwarding rule targeting the `all-apis` or `vpc-sc` bundle.
* Private zones for `googleapis.com`, `gcr.io` and `pkg.dev` with apex and wildcard A records pointing at
  the endpoint, so `storage.googleapis.com` and friends resolve to an internal IP without any client change.

Compared with Private Google Access through `private.googleapis.com` / `restricted.googleapis.com`, a PSC
endpoint uses an address from your own plan, can be reached from on-premises over Interconnect or VPN with
an ordinary route, and can be pinned to the `vpc-sc` bundle once VPC Service Controls are enforced.

Google requires the endpoint name to be 1-20 lowercase letters and digits with no hyphens; the variable
validation enforces it.

## Usage

```hcl
module "psc_prod" {
  source = "../../modules/private-service-connect"

  project_id    = "prj-p-net-host-1a2b"
  network_id    = module.vpc_prod.network_id
  endpoint_name = "pscprod"
  endpoint_ip   = "10.255.255.10"
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| google | >= 8.10.0, < 9.0.0 |

### Providers

| Name | Version |
| ---- | ------- |
| google | >= 8.10.0, < 9.0.0 |

### Modules

No modules.

### Resources

| Name | Type |
| ---- | ---- |
| [google_compute_global_address.psc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.psc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_dns_managed_zone.psc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.apex](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.wildcard](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| endpoint\_ip | Internal IPv4 address for the endpoint. It must not fall inside any subnet of the network. | `string` | n/a | yes |
| endpoint\_name | Name of the PSC endpoint. Google requires 1-20 lowercase letters and digits, starting with a letter (no hyphens). | `string` | n/a | yes |
| network\_id | ID or self link of the VPC network (the Shared VPC of one environment). | `string` | n/a | yes |
| project\_id | Host project of the network that gets the endpoint. | `string` | n/a | yes |
| api\_bundle | `all-apis` reaches every supported Google API; `vpc-sc` reaches only APIs that support VPC Service Controls, which is the safer choice once a perimeter is enforced. | `string` | `"all-apis"` | no |
| dns\_domains | Private DNS zones that send Google API hostnames to the endpoint. Each zone gets an apex and a wildcard A record pointing at `endpoint_ip`, so default hostnames such as `storage.googleapis.com` resolve to the endpoint without changing client configuration. | `list(string)` | ```[ "googleapis.com.", "gcr.io.", "pkg.dev." ]``` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| dns\_zones | Private DNS zone names, keyed by domain. |
| endpoint\_ip | IP address of the PSC endpoint. |
| forwarding\_rule\_id | ID of the PSC forwarding rule. |
<!-- END_TF_DOCS -->
