# Stage 0: bootstrap

Run once, by a person with Organisation Administrator and Billing Account User, from a workstation:

```bash
gcloud auth application-default login
cp terraform.tfvars.example terraform.tfvars   # fill in the placeholders
terraform init
terraform apply
cp backend.tf.example backend.tf
terraform init -migrate-state -backend-config="bucket=$(terraform output -raw state_bucket)"
```

Each later stage gets two CI identities:

| Identity | Roles | Who can impersonate it |
| --- | --- | --- |
| `tf-<stage>-plan` | read-only at organisation level, `objectViewer` on state | any workflow in the repository (pull request plans, run with `-lock=false`) |
| `tf-<stage>` | what the stage needs to change things, `objectAdmin` on state | only jobs running in the GitHub environment `<stage>` (`apply_environments = true`, the default) |

Then record the outputs as GitHub Actions variables (not secrets; none of them is sensitive):
`GCP_WIF_PROVIDER` from `workload_identity_provider`, `TF_STATE_BUCKET` from `state_bucket`, and
`GCP_SA_<STAGE>_PLAN` from `ci_service_accounts`. Create GitHub environments named `org`, `networking` and
`projects` with required reviewers and a `main`-only deployment rule.

After this, the person who ran the bootstrap no longer needs standing organisation-wide access: later stages
run as their CI identities.

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
| bootstrap | ../../modules/bootstrap | n/a |
| bootstrap\_folder | ../../modules/resource-hierarchy | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | Billing account ID (`XXXXXX-XXXXXX-XXXXXX`). | `string` | n/a | yes |
| github\_repository | Repository (`owner/name`) whose workflows may deploy the landing zone. | `string` | n/a | yes |
| org\_id | Numeric organisation ID. | `string` | n/a | yes |
| seed\_project\_id | Globally unique ID for the seed project. | `string` | n/a | yes |
| state\_bucket\_name | Globally unique name for the Terraform state bucket. | `string` | n/a | yes |
| apply\_environments | When true, each stage's CI identity is bound to the GitHub environment of the same name (subject `repo:<owner/name>:environment:<stage>`) instead of to the whole repository, so only jobs that passed that environment's protection rules can impersonate it. Requires matching GitHub environments. | `bool` | `true` | no |
| labels | Labels for bootstrap resources. | `map(string)` | `{}` | no |
| state\_bucket\_location | Location of the state bucket. | `string` | `"EU"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| backend\_configs | Backend bucket and prefix for each later stage. |
| bootstrap\_folder\_id | Folder that holds the seed project. |
| ci\_service\_accounts | CI service account per stage. Store each as a GitHub Actions variable. |
| seed\_project\_id | Seed project ID; use it as `quota_project` in later stages. |
| state\_bucket | Terraform state bucket for all stages. |
| workload\_identity\_provider | WIF provider resource name. Store as the GitHub Actions variable GCP\_WIF\_PROVIDER. |
<!-- END_TF_DOCS -->
