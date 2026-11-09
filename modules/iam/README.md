# iam

Grants roles at organisation, folder and project level, to groups only.

* Every member must be a `group:` principal. A `user:` or `serviceAccount:` member fails variable
  validation, so access is managed in the identity provider rather than in Terraform. Service accounts
  get their roles from the module that creates them (bootstrap, project factory).
* `roles/owner` and `roles/editor` are rejected by a precondition.
* Grants are additive (`google_*_iam_member`). Authoritative bindings at organisation or folder level
  would silently remove grants made by Google service agents and by break-glass procedures. See ADR-006.

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  org_id = "123456789012"
  org_bindings = {
    "roles/securitycenter.admin" = ["group:gcp-security-admins@example.com"]
  }
  folder_bindings = {
    nonprod = {
      folder   = "folders/333333333333"
      bindings = { "roles/viewer" = ["group:gcp-developers@example.com"] }
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
| [google_folder_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder_iam_member) | resource |
| [google_organization_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_member) | resource |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| denied\_roles | Basic roles that must never be granted through this module, even to groups. | `list(string)` | ```[ "roles/owner", "roles/editor" ]``` | no |
| folder\_bindings | Folder-level grants, keyed by a stable label of your choice: `{ prod = { folder = "folders/123", bindings = { "roles/viewer" = ["group:prod-readers@example.com"] } } }`. Members must be `group:` principals. | ```map(object({ folder = string bindings = map(list(string)) }))``` | `{}` | no |
| org\_bindings | Organisation-level grants: role => list of members. Members must be `group:` principals. | `map(list(string))` | `{}` | no |
| org\_id | Numeric organisation ID. Required when `org_bindings` is non-empty. | `string` | `null` | no |
| project\_bindings | Project-level grants: `{ label = { project = "my-project", bindings = { role = [members] } } }`. Members must be `group:` principals. | ```map(object({ project = string bindings = map(list(string)) }))``` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| binding\_count | Number of individual role/member grants managed, by scope. |
| granted\_roles | Distinct roles granted by this module, across all scopes. |
<!-- END_TF_DOCS -->
