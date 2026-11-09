# Smoke test of the whole stage against a mocked provider: proves the modules wire together and that the
# baseline lands where it should. No credentials or backend needed (`terraform init -backend=false`).
mock_provider "google" {
  mock_resource "google_folder" {
    defaults = {
      name = "folders/100000000001"
    }
  }
}

variables {
  org_id                 = "123456789012"
  billing_account        = "012345-6789AB-CDEF01"
  quota_project          = "prj-b-seed-1a2b"
  directory_customer_ids = ["C0abc1234"]
  project_ids = {
    logging  = "prj-c-logging-1a2b"
    security = "prj-c-security-1a2b"
  }
  groups = {
    org_admins      = "gcp-organization-admins@example.com"
    billing_admins  = "gcp-billing-admins@example.com"
    network_admins  = "gcp-network-admins@example.com"
    security_admins = "gcp-security-admins@example.com"
    auditors        = "gcp-auditors@example.com"
    developers      = "gcp-developers@example.com"
  }
}

run "org_stage_plans" {
  command = plan

  assert {
    condition     = length(module.folders.folder_ids) == 4
    error_message = "Expected common, prod, nonprod and sandbox folders."
  }

  assert {
    condition     = contains(module.org_policies.list_policy_names, "organizations/123456789012/policies/iam.allowedPolicyMemberDomains")
    error_message = "Domain-restricted sharing must be enforced at organisation level."
  }

  assert {
    condition     = module.org_policies.boolean_policies["iam.disableServiceAccountKeyCreation"]
    error_message = "Service account key creation must be blocked."
  }

  assert {
    condition     = length(module.sandbox_policies.list_policy_names) == 1 && length(module.sandbox_policies.boolean_policies) == 0
    error_message = "Sandbox should carry exactly one exception."
  }

  assert {
    condition     = module.org_firewall.rule_priorities["deny-internet-admin-ports"] > module.org_firewall.rule_priorities["allow-iap-tcp-forwarding"]
    error_message = "IAP must be allowed before internet SSH/RDP is denied."
  }
}

run "optional_archive" {
  command = plan

  variables {
    log_archive = {
      bucket_name    = "example-org-audit-archive"
      location       = "EU"
      retention_days = 2557
    }
  }

  assert {
    condition     = module.logging.archive_bucket == "example-org-audit-archive"
    error_message = "Archive bucket should be created when log_archive is set."
  }
}
