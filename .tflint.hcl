# TFLint configuration shared by every module and environment.
# Run from the repository root: `tflint --init && tflint --recursive --config "$(pwd)/.tflint.hcl"`

config {
  # Lint module calls as well as the root module.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.41.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Every variable and output must be documented: terraform-docs builds the module READMEs from them.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_standard_module_structure" {
  enabled = true
}
