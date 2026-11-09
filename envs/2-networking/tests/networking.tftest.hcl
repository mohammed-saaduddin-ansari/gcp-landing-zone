mock_provider "google" {}

variables {
  billing_account      = "012345-6789AB-CDEF01"
  quota_project        = "prj-b-seed-1a2b"
  network_admins_group = "gcp-network-admins@example.com"
  folder_ids = {
    prod    = "folders/100000000002"
    nonprod = "folders/100000000003"
  }
  environments = {
    prod = {
      host_project_id = "prj-p-net-host-1a2b"
      network_name    = "vpc-prod"
      psc_endpoint_ip = "10.255.255.10"
      subnets = {
        sb-prod-ew2-app = { region = "europe-west2", ip_cidr_range = "10.10.0.0/20" }
        sb-prod-ew1-app = { region = "europe-west1", ip_cidr_range = "10.10.32.0/20" }
      }
    }
    nonprod = {
      host_project_id = "prj-n-net-host-1a2b"
      network_name    = "vpc-nonprod"
      psc_endpoint_ip = "10.255.255.20"
      subnets = {
        sb-nonprod-ew2-app = { region = "europe-west2", ip_cidr_range = "10.20.0.0/20", flow_sampling = 0.1 }
      }
    }
  }
}

run "one_host_project_and_vpc_per_environment" {
  command = plan

  assert {
    condition     = length(module.shared_vpc) == 2 && length(module.psc) == 2
    error_message = "Expected a Shared VPC and a PSC endpoint per environment."
  }

  assert {
    condition     = module.host_projects.projects["prj-p-net-host-1a2b"].folder_id == "folders/100000000002"
    error_message = "Prod host project should live in the prod folder."
  }

  assert {
    condition     = output.host_projects["nonprod"] == "prj-n-net-host-1a2b"
    error_message = "host_projects output is wrong."
  }
}
