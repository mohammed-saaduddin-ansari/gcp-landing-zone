# Project definitions

One YAML file per project. The file name is only for humans; `project_id` is what matters.

```yaml
project_id: prj-p-payments-api      # required, globally unique, 6-30 chars
name: Payments API - prod           # optional; 4-30 chars, letters, digits, spaces, - ' " !
folder: prod                        # required, a key of folder_ids (prod, nonprod, sandbox, ...)
labels:                             # environment, owner and cost_centre are required
  environment: prod
  owner: payments
  cost_centre: cc-1234
services:                           # APIs to enable
  - container.googleapis.com
iam:                                # groups only; basic roles are rejected
  roles/container.developer:
    - group:payments-devs@example.com
budget:                             # optional; monthly, alerts at 50/90/100% actual and 100% forecast
  amount: 2500
  currency_code: GBP                # must match the billing account's currency
shared_vpc:                         # optional; attaches to the host project of `folder`
  subnets:
    - europe-west2/sb-prod-ew2-app  # region/subnet-name
  network_users:
    - group:payments-devs@example.com
vpc_sc: true                        # optional; include in the VPC Service Controls perimeter
```

Adding a project is a pull request that adds one file. CI runs `terraform plan` for the stage and a reviewer
from the platform team approves it.
