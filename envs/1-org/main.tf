locals {
  common_labels = {
    environment = "common"
    owner       = "platform"
    cost_centre = "platform"
  }

  audit_filter = <<-EOT
    log_id("cloudaudit.googleapis.com/activity") OR
    log_id("cloudaudit.googleapis.com/system_event") OR
    log_id("cloudaudit.googleapis.com/policy") OR
    log_id("cloudaudit.googleapis.com/data_access") OR
    log_id("cloudaudit.googleapis.com/access_transparency")
  EOT
}

# --- Resource hierarchy ---------------------------------------------------------------------------

module "folders" {
  source = "../../modules/resource-hierarchy"

  parent  = "organizations/${var.org_id}"
  folders = ["common", "prod", "nonprod", "sandbox"]
}

# --- Organisation policies --------------------------------------------------------------------------

module "org_policies" {
  source = "../../modules/org-policies"

  parent                        = "organizations/${var.org_id}"
  allowed_policy_member_domains = var.directory_customer_ids
  allowed_resource_locations    = var.allowed_resource_locations
}

# Sandbox is for experiments: allow external IPs on VMs there. Everything else is inherited.
module "sandbox_policies" {
  source = "../../modules/org-policies"

  parent           = module.folders.folder_ids["sandbox"]
  boolean_policies = {}
  list_policies = {
    "compute.vmExternalIpAccess" = { allow_all = true }
  }
}

# --- Shared projects in the common folder -------------------------------------------------------------

module "common_projects" {
  source = "../../modules/project-factory"

  billing_account = var.billing_account

  projects = {
    (var.project_ids.logging) = {
      name      = "Central logging"
      folder_id = module.folders.folder_ids["common"]
      labels    = local.common_labels
      services  = ["logging.googleapis.com", "storage.googleapis.com"]
      iam       = { "roles/logging.viewer" = ["group:${var.groups.auditors}", "group:${var.groups.security_admins}"] }
    }
    (var.project_ids.security) = {
      name      = "Security tooling"
      folder_id = module.folders.folder_ids["common"]
      labels    = local.common_labels
      services  = ["pubsub.googleapis.com", "securitycenter.googleapis.com"]
      iam       = { "roles/pubsub.viewer" = ["group:${var.groups.security_admins}"] }
    }
  }
}

# --- Centralised logging --------------------------------------------------------------------------

module "logging" {
  source = "../../modules/logging"

  org_id     = var.org_id
  project_id = module.common_projects.projects[var.project_ids.logging].project_id

  log_buckets = {
    audit = {
      location       = var.default_region
      retention_days = var.audit_log_retention_days
      description    = "Organisation-wide audit logs."
    }
    network = {
      location       = var.default_region
      retention_days = 30
      description    = "VPC flow logs, firewall and Cloud NAT logs for troubleshooting."
    }
  }

  sinks = {
    org-audit = {
      log_bucket = "audit"
      filter     = local.audit_filter
    }
    org-network = {
      log_bucket = "network"
      filter     = <<-EOT
        log_id("compute.googleapis.com/vpc_flows") OR
        log_id("compute.googleapis.com/firewall") OR
        log_id("compute.googleapis.com/nat_flows")
      EOT
    }
  }

  archive = var.log_archive == null ? null : {
    bucket_name    = var.log_archive.bucket_name
    location       = var.log_archive.location
    retention_days = var.log_archive.retention_days
    lock_retention = var.log_archive.lock_retention
    filter         = local.audit_filter
  }
}

# --- Security baseline -----------------------------------------------------------------------------

module "security" {
  source = "../../modules/security-baseline"

  org_id             = var.org_id
  project_id         = module.common_projects.projects[var.project_ids.security].project_id
  essential_contacts = var.essential_contacts
}

# --- Organisation firewall policy -------------------------------------------------------------------

module "org_firewall" {
  source = "../../modules/firewall-policy"

  parent             = "organizations/${var.org_id}"
  short_name         = "org-baseline"
  description        = "Organisation-wide firewall baseline. Anything not matched here is delegated to VPC rules."
  attachment_targets = ["organizations/${var.org_id}"]

  rules = {
    allow-iap-tcp-forwarding = {
      priority       = 1000
      direction      = "INGRESS"
      action         = "allow"
      description    = "SSH and RDP through Identity-Aware Proxy TCP forwarding."
      src_ip_ranges  = ["35.235.240.0/20"]
      layer4         = [{ protocol = "tcp", ports = ["22", "3389"] }]
      enable_logging = true
    }
    allow-google-health-checks = {
      priority      = 1100
      direction     = "INGRESS"
      action        = "allow"
      description   = "Google Cloud load balancer health checks."
      src_ip_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
      layer4        = [{ protocol = "tcp" }]
    }
    deny-internet-admin-ports = {
      priority       = 2000
      direction      = "INGRESS"
      action         = "deny"
      description    = "No SSH or RDP from anywhere else, whatever VPC rules say."
      src_ip_ranges  = ["0.0.0.0/0"]
      layer4         = [{ protocol = "tcp", ports = ["22", "3389"] }]
      enable_logging = true
    }
  }
}

# --- IAM: groups only ---------------------------------------------------------------------------------

module "iam" {
  source = "../../modules/iam"

  org_id = var.org_id

  org_bindings = {
    "roles/resourcemanager.organizationAdmin" = ["group:${var.groups.org_admins}"]
    "roles/resourcemanager.folderAdmin"       = ["group:${var.groups.org_admins}"]
    "roles/orgpolicy.policyAdmin"             = ["group:${var.groups.org_admins}"]
    "roles/billing.viewer"                    = ["group:${var.groups.billing_admins}"]
    "roles/compute.xpnAdmin"                  = ["group:${var.groups.network_admins}"]
    "roles/compute.networkViewer"             = ["group:${var.groups.network_admins}", "group:${var.groups.security_admins}"]
    "roles/securitycenter.admin"              = ["group:${var.groups.security_admins}"]
    "roles/iam.securityReviewer"              = ["group:${var.groups.security_admins}", "group:${var.groups.auditors}"]
    "roles/logging.viewer"                    = ["group:${var.groups.auditors}"]
    "roles/resourcemanager.organizationViewer" = [
      "group:${var.groups.auditors}",
      "group:${var.groups.developers}",
    ]
  }

  folder_bindings = {
    nonprod = {
      folder   = module.folders.folder_ids["nonprod"]
      bindings = { "roles/viewer" = ["group:${var.groups.developers}"] }
    }
    sandbox = {
      folder = module.folders.folder_ids["sandbox"]
      bindings = {
        "roles/resourcemanager.projectCreator" = ["group:${var.groups.developers}"]
      }
    }
  }
}
