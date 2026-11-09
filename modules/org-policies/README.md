# org-policies

Applies organisation policy constraints at an organisation, folder or project, using the Org Policy v2 API
(`google_org_policy_policy`).

The defaults are a baseline meant for the organisation node:

| Area | Constraint | Effect |
| --- | --- | --- |
| IAM | `iam.disableServiceAccountKeyCreation`, `iam.disableServiceAccountKeyUpload` | No long-lived service account keys; CI uses workload identity federation |
| IAM | `iam.automaticIamGrantsForDefaultServiceAccounts` | Default service accounts do not get Editor |
| IAM | `iam.allowedPolicyMemberDomains` (when customer IDs are given) | Domain-restricted sharing |
| Compute | `compute.vmExternalIpAccess` (deny all) | No public IPs on VMs; egress via Cloud NAT |
| Compute | `compute.requireOsLogin`, `compute.disableSerialPortAccess` | IAM-controlled SSH, no serial console |
| Compute | `compute.skipDefaultNetworkCreation` | No `default` network with permissive rules |
| Compute | `compute.vmCanIpForward`, `compute.restrictProtocolForwardingCreationForTypes` | No ad-hoc routers; internal protocol forwarding only |
| Compute | `compute.restrictXpnProjectLienRemoval`, `compute.disableVpcExternalIpv6`, `compute.setNewProjectDefaultToZonalDNSOnly` | Protect host projects; no external IPv6; zonal DNS |
| Storage | `storage.uniformBucketLevelAccess`, `storage.publicAccessPrevention` | No ACLs, no public buckets |
| Cloud SQL | `sql.restrictPublicIp`, `sql.restrictAuthorizedNetworks` | Private-IP databases |
| Location | `gcp.resourceLocations` (when locations are given) | Data residency |

Organisations created since 2024 already have several of these enforced by Google's secure-by-default
policies. Managing them explicitly makes the intent visible in code and keeps older organisations consistent.

Call the module a second time at a folder to make exceptions, for example allowing external IPs in
`sandbox`. Pass `boolean_policies = {}` there so the folder only carries the exception.

## Usage

```hcl
module "org_policies" {
  source = "../../modules/org-policies"

  parent                        = "organizations/123456789012"
  allowed_policy_member_domains = ["C0abc1234"]
  allowed_resource_locations    = ["in:eu-locations"]
}

module "sandbox_exceptions" {
  source = "../../modules/org-policies"

  parent           = "folders/222222222222"
  boolean_policies = {}
  list_policies    = { "compute.vmExternalIpAccess" = { allow_all = true } }
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
| [google_org_policy_policy.boolean](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/org_policy_policy) | resource |
| [google_org_policy_policy.list](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/org_policy_policy) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| parent | Where the policies are set: `organizations/<id>`, `folders/<id>` or `projects/<project id>`. | `string` | n/a | yes |
| allowed\_policy\_member\_domains | Cloud Identity / Workspace customer IDs (for example `C0abc1234`) allowed in IAM policies. Setting this enforces domain-restricted sharing via `iam.allowedPolicyMemberDomains`. Leave empty to skip. | `list(string)` | `[]` | no |
| allowed\_resource\_locations | Values for `gcp.resourceLocations`, for example `["in:eu-locations"]` or `["in:europe-west2-locations"]`. Leave empty to skip. Global services are unaffected by this constraint. | `list(string)` | `[]` | no |
| boolean\_policies | Boolean constraints, mapped to `true` (enforce) or `false` (explicitly not enforced, used for folder- or project-level exceptions). The default is the baseline applied at organisation level. | `map(bool)` | ```{ "compute.disableSerialPortAccess": true, "compute.disableVpcExternalIpv6": true, "compute.requireOsLogin": true, "compute.restrictXpnProjectLienRemoval": true, "compute.setNewProjectDefaultToZonalDNSOnly": true, "compute.skipDefaultNetworkCreation": true, "iam.automaticIamGrantsForDefaultServiceAccounts": true, "iam.disableServiceAccountKeyCreation": true, "iam.disableServiceAccountKeyUpload": true, "sql.restrictAuthorizedNetworks": true, "sql.restrictPublicIp": true, "storage.publicAccessPrevention": true, "storage.uniformBucketLevelAccess": true }``` | no |
| list\_policies | List constraints. For each constraint set exactly one of `allow`, `deny`, `allow_all` or `deny_all`. `inherit_from_parent = true` merges the values with the parent's policy instead of replacing it. The default is the baseline applied at organisation level; organisation-specific constraints such as `iam.allowedPolicyMemberDomains` and `gcp.resourceLocations` are supplied by the caller. | ```map(object({ allow = optional(list(string), []) deny = optional(list(string), []) allow_all = optional(bool, false) deny_all = optional(bool, false) inherit_from_parent = optional(bool, false) }))``` | ```{ "compute.restrictProtocolForwardingCreationForTypes": { "allow": [ "is:INTERNAL" ] }, "compute.vmCanIpForward": { "deny_all": true }, "compute.vmExternalIpAccess": { "deny_all": true } }``` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| boolean\_policies | Boolean constraints managed at this parent, mapped to whether they are enforced. |
| list\_policy\_names | Resource names of the list constraint policies managed at this parent. |
<!-- END_TF_DOCS -->
