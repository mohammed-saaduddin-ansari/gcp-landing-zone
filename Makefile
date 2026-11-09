# Local entry points. CI (.github/workflows/ci.yml) runs the same targets.
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help
help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

.PHONY: fmt
fmt: ## Format all Terraform files in place
	terraform fmt -recursive

.PHONY: fmt-check
fmt-check: ## Fail if any Terraform file is not formatted
	terraform fmt -recursive -check -diff

.PHONY: validate
validate: ## terraform init -backend=false && terraform validate in every module and stage
	scripts/validate.sh

.PHONY: tflint
tflint: ## TFLint with the terraform and google rulesets
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	tflint --recursive --config "$(CURDIR)/.tflint.hcl" --format compact

.PHONY: checkov
checkov: ## Checkov static security analysis (skips documented in .checkov.yaml)
	checkov --config-file .checkov.yaml

.PHONY: lint
lint: fmt-check validate tflint checkov docs-check ## All static checks

.PHONY: test
test: ## terraform test against mocked providers (no credentials needed)
	scripts/test.sh

.PHONY: docs
docs: ## Regenerate module and stage READMEs with terraform-docs
	scripts/docs.sh

.PHONY: docs-check
docs-check: ## Fail if a generated README section is out of date
	scripts/docs.sh --check

.PHONY: clean
clean: ## Remove local .terraform directories
	find . -type d -name .terraform -prune -exec rm -rf {} +
