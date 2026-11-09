locals {
  # Roles per stage. A starting point sized to what each stage's Terraform actually manages; review them
  # against your organisation before applying. Granted at organisation level for simplicity; see
  # docs/DECISIONS.md (ADR-004) for the folder-scoped alternative.
  stages = {
    org = {
      display_name = "Terraform CI: 1-org"
      org_roles = [
        "roles/compute.orgFirewallPolicyAdmin",
        "roles/compute.orgSecurityResourceAdmin",
        "roles/essentialcontacts.admin",
        "roles/iam.securityAdmin",
        "roles/logging.configWriter",
        "roles/orgpolicy.policyAdmin",
        "roles/pubsub.admin",
        "roles/resourcemanager.folderAdmin",
        "roles/resourcemanager.projectCreator",
        "roles/securitycenter.notificationConfigEditor",
        "roles/serviceusage.serviceUsageAdmin",
      ]
      billing_roles = ["roles/billing.user"]
    }
    networking = {
      display_name = "Terraform CI: 2-networking"
      org_roles = [
        "roles/compute.networkAdmin",
        "roles/compute.xpnAdmin",
        "roles/dns.admin",
        "roles/resourcemanager.projectCreator",
        "roles/serviceusage.serviceUsageAdmin",
      ]
      billing_roles = ["roles/billing.user"]
    }
    projects = {
      display_name = "Terraform CI: 3-projects"
      org_roles = [
        "roles/accesscontextmanager.policyEditor",
        "roles/compute.xpnAdmin",
        "roles/resourcemanager.projectCreator",
        "roles/resourcemanager.projectIamAdmin",
        "roles/serviceusage.serviceUsageAdmin",
      ]
      billing_roles = ["roles/billing.user", "roles/billing.costsManager"]
    }
  }

  # Read-only roles for the plan identity of every stage. Pull request plans run as these identities with
  # `terraform plan -lock=false`, so an unreviewed branch can read the estate but never change it.
  plan_org_roles = [
    "roles/accesscontextmanager.policyReader",
    "roles/browser",
    "roles/essentialcontacts.viewer",
    "roles/iam.securityReviewer",
    "roles/logging.viewer",
    "roles/orgpolicy.policyViewer",
    "roles/securitycenter.notificationConfigViewer",
    "roles/viewer",
  ]

  identities = merge(
    # Apply identities: bound to the GitHub environment of the stage when apply_environments is true.
    {
      for stage, cfg in local.stages : stage => merge(cfg, {
        repository        = var.github_repository
        wif_subjects      = var.apply_environments ? ["repo:${var.github_repository}:environment:${stage}"] : []
        state_bucket_role = "roles/storage.objectAdmin"
        state_prefix      = stage
      })
    },
    # Plan identities: any workflow in the repository, read-only everywhere.
    {
      for stage, cfg in local.stages : "${stage}-plan" => {
        display_name      = "${cfg.display_name} (plan, read-only)"
        repository        = var.github_repository
        wif_subjects      = []
        org_roles         = local.plan_org_roles
        billing_roles     = ["roles/billing.viewer"]
        state_bucket_role = "roles/storage.objectViewer"
        state_prefix      = stage
      }
    },
  )
}

module "bootstrap_folder" {
  source = "../../modules/resource-hierarchy"

  parent  = "organizations/${var.org_id}"
  folders = ["bootstrap"]
}

module "bootstrap" {
  source = "../../modules/bootstrap"

  org_id                = var.org_id
  folder_id             = module.bootstrap_folder.folder_ids["bootstrap"]
  billing_account       = var.billing_account
  project_id            = var.seed_project_id
  labels                = merge(var.labels, { environment = "bootstrap" })
  state_bucket_name     = var.state_bucket_name
  state_bucket_location = var.state_bucket_location
  github_repositories   = [var.github_repository]

  service_accounts = local.identities
}
