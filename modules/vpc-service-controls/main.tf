locals {
  policy_id = var.create_access_policy ? google_access_context_manager_access_policy.this[0].name : var.access_policy_id
  dry_run   = var.mode == "dry_run"
  # Placeholder keeps the names renderable so the precondition below can report a missing policy clearly.
  policy_ref = coalesce(local.policy_id, "unset")

  config = {
    resources           = var.resources
    restricted_services = var.restricted_services
    access_levels       = var.access_levels
  }
}

resource "google_access_context_manager_access_policy" "this" {
  count = var.create_access_policy ? 1 : 0

  parent = "organizations/${var.org_id}"
  title  = "Organisation access policy"

  lifecycle {
    precondition {
      condition     = var.org_id != null
      error_message = "org_id is required when create_access_policy is true."
    }
  }
}

resource "google_access_context_manager_service_perimeter" "this" {
  parent         = "accessPolicies/${local.policy_ref}"
  name           = "accessPolicies/${local.policy_ref}/servicePerimeters/${var.perimeter_name}"
  title          = var.perimeter_name
  perimeter_type = "PERIMETER_TYPE_REGULAR"
  description    = "Managed by Terraform. Mode: ${var.mode}."

  # In dry-run the configuration lives only in `spec`; `status` (enforcement) stays empty.
  use_explicit_dry_run_spec = local.dry_run

  dynamic "spec" {
    for_each = local.dry_run ? [local.config] : []
    content {
      resources           = spec.value.resources
      restricted_services = spec.value.restricted_services
      access_levels       = spec.value.access_levels

      dynamic "vpc_accessible_services" {
        for_each = var.restrict_vpc_accessible_services ? [1] : []
        content {
          enable_restriction = true
          allowed_services   = ["RESTRICTED-SERVICES"]
        }
      }
    }
  }

  dynamic "status" {
    for_each = local.dry_run ? [] : [local.config]
    content {
      resources           = status.value.resources
      restricted_services = status.value.restricted_services
      access_levels       = status.value.access_levels

      dynamic "vpc_accessible_services" {
        for_each = var.restrict_vpc_accessible_services ? [1] : []
        content {
          enable_restriction = true
          allowed_services   = ["RESTRICTED-SERVICES"]
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = local.policy_id != null
      error_message = "Set access_policy_id, or set create_access_policy = true."
    }
  }
}
