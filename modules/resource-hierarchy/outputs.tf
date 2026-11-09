output "folder_ids" {
  description = "Top-level folder resource names (`folders/123...`), keyed by folder key."
  value       = { for k, f in google_folder.top : k => f.name }
}

output "subfolder_ids" {
  description = "Second-level folder resource names, keyed by `<parent key>/<name>`."
  value       = { for k, f in google_folder.sub : k => f.name }
}

output "folders" {
  description = "Full folder objects for every folder created, keyed as in `folder_ids` and `subfolder_ids`."
  value       = merge(google_folder.top, google_folder.sub)
}
