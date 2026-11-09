# vpc-service-controls

An optional VPC Service Controls perimeter around sensitive projects, dry-run by default.

VPC-SC stops data being copied out of a set of projects through Google APIs, even by a caller with valid IAM
credentials, for example `gsutil cp` from a production bucket to a personal project. It is also one of the
easiest controls to get wrong: an enforced perimeter that is missing an ingress rule breaks CI, the console,
or a partner integration immediately.

So this module:

1. defaults to `mode = "dry_run"`, which writes the configuration to the perimeter's explicit dry-run
   `spec`. Violations are logged (`protoPayload.metadata.dryRun = true`) but nothing is blocked;
2. switches to `mode = "enforced"` only when you change it, which moves the same configuration into the
   live `status`.

Review a few weeks of dry-run violation logs, add ingress and egress rules or access levels for the
legitimate ones, then enforce. Resources are project numbers, not IDs; the variable validation enforces
this.

Not yet covered: ingress and egress policies as inputs and perimeter bridges. See the roadmap.

## Usage

```hcl
module "vpc_sc" {
  source = "../../modules/vpc-service-controls"

  access_policy_id = "123456789"
  perimeter_name   = "prod_data"
  resources        = ["projects/100000000042"]
  mode             = "dry_run"
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
| [google_access_context_manager_access_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/access_context_manager_access_policy) | resource |
| [google_access_context_manager_service_perimeter.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/access_context_manager_service_perimeter) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| perimeter\_name | Short name of the service perimeter (letters, digits and underscores). | `string` | n/a | yes |
| access\_levels | Access level resource names allowed to cross the perimeter (for example a corporate IP range level). | `list(string)` | `[]` | no |
| access\_policy\_id | Numeric ID of the existing organisation access policy. Leave null and set `create_access_policy` to create one. | `string` | `null` | no |
| create\_access\_policy | Create the organisation-level access policy. An organisation can have only one, so this is usually false. | `bool` | `false` | no |
| mode | `dry_run` writes the configuration to the perimeter's dry-run spec: violations are logged but nothing is blocked. `enforced` writes it to the live status. Always run in dry-run first and review the violation logs before switching. | `string` | `"dry_run"` | no |
| org\_id | Numeric organisation ID. Required only when `create_access_policy` is true. | `string` | `null` | no |
| resources | Projects inside the perimeter, as `projects/<project number>` (numbers, not IDs). | `list(string)` | `[]` | no |
| restrict\_vpc\_accessible\_services | Limit which APIs can be called from networks inside the perimeter to the restricted services. | `bool` | `true` | no |
| restricted\_services | Services whose APIs are protected by the perimeter. | `list(string)` | ```[ "bigquery.googleapis.com", "bigtable.googleapis.com", "cloudkms.googleapis.com", "pubsub.googleapis.com", "secretmanager.googleapis.com", "spanner.googleapis.com", "sqladmin.googleapis.com", "storage.googleapis.com" ]``` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| access\_policy\_id | Numeric ID of the access policy in use. |
| mode | Whether the perimeter is in dry\_run or enforced mode. |
| perimeter\_name | Full resource name of the service perimeter. |
<!-- END_TF_DOCS -->
