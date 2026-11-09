# In CI, google-github-actions/auth exchanges the GitHub OIDC token for this stage's service account, so no
# impersonation is configured. Locally, set impersonate_service_account to run as the same identity.
provider "google" {
  impersonate_service_account = var.impersonate_service_account

  # Bill API quota (budgets, org policy, Essential Contacts) to the seed project, not to the caller.
  billing_project       = var.quota_project
  user_project_override = true

  default_labels = {
    managed_by = "terraform"
    stage      = "org"
  }
}
