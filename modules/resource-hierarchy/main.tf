locals {
  # Second-level folders flattened to "<parent key>/<name>" so they can be addressed in for_each.
  subfolders = merge([
    for parent_key, names in var.subfolders : {
      for name in names : "${parent_key}/${name}" => {
        parent_key = parent_key
        name       = name
      }
    }
  ]...)
}

resource "google_folder" "top" {
  for_each = toset(var.folders)

  display_name        = lookup(var.display_names, each.key, each.key)
  parent              = var.parent
  deletion_protection = var.deletion_protection
}

resource "google_folder" "sub" {
  for_each = local.subfolders

  display_name        = each.value.name
  parent              = try(google_folder.top[each.value.parent_key].name, "undefined")
  deletion_protection = var.deletion_protection

  lifecycle {
    precondition {
      condition     = contains(var.folders, each.value.parent_key)
      error_message = "Subfolder parent \"${each.value.parent_key}\" is not one of the top-level folders."
    }
  }
}
