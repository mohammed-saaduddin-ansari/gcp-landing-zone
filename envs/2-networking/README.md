# Stage 2: networking

One host project and Shared VPC per environment (`prod`, `nonprod`), each in its environment's folder, with
Cloud NAT per region, DNS query logging and a PSC endpoint for Google APIs. Environments are separate
networks with no peering between them; the address plan does not overlap so they can be connected later.

Inputs come from stage 1 (`folder_ids`). Outputs (`host_projects`, `subnets`) feed stage 3.

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
| host\_projects | ../../modules/project-factory | n/a |
| psc | ../../modules/private-service-connect | n/a |
| shared\_vpc | ../../modules/shared-vpc | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | Billing account ID for the host projects. | `string` | n/a | yes |
| environments | One Shared VPC per environment. Each environment gets its own host project in the folder of the same name, a custom-mode VPC, Cloud NAT in every region with a subnet, and a PSC endpoint for Google APIs. | ```map(object({ host_project_id = string network_name = string psc_endpoint_ip = string subnets = map(object({ region = string ip_cidr_range = string secondary_ranges = optional(map(string), {}) flow_sampling = optional(number, 0.5) })) }))``` | n/a | yes |
| folder\_ids | Folder IDs from the 1-org stage output `folder_ids` (needs at least the environment keys). | `map(string)` | n/a | yes |
| network\_admins\_group | Group email granted network administration on the host projects. | `string` | n/a | yes |
| quota\_project | Project used for API quota and billing of API calls (the seed project). | `string` | n/a | yes |
| impersonate\_service\_account | Service account to impersonate for local runs. Leave null in CI. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| host\_projects | Host project ID per environment. Pass to 3-projects. |
| networks | Shared VPC network ID per environment. |
| psc\_endpoints | PSC endpoint IP per environment. |
| subnets | Subnets per environment, keyed by subnet name. |
<!-- END_TF_DOCS -->
