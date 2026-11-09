# Stage 0 is applied once by a human organisation administrator using their own credentials
# (`gcloud auth application-default login`). Every later stage runs as a CI service account created here.
provider "google" {
  default_labels = {
    managed_by = "terraform"
    stage      = "bootstrap"
  }
}
