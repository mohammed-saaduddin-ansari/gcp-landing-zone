# Stage 3: projects

The project factory. Each YAML file in [`projects/`](projects/README.md) becomes a project with labels, APIs,
group IAM, a budget and, for `prod` and `nonprod`, a Shared VPC attachment to the environment's host project.

Plan-time checks (output preconditions) catch duplicate project IDs, unknown folders, Shared VPC requests in
environments with no host project, and malformed subnet references.

Optionally, projects with `vpc_sc: true` are placed in a VPC Service Controls perimeter, in dry-run until
you choose otherwise.

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
| projects | ../../modules/project-factory | n/a |
| vpc\_sc | ../../modules/vpc-service-controls | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | Default billing account for new projects. | `string` | n/a | yes |
| folder\_ids | Folder IDs from 1-org, keyed by folder key (`prod`, `nonprod`, `sandbox`, ...). | `map(string)` | n/a | yes |
| quota\_project | Project used for API quota and billing of API calls (the seed project). | `string` | n/a | yes |
| budget\_currency | Currency of the billing account, used for budgets that do not set one. Must match the billing account. | `string` | `null` | no |
| host\_projects | Shared VPC host project per environment, from the 2-networking output `host_projects`. | `map(string)` | `{}` | no |
| impersonate\_service\_account | Service account to impersonate for local runs. Leave null in CI. | `string` | `null` | no |
| projects\_dir | Directory of project definition YAML files, relative to this stage. | `string` | `"projects"` | no |
| vpc\_sc | Optional VPC Service Controls perimeter around every project whose YAML sets `vpc_sc: true`. Starts in dry-run. `extra_resources` adds projects created elsewhere (such as the prod host project) as `projects/<number>`. | ```object({ enabled = optional(bool, false) access_policy_id = optional(string) perimeter_name = optional(string, "prod_data") mode = optional(string, "dry_run") extra_resources = optional(list(string), []) })``` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| projects | Projects created from the YAML definitions. |
| vpc\_sc\_perimeter | Service perimeter name and mode, or null when VPC Service Controls are disabled. |
<!-- END_TF_DOCS -->
