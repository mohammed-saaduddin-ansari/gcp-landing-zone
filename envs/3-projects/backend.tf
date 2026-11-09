# Partial configuration: terraform init -backend-config=backend.hcl (see backend.hcl.example).
terraform {
  backend "gcs" {}
}
