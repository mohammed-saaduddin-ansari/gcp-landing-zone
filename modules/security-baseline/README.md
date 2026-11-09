# security-baseline

Organisation-level security plumbing that does not belong to any one project.

* **Security Command Center notifications**: a Pub/Sub topic in the security project and an SCC v2
  notification config that streams active, unmuted HIGH and CRITICAL findings to it, ready for a paging or
  ticketing subscriber. The SCC notification service agent is granted publisher on the topic explicitly.
* **Essential Contacts** at organisation level, so Google's security, billing, legal and suspension notices
  reach group mailboxes rather than whoever created the organisation.

## Security Command Center notes

* Activating SCC (Standard, Premium or Enterprise) is an organisation-level, mostly one-off action done in
  the console, and the tier is a commercial decision; it is not managed here.
* Many Security Health Analytics findings (public buckets, open firewall rules, service account keys,
  external IPs) are prevented outright by the org policy baseline. Expect few of them, and treat any
  that appear as evidence of an exception that needs a review.
* Use SCC mute rules for accepted risks instead of filtering them out of the notification, so the decision
  is recorded in SCC itself.

## Usage

```hcl
module "security" {
  source = "../../modules/security-baseline"

  org_id     = "123456789012"
  project_id = "prj-c-security-1a2b"

  essential_contacts = {
    "gcp-security@example.com" = ["SECURITY", "TECHNICAL_INCIDENTS"]
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
| [google_essential_contacts_contact.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/essential_contacts_contact) | resource |
| [google_pubsub_topic.scc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.scc_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_scc_v2_organization_notification_config.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/scc_v2_organization_notification_config) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| org\_id | Numeric organisation ID. | `string` | n/a | yes |
| project\_id | Central security project that owns the findings topic. | `string` | n/a | yes |
| essential\_contacts | Organisation-level Essential Contacts: email => notification categories. Use group mailboxes, not individuals, so notifications survive people leaving. | `map(list(string))` | `{}` | no |
| essential\_contacts\_language | Language tag for Essential Contacts notifications. | `string` | `"en-GB"` | no |
| labels | Labels applied to the findings topic. | `map(string)` | `{}` | no |
| scc\_notifications | Stream Security Command Center findings to Pub/Sub for paging or ticketing. Requires Security Command Center to be activated for the organisation, which is done once in the console and is not managed here. The default filter forwards active, unmuted HIGH and CRITICAL findings only. | ```object({ enabled = optional(bool, true) config_id = optional(string, "high-and-critical-findings") topic_name = optional(string, "scc-findings") filter = optional(string, "state = \"ACTIVE\" AND mute ! = \"MUTED\" AND (severity = \"HIGH\" OR severity = \"CRITICAL\")") message_retention = optional(string, "604800s") kms_key_name = optional(string) })``` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| essential\_contacts | Essential Contacts created, keyed by email. |
| scc\_notification\_config | Resource name of the SCC notification config, or null when disabled. |
| scc\_topic\_id | ID of the Pub/Sub topic that receives SCC findings, or null when disabled. |
<!-- END_TF_DOCS -->
