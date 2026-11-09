# shared-vpc

Turns a host project into one environment's Shared VPC.

* Custom-mode VPC (no auto subnets), `GLOBAL` dynamic routing by default.
* Subnets with **Private Google Access** on and **VPC flow logs** on at 50% sampling (both overridable per
  subnet), plus optional secondary ranges for GKE.
* One **Cloud Router and Cloud NAT** per region that has a subnet, with dynamic port allocation and error
  logging. VMs have no external IPs (see the org policy baseline), so NAT is the only way out to the internet.
* A **Cloud DNS server policy** that logs queries and can accept inbound forwarding from on-premises.

Firewall policy is deliberately not in this module: the baseline lives in hierarchical firewall policies
(`modules/firewall-policy`), and application teams manage their own VPC rules.

## Usage

```hcl
module "vpc_prod" {
  source = "../../modules/shared-vpc"

  project_id   = "prj-p-net-host-1a2b"
  network_name = "vpc-prod"

  subnets = {
    sb-prod-ew2-app = {
      region           = "europe-west2"
      ip_cidr_range    = "10.10.0.0/20"
      secondary_ranges = { pods = "100.64.0.0/14", services = "100.72.0.0/20" }
    }
  }
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
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_shared_vpc_host_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_host_project) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_dns_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_policy) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| network\_name | Name of the VPC network. | `string` | n/a | yes |
| project\_id | Host project for this environment's Shared VPC. The project must already exist with compute.googleapis.com enabled. | `string` | n/a | yes |
| subnets | Subnets keyed by name. Private Google Access and VPC flow logs are on by default. `secondary_ranges` maps range name to CIDR (for GKE Pods and Services). Flow log sampling is a cost lever: 0.5 halves the volume of the default 1.0. | ```map(object({ region = string ip_cidr_range = string secondary_ranges = optional(map(string), {}) private_google_access = optional(bool, true) description = optional(string) flow_logs = optional(object({ enabled = optional(bool, true) aggregation_interval = optional(string, "INTERVAL_5_SEC") flow_sampling = optional(number, 0.5) metadata = optional(string, "INCLUDE_ALL_METADATA") }), {}) }))``` | n/a | yes |
| dns\_inbound\_forwarding | Allow on-premises resolvers to forward queries into this network (needs hybrid connectivity). | `bool` | `false` | no |
| dns\_logging | Create a Cloud DNS server policy that logs queries from this network. | `bool` | `true` | no |
| nat | Cloud NAT settings. One router and one NAT gateway are created in each region that has a subnet. | ```object({ enabled = optional(bool, true) min_ports_per_vm = optional(number, 64) max_ports_per_vm = optional(number, 4096) log_filter = optional(string, "ERRORS_ONLY") })``` | `{}` | no |
| routing\_mode | `GLOBAL` lets Cloud Routers advertise every region's subnets over hybrid links; `REGIONAL` limits each router to its own region. | `string` | `"GLOBAL"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| nat\_regions | Regions with a Cloud NAT gateway. |
| network\_id | ID of the Shared VPC network (`projects/<p>/global/networks/<name>`). |
| network\_self\_link | Self link of the Shared VPC network. |
| subnets | Subnets keyed by name, with the attributes service projects need. |
<!-- END_TF_DOCS -->
