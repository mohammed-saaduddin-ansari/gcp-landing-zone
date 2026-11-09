# bootstrap

Creates what every other stage depends on:

* a **seed project** (no default network, deletion-protected) that holds state and CI identities and
  is used as the quota project for API calls;
* a **Terraform state bucket** with versioning, uniform bucket-level access, public access prevention,
  a bounded number of noncurrent versions for rollback and optional CMEK;
* one **CI service account per stage**, each with only the organisation and billing roles its stage needs;
* a **workload identity pool and GitHub OIDC provider**, so GitHub Actions gets short-lived credentials and no
  service account key ever exists.

## How the GitHub trust works

1. The provider only accepts tokens whose `repository` claim is in `github_repositories`
   (`attribute_condition`). Tokens from any other repository are rejected before IAM is consulted.
2. Each service account is impersonable either by any workflow in its repository (principal set on
   `attribute.repository`) or, when `wif_subjects` is set, only by tokens with an exact `sub` claim such as
   `repo:owner/name:environment:org`. The second form ties apply rights to a GitHub environment, with its
   required reviewers and branch rules.

## Usage

```hcl
module "bootstrap" {
  source = "../../modules/bootstrap"

  org_id              = "123456789012"
  folder_id           = "folders/222222222222"
  billing_account     = "012345-6789AB-CDEF01"
  project_id          = "prj-b-seed-1a2b"
  state_bucket_name   = "example-org-tfstate-1a2b"
  github_repositories = ["mohammed-saaduddin-ansari/gcp-landing-zone"]

  service_accounts = {
    org = {
      display_name = "Terraform CI: org"
      repository   = "mohammed-saaduddin-ansari/gcp-landing-zone"
      wif_subjects = ["repo:mohammed-saaduddin-ansari/gcp-landing-zone:environment:org"]
      org_roles    = ["roles/resourcemanager.folderAdmin", "roles/orgpolicy.policyAdmin"]
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
| [google_billing_account_iam_member.ci](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_account_iam_member) | resource |
| [google_iam_workload_identity_pool.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_organization_iam_member.ci](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/organization_iam_member) | resource |
| [google_project.seed](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_iam_member.ci_service_usage](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.seed](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.ci](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.wif](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.ci_state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | Billing account ID in the form `XXXXXX-XXXXXX-XXXXXX`. | `string` | n/a | yes |
| folder\_id | Folder that will hold the seed project (`folders/123...`), normally the `bootstrap` folder. | `string` | n/a | yes |
| github\_repositories | GitHub repositories (`owner/name`) allowed to exchange OIDC tokens through the workload identity pool. Any token from another repository is rejected by the provider's attribute condition. | `list(string)` | n/a | yes |
| org\_id | Numeric organisation ID. | `string` | n/a | yes |
| project\_id | ID of the seed project that holds Terraform state and the CI identities. | `string` | n/a | yes |
| service\_accounts | CI service accounts, typically a read-only `plan` and a read-write `apply` identity per stage, so each pipeline holds only the roles it needs. `wif_subjects` binds the account to exact OIDC subjects (for example `repo:owner/name:environment:org`); when empty, the account is bound to every workflow in `repository`. `state_bucket_role` is `roles/storage.objectAdmin` for identities that write state and `roles/storage.objectViewer` for plan-only identities (which then run `terraform plan -lock=false`). `state_prefix` is informational and is surfaced in the outputs for backend configuration. | ```map(object({ display_name = string repository = string wif_subjects = optional(list(string), []) org_roles = optional(list(string), []) billing_roles = optional(list(string), []) state_bucket_role = optional(string, "roles/storage.objectAdmin") state_prefix = optional(string) }))``` | n/a | yes |
| state\_bucket\_name | Globally unique name of the Terraform state bucket. | `string` | n/a | yes |
| activate\_apis | APIs enabled on the seed project. The CI identities use this project for quota, so it needs every API the later stages call. | `list(string)` | ```[ "accesscontextmanager.googleapis.com", "billingbudgets.googleapis.com", "cloudbilling.googleapis.com", "cloudresourcemanager.googleapis.com", "compute.googleapis.com", "dns.googleapis.com", "essentialcontacts.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "logging.googleapis.com", "orgpolicy.googleapis.com", "pubsub.googleapis.com", "securitycenter.googleapis.com", "serviceusage.googleapis.com", "storage.googleapis.com", "sts.googleapis.com" ]``` | no |
| labels | Labels applied to the seed project and state bucket. | `map(string)` | `{}` | no |
| state\_bucket\_kms\_key | Optional Cloud KMS key for CMEK on the state bucket. Null uses Google-managed encryption. | `string` | `null` | no |
| state\_bucket\_location | Location of the state bucket. A multi-region or dual-region keeps state readable through a regional outage. | `string` | `"EU"` | no |
| state\_versions\_to\_keep | Number of noncurrent state object versions kept for rollback before they are deleted. | `number` | `50` | no |
| workload\_identity\_pool\_id | ID of the workload identity pool. | `string` | `"github"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| backend\_configs | Suggested GCS backend settings per stage, for `terraform init -backend-config=...`. |
| seed\_project\_id | Seed project ID. |
| seed\_project\_number | Seed project number. |
| service\_account\_emails | CI service account emails, keyed by stage. |
| state\_bucket | Name of the Terraform state bucket. |
| workload\_identity\_provider | Full resource name of the WIF provider; pass it to google-github-actions/auth as `workload_identity_provider`. |
<!-- END_TF_DOCS -->
