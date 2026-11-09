# firewall-policy

A hierarchical firewall policy attached to the organisation or to folders.

Hierarchical policies are evaluated before any VPC firewall rule, so they are the right place for rules that
no project should be able to override: allow IAP TCP forwarding and Google health checks, deny SSH and RDP
from the internet. Anything the policy does not match (or matches with `goto_next`) falls through to the next
level down, which is how central and team-owned rules coexist.

Variable validation enforces valid directions and actions, unique priorities, and a source range on ingress
and a destination range on egress.

## Usage

```hcl
module "org_firewall" {
  source = "../../modules/firewall-policy"

  parent             = "organizations/123456789012"
  short_name         = "org-baseline"
  attachment_targets = ["organizations/123456789012"]

  rules = {
    allow-iap = {
      priority      = 1000
      direction     = "INGRESS"
      action        = "allow"
      src_ip_ranges = ["35.235.240.0/20"]
      layer4        = [{ protocol = "tcp", ports = ["22", "3389"] }]
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
| [google_compute_firewall_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall_policy) | resource |
| [google_compute_firewall_policy_association.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall_policy_association) | resource |
| [google_compute_firewall_policy_rule.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall_policy_rule) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| parent | Owner of the hierarchical firewall policy: `organizations/<id>` or `folders/<id>`. | `string` | n/a | yes |
| short\_name | Short name of the policy, unique within the organisation. | `string` | n/a | yes |
| attachment\_targets | Nodes the policy is associated with (`organizations/<id>` or `folders/<id>`). A node can have only one associated hierarchical policy. | `list(string)` | `[]` | no |
| description | Description of the policy. | `string` | `"Managed by Terraform."` | no |
| rules | Rules keyed by a short name. Lower `priority` numbers are evaluated first. `goto_next` hands evaluation to the next level down (folder policy, then VPC firewall rules), which is how the organisation delegates decisions it does not want to make centrally. Each `layer4` entry is `{ protocol = "tcp", ports = ["22"] }`. | ```map(object({ priority = number direction = string action = string description = optional(string) src_ip_ranges = optional(list(string), []) dest_ip_ranges = optional(list(string), []) layer4 = optional(list(object({ protocol = string, ports = optional(list(string), []) })), [{ protocol = "all" }]) target_service_accounts = optional(list(string), []) target_resources = optional(list(string), []) enable_logging = optional(bool, false) disabled = optional(bool, false) }))``` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| policy\_id | ID of the hierarchical firewall policy (`locations/global/firewallPolicies/<numeric id>`). |
| policy\_name | Numeric name of the policy, as used by rules. |
| rule\_priorities | Rule priorities, keyed by rule name. |
<!-- END_TF_DOCS -->
