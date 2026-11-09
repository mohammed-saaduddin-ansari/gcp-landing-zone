# resource-hierarchy

Creates the top-level folders of the landing zone and, optionally, one level of subfolders.

The default layout is `bootstrap`, `common`, `prod`, `nonprod` and `sandbox`. Environments are folders
rather than projects or organisations so that organisation policies, firewall policies and IAM can differ
per environment and are inherited by everything created beneath them. Keep the tree shallow: two levels are
enough for most organisations, and every extra level is another place to look when debugging inherited
policy.

Folders are deletion-protected by default.

## Usage

```hcl
module "folders" {
  source = "../../modules/resource-hierarchy"

  parent     = "organizations/123456789012"
  folders    = ["common", "prod", "nonprod", "sandbox"]
  subfolders = { prod = ["payments", "data"] }
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
| [google_folder.sub](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |
| [google_folder.top](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| parent | Parent of the top-level folders, in the form `organizations/123456789012` or `folders/123456789012`. | `string` | n/a | yes |
| deletion\_protection | Prevent Terraform from deleting folders. Leave this on outside of throwaway test organisations. | `bool` | `true` | no |
| display\_names | Optional display-name overrides, keyed by folder key (for example `{ prod = "Production" }`). | `map(string)` | `{}` | no |
| folders | Top-level folder keys to create under `parent`. The key is used as the display name unless overridden in `display_names`. | `list(string)` | ```[ "bootstrap", "common", "prod", "nonprod", "sandbox" ]``` | no |
| subfolders | Optional second-level folders, keyed by top-level folder key. Example: `{ prod = ["payments", "data"] }`. | `map(list(string))` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| folder\_ids | Top-level folder resource names (`folders/123...`), keyed by folder key. |
| folders | Full folder objects for every folder created, keyed as in `folder_ids` and `subfolder_ids`. |
| subfolder\_ids | Second-level folder resource names, keyed by `<parent key>/<name>`. |
<!-- END_TF_DOCS -->
