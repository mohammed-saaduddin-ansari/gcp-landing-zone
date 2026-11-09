mock_provider "google" {}

variables {
  parent = "organizations/123456789012"
}

run "baseline_is_enforced" {
  command = plan

  assert {
    condition     = google_org_policy_policy.boolean["iam.disableServiceAccountKeyCreation"].spec[0].rules[0].enforce == "TRUE"
    error_message = "Service account key creation must be blocked by the baseline."
  }

  assert {
    condition     = google_org_policy_policy.list["compute.vmExternalIpAccess"].spec[0].rules[0].deny_all == "TRUE"
    error_message = "External IPs on VMs must be denied by the baseline."
  }

  assert {
    condition     = google_org_policy_policy.boolean["storage.publicAccessPrevention"].name == "organizations/123456789012/policies/storage.publicAccessPrevention"
    error_message = "Policy names must be <parent>/policies/<constraint>."
  }

  # Org-specific constraints are opt-in.
  assert {
    condition     = !contains(keys(google_org_policy_policy.list), "iam.allowedPolicyMemberDomains")
    error_message = "Domain restriction must not be created without customer IDs."
  }
}

run "domain_restriction_and_locations" {
  command = plan

  variables {
    allowed_policy_member_domains = ["C0abc1234"]
    allowed_resource_locations    = ["in:eu-locations"]
  }

  assert {
    condition     = google_org_policy_policy.list["iam.allowedPolicyMemberDomains"].spec[0].rules[0].values[0].allowed_values == tolist(["C0abc1234"])
    error_message = "Domain restriction should allow only the given customer ID."
  }

  assert {
    condition     = google_org_policy_policy.list["gcp.resourceLocations"].spec[0].rules[0].values[0].allowed_values == tolist(["in:eu-locations"])
    error_message = "Resource locations should be restricted to the EU value group."
  }
}

run "folder_level_exception" {
  command = plan

  variables {
    parent           = "folders/987654321098"
    boolean_policies = { "compute.requireOsLogin" = false }
    list_policies    = { "compute.vmExternalIpAccess" = { allow_all = true } }
  }

  assert {
    condition     = google_org_policy_policy.boolean["compute.requireOsLogin"].spec[0].rules[0].enforce == "FALSE"
    error_message = "Exception should explicitly disable enforcement."
  }

  assert {
    condition     = google_org_policy_policy.list["compute.vmExternalIpAccess"].spec[0].rules[0].allow_all == "TRUE"
    error_message = "Sandbox exception should allow all external IPs."
  }

  assert {
    condition     = length(google_org_policy_policy.boolean) == 1
    error_message = "Only the overridden constraint should be managed at folder level."
  }
}

run "rejects_ambiguous_list_policy" {
  command = plan

  variables {
    list_policies = { "compute.vmExternalIpAccess" = { allow_all = true, deny_all = true } }
  }

  expect_failures = [var.list_policies]
}

run "rejects_domain_names_for_customer_ids" {
  command = plan

  variables {
    allowed_policy_member_domains = ["example.com"]
  }

  expect_failures = [var.allowed_policy_member_domains]
}
