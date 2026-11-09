# project-factory

Creates projects from a map of definitions. In this repository the map is decoded from one YAML file per
project (`envs/3-projects/projects/`), so a new project is a pull request that adds one file.

For each project:

* no default network, deletion protection (`PREVENT`) unless overridden;
* default labels merged with project labels, and a precondition that the **required labels**
  (`environment`, `owner`, `cost_centre` by default) are present, so cost reports can be grouped from day one;
* APIs enabled (`disable_on_destroy = false`, so removing an API from the list never breaks a running
  workload);
* IAM for groups only, as in `modules/iam`;
* optionally a **monthly budget** with alerts at 50/90/100% of actual spend and 100% of forecast spend, sent
  to billing administrators and optionally to Pub/Sub or Cloud Monitoring channels;
* optionally **Shared VPC attachment** with `roles/compute.networkUser` on named subnets for the given
  groups, the Google APIs service agent and, if GKE is enabled, the GKE service agent (which also gets
  `roles/container.hostServiceAgentUser` on the host project).

Budgets alert; they do not cap spend.

## Usage

```hcl
module "projects" {
  source = "../../modules/project-factory"

  billing_account = "012345-6789AB-CDEF01"

  projects = {
    "prj-p-payments-api-1a2b" = {
      folder_id = "folders/333333333333"
      labels    = { environment = "prod", owner = "payments", cost_centre = "cc-1234" }
      services  = ["container.googleapis.com"]
      budget    = { amount = 2500, currency_code = "GBP" }
      shared_vpc = {
        host_project  = "prj-p-net-host-1a2b"
        subnets       = ["projects/prj-p-net-host-1a2b/regions/europe-west2/subnetworks/sb-prod-ew2-app"]
        network_users = ["group:payments-devs@example.com"]
      }
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
| [google_billing_budget.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |
| [google_compute_shared_vpc_service_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_service_project) | resource |
| [google_compute_subnetwork_iam_member.network_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork_iam_member) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_iam_member.gke_host_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | Default billing account for new projects, in the form `XXXXXX-XXXXXX-XXXXXX`. | `string` | n/a | yes |
| default\_labels | Labels added to every project. Per-project labels win on conflict. | `map(string)` | `{}` | no |
| projects | Projects to create, keyed by project ID. Normally produced by decoding the YAML files under `envs/3-projects/projects/`. See the module README for the full schema. | ```map(object({ name = optional(string) folder_id = string billing_account = optional(string) labels = optional(map(string), {}) services = optional(list(string), []) deletion_policy = optional(string, "PREVENT") iam = optional(map(list(string)), {}) budget = optional(object({ amount = number currency_code = optional(string) alert_thresholds = optional(list(number), [0.5, 0.9, 1.0]) forecast_threshold = optional(number, 1.0) pubsub_topic = optional(string) notification_channels = optional(list(string), []) })) shared_vpc = optional(object({ host_project = string subnets = optional(list(string), []) network_users = optional(list(string), []) })) }))``` | `{}` | no |
| required\_labels | Label keys every project must carry after defaults are merged. Used for cost allocation and ownership. | `list(string)` | ```[ "environment", "owner", "cost_centre" ]``` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| budget\_ids | Budget resource IDs keyed by project ID. |
| project\_numbers | Project numbers keyed by project ID (useful for VPC Service Controls perimeters). |
| projects | Created projects keyed by project ID, with number, folder and labels. |
<!-- END_TF_DOCS -->
