locals {
  # Organisation-specific list constraints are only added when the caller supplies values.
  derived_list_policies = merge(
    length(var.allowed_policy_member_domains) > 0 ? {
      "iam.allowedPolicyMemberDomains" = {
        allow               = var.allowed_policy_member_domains
        deny                = []
        allow_all           = false
        deny_all            = false
        inherit_from_parent = false
      }
    } : {},
    length(var.allowed_resource_locations) > 0 ? {
      "gcp.resourceLocations" = {
        allow               = var.allowed_resource_locations
        deny                = []
        allow_all           = false
        deny_all            = false
        inherit_from_parent = false
      }
    } : {},
  )

  # Explicit entries in list_policies win over the derived ones.
  list_policies = merge(local.derived_list_policies, var.list_policies)
}

resource "google_org_policy_policy" "boolean" {
  for_each = var.boolean_policies

  name   = "${var.parent}/policies/${each.key}"
  parent = var.parent

  spec {
    rules {
      enforce = each.value ? "TRUE" : "FALSE"
    }
  }
}

resource "google_org_policy_policy" "list" {
  for_each = local.list_policies

  name   = "${var.parent}/policies/${each.key}"
  parent = var.parent

  spec {
    inherit_from_parent = each.value.inherit_from_parent ? true : null

    rules {
      allow_all = each.value.allow_all ? "TRUE" : null
      deny_all  = each.value.deny_all ? "TRUE" : null

      dynamic "values" {
        for_each = length(each.value.allow) + length(each.value.deny) > 0 ? [1] : []
        content {
          allowed_values = length(each.value.allow) > 0 ? each.value.allow : null
          denied_values  = length(each.value.deny) > 0 ? each.value.deny : null
        }
      }
    }
  }
}
