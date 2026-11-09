# Stage 1: organisation

Applies the organisation-wide foundation as the `tf-org` CI identity:

* folders `common`, `prod`, `nonprod`, `sandbox`;
* the org policy baseline, with a single exception on `sandbox` (external IPs allowed);
* the central logging and security projects in `common`;
* aggregated sinks for audit logs (400 days) and network logs (30 days), with an optional locked archive;
* SCC findings to Pub/Sub and Essential Contacts;
* the organisation firewall policy (allow IAP and health checks, deny internet SSH/RDP);
* group-based IAM for the standard administrative personas.

```bash
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform plan
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| google | ~> 8.10 |

### Providers

No providers.

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| common\_projects | ../../modules/project-factory | n/a |
| folders | ../../modules/resource-hierarchy | n/a |
| iam | ../../modules/iam | n/a |
| logging | ../../modules/logging | n/a |
| org\_firewall | ../../modules/firewall-policy | n/a |
| org\_policies | ../../modules/org-policies | n/a |
| sandbox\_policies | ../../modules/org-policies | n/a |
| security | ../../modules/security-baseline | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | Billing account ID (`XXXXXX-XXXXXX-XXXXXX`). | `string` | n/a | yes |
| directory\_customer\_ids | Cloud Identity / Workspace customer IDs allowed in IAM policies (domain-restricted sharing). | `list(string)` | n/a | yes |
| groups | Google group emails for the standard administrative personas. | ```object({ org_admins = string billing_admins = string network_admins = string security_admins = string auditors = string developers = string })``` | n/a | yes |
| org\_id | Numeric organisation ID. | `string` | n/a | yes |
| project\_ids | IDs of the shared projects created in the common folder. | ```object({ logging = string security = string })``` | n/a | yes |
| quota\_project | Project used for API quota and billing of API calls (the seed project). | `string` | n/a | yes |
| allowed\_resource\_locations | Value groups or locations for gcp.resourceLocations, for example `["in:eu-locations"]`. | `list(string)` | ```[ "in:eu-locations" ]``` | no |
| audit\_log\_retention\_days | Retention of the central audit log bucket. | `number` | `400` | no |
| default\_region | Region for regional resources such as log buckets. | `string` | `"europe-west2"` | no |
| essential\_contacts | Organisation Essential Contacts: group email => categories. | `map(list(string))` | `{}` | no |
| impersonate\_service\_account | Service account to impersonate for local runs. Leave null in CI. | `string` | `null` | no |
| log\_archive | Optional long-term archive bucket for audit logs. See modules/logging. | ```object({ bucket_name = string location = string retention_days = number lock_retention = optional(bool, false) })``` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| folder\_ids | Top-level folder IDs created by this stage. Pass them to 2-networking and 3-projects. |
| log\_bucket\_ids | Central log buckets. |
| logging\_project\_id | Central logging project. |
| org\_firewall\_policy | Organisation firewall policy ID. |
| security\_project\_id | Central security project. |
<!-- END_TF_DOCS -->
