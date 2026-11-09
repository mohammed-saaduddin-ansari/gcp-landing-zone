# Exercises the YAML-to-module translation using the example files in projects/.
mock_provider "google" {
  mock_resource "google_project" {
    defaults = {
      number = "100000000042"
    }
  }
}

variables {
  billing_account = "012345-6789AB-CDEF01"
  quota_project   = "prj-b-seed-1a2b"
  folder_ids = {
    prod    = "folders/100000000002"
    nonprod = "folders/100000000003"
    sandbox = "folders/100000000004"
  }
  host_projects = {
    prod    = "prj-p-net-host-1a2b"
    nonprod = "prj-n-net-host-1a2b"
  }
}

run "yaml_projects_are_loaded" {
  command = plan

  assert {
    condition     = length(local.projects) == 3
    error_message = "Expected the three example project definitions."
  }

  assert {
    condition     = local.projects["prj-p-payments-api-1a2b"].folder_id == "folders/100000000002"
    error_message = "Folder key should resolve to the folder ID."
  }

  assert {
    condition     = local.projects["prj-p-payments-api-1a2b"].shared_vpc.subnets == ["projects/prj-p-net-host-1a2b/regions/europe-west2/subnetworks/sb-prod-ew2-app"]
    error_message = "region/subnet reference should resolve to a subnet ID in the environment's host project."
  }

  assert {
    condition     = local.projects["prj-s-data-sandbox-1a2b"].shared_vpc == null
    error_message = "Sandbox project should not be attached to a Shared VPC."
  }

  assert {
    condition     = local.vpc_sc_projects == ["prj-p-payments-api-1a2b"]
    error_message = "Only projects with vpc_sc: true belong in the perimeter."
  }

  assert {
    condition     = length(module.vpc_sc) == 0
    error_message = "VPC Service Controls must be off by default."
  }
}

run "vpc_sc_dry_run" {
  command = apply

  variables {
    vpc_sc = {
      enabled          = true
      access_policy_id = "123456789"
    }
  }

  assert {
    condition     = output.vpc_sc_perimeter.mode == "dry_run"
    error_message = "Perimeter should start in dry-run."
  }

  assert {
    condition     = output.vpc_sc_perimeter.name == "accessPolicies/123456789/servicePerimeters/prod_data"
    error_message = "Unexpected perimeter name."
  }
}
