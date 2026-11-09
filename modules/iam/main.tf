# Additive (non-authoritative) grants only. Authoritative IAM at organisation or folder level would
# silently remove grants made by Google-managed service agents and by break-glass procedures; see
# docs/DECISIONS.md (ADR-006).

locals {
  org = merge([
    for role, members in var.org_bindings : {
      for m in members : "${role}|${m}" => { role = role, member = m }
    }
  ]...)

  folder = merge(flatten([
    for label, f in var.folder_bindings : [
      for role, members in f.bindings : {
        for m in members : "${label}|${role}|${m}" => { folder = f.folder, role = role, member = m }
      }
    ]
  ])...)

  project = merge(flatten([
    for label, p in var.project_bindings : [
      for role, members in p.bindings : {
        for m in members : "${label}|${role}|${m}" => { project = p.project, role = role, member = m }
      }
    ]
  ])...)

  all_roles = concat(
    [for b in values(local.org) : b.role],
    [for b in values(local.folder) : b.role],
    [for b in values(local.project) : b.role],
  )
}

resource "google_organization_iam_member" "this" {
  for_each = local.org

  org_id = var.org_id
  role   = each.value.role
  member = each.value.member

  lifecycle {
    precondition {
      condition     = var.org_id != null
      error_message = "org_id is required for organisation-level bindings."
    }
    precondition {
      condition     = !contains(var.denied_roles, each.value.role)
      error_message = "Role ${each.value.role} is on the denied list; use predefined or custom roles instead."
    }
  }
}

resource "google_folder_iam_member" "this" {
  for_each = local.folder

  folder = each.value.folder
  role   = each.value.role
  member = each.value.member

  lifecycle {
    precondition {
      condition     = !contains(var.denied_roles, each.value.role)
      error_message = "Role ${each.value.role} is on the denied list; use predefined or custom roles instead."
    }
  }
}

resource "google_project_iam_member" "this" {
  for_each = local.project

  project = each.value.project
  role    = each.value.role
  member  = each.value.member

  lifecycle {
    precondition {
      condition     = !contains(var.denied_roles, each.value.role)
      error_message = "Role ${each.value.role} is on the denied list; use predefined or custom roles instead."
    }
  }
}
