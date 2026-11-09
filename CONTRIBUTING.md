# Contributing

Issues and pull requests are welcome. This is a reference implementation, so changes that make a decision
clearer or safer are more valuable than changes that add options.

## Before opening a pull request

```bash
pre-commit install          # once
make lint                   # fmt-check, validate, tflint, checkov, docs check
make test                   # terraform test against mocked providers; no credentials needed
make docs                   # if you changed variables or outputs
```

CI runs the same checks. The `plan` job only runs where the repository has workload identity federation set
up, so it is skipped on forks.

## Conventions

* **Modules** live in `modules/<name>/` with `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, a
  `README.md` (hand-written intro and usage, generated inputs and outputs) and `tests/*.tftest.hcl`.
* **Every variable and output has a description and a type.** TFLint enforces this.
* **Validate at the boundary.** Reject bad input in variable `validation` blocks or `lifecycle`
  preconditions with a message that says how to fix it, and add an `expect_failures` test for it.
* **Tests use `mock_provider "google"`** and must run offline. When the provider validates a mocked computed
  value (IAM members, for example), give the mock a realistic default.
* **`for_each` keys must be known at plan time.** Use static labels in keys and put apply-time values in the
  map values.
* **Groups only** for human access; no `roles/owner` or `roles/editor`.
* **New checkov skips** go in `.checkov.yaml` with a reason, and in the table in `docs/ARCHITECTURE.md`.
* **Significant design changes** get an ADR in `docs/DECISIONS.md`.
* British spelling in prose; Google's spelling in API names and identifiers.

## Commit messages

Conventional-commit style prefixes (`feat`, `fix`, `docs`, `ci`, `chore`) with the module or stage in
parentheses, for example `fix(project-factory): ...`. Explain why in the body when it is not obvious.
