# Architecture decision records

Each record states the context, the decision, the alternatives considered and the consequences, including
the ones that hurt. Status is `Accepted` unless noted.

| ADR | Decision |
| --- | --- |
| [001](#adr-001-stage-based-compositions-with-separate-state) | Stage-based compositions with separate state |
| [002](#adr-002-environment-folders-and-a-shallow-hierarchy) | Environment folders and a shallow hierarchy |
| [003](#adr-003-keyless-ci-with-workload-identity-federation-and-planapply-identities) | Keyless CI with workload identity federation and plan/apply identities |
| [004](#adr-004-ci-roles-granted-at-organisation-level-for-now) | CI roles granted at organisation level, for now |
| [005](#adr-005-shared-vpc-per-environment-no-hub-yet) | Shared VPC per environment, no hub yet |
| [006](#adr-006-group-only-additive-iam) | Group-only, additive IAM |
| [007](#adr-007-aggregated-organisation-sinks-into-cloud-logging-buckets) | Aggregated organisation sinks into Cloud Logging buckets |
| [008](#adr-008-preventive-guardrails-first-detective-controls-second-vpc-sc-in-dry-run) | Preventive guardrails first, VPC-SC in dry-run |

---

## ADR-001: Stage-based compositions with separate state

**Context.** A landing zone has resources that change a few times a year (folders, org policies) and
resources that change weekly (projects). Changing both in one state means every project request plans the
whole organisation, needs organisation-wide permissions and risks organisation-wide damage.

**Decision.** Four compositions under `envs/` (bootstrap, org, networking, projects), each with its own state
prefix and its own CI identities. Outputs are passed forward explicitly as tfvars (`folder_ids`,
`host_projects`).

**Alternatives.**
* *One root module.* Simplest, but has the blast radius and privilege problems above, and plans get slow.
* *Per-environment roots* (`envs/prod`, `envs/nonprod`) each containing everything. Good isolation between
  environments but duplicates organisation-wide resources or forces an extra shared root anyway.
* *`terraform_remote_state` between stages.* Saves copying IDs, but gives each stage read access to the
  whole state of the previous stage, which may contain sensitive values, and couples them at plan time.
  Explicit inputs are reviewable in a pull request and keep stages independently testable.

**Consequences.** Four pipelines and some copying of outputs into tfvars when upstream stages change (rare).
Order matters on first build. A mistake in `3-projects` cannot touch folders or org policies.

---

## ADR-002: Environment folders and a shallow hierarchy

**Context.** Org policies, firewall policies and IAM inherit through the resource hierarchy, so folder
structure decides where controls can differ.

**Decision.** Top-level folders `bootstrap`, `common`, `prod`, `nonprod`, `sandbox`, with optional
second-level folders for business units. No deeper nesting by default.

**Alternatives.**
* *Business unit first, environment second* (`payments/prod`). Fits organisations whose units are largely
  autonomous, but environment-wide controls then have to be repeated per unit.
* *Separate organisations per environment.* Strongest isolation, but doubles identity, billing and policy
  administration. Justified only for regulatory separation.
* *Deep hierarchies.* Every level is another place an inherited policy or grant can come from, which makes
  "why can this person do that?" slow to answer.

**Consequences.** Environment-wide differences (sandbox exceptions, developer access to nonprod) are one
folder-level change. Business-unit differences need subfolders, which the module supports.

---

## ADR-003: Keyless CI with workload identity federation and plan/apply identities

**Context.** Terraform for a landing zone runs with some of the most powerful credentials in the
organisation. Service account keys are long-lived bearer credentials that get copied into CI secrets,
laptops and occasionally logs, and are hard to rotate.

**Decision.**
* GitHub Actions authenticates through a workload identity pool with a GitHub OIDC provider. The provider's
  `attribute_condition` accepts only an explicit allow-list of repositories.
* Each stage has two service accounts. `tf-<stage>-plan` has read-only roles, can only read state, and can be
  impersonated by any workflow in the repository, which is what pull request plans need. `tf-<stage>` has
  write roles and can only be impersonated by the exact subject
  `repo:<owner>/<repo>:environment:<stage>`, which GitHub issues only after the environment's protection
  rules pass.
* `iam.disableServiceAccountKeyCreation` and `iam.disableServiceAccountKeyUpload` are enforced so no key can
  be created as a workaround.
* Federated principals impersonate service accounts rather than being granted roles directly.

**Alternatives.**
* *Service account keys in CI secrets.* Rejected for the reasons above.
* *Direct resource access for federated principals* (no service account). Fewer moving parts, but not every
  API accepts federated principals, and a named service account per stage is easier to audit and reason
  about.
* *One identity for plan and apply.* Simpler, but then any branch that can run a workflow holds write
  credentials.

**Consequences.** Six CI service accounts instead of three. Pull request plans run with `-lock=false`,
because plan identities cannot write the lock object; this is safe because they never write state. Every
stage still has bucket-wide access to the state bucket, so a stage identity could read another stage's
state. Per-stage buckets or IAM conditions on object prefixes would close that gap and are on the roadmap.

---

## ADR-004: CI roles granted at organisation level, for now

**Context.** Each stage identity needs permission to manage its resources. Those resources sit under
different folders, and some (org policies, sinks, firewall policy) are organisation-level by nature.

**Decision.** Grant each stage identity a list of predefined roles at organisation level, sized to what the
stage manages (for example the networking identity gets `compute.networkAdmin`, `compute.xpnAdmin` and
`dns.admin`, but not `orgpolicy.policyAdmin`). Billing roles are granted on the billing account.

**Alternatives.**
* *Folder-scoped grants* (networking identity only on `prod` and `nonprod`). Tighter, but needs the folders
  to exist before the grants, which reorders bootstrap and stage 1, and some roles (Shared VPC admin) must
  be held at organisation or folder level anyway.
* *Custom roles* with exactly the permissions used. Tightest, but expensive to maintain as provider versions
  add API calls, and failures show up as opaque permission errors mid-apply.

**Consequences.** The identities hold more than they strictly need. The mitigations are the apply-identity
binding (ADR-003), separate identities per stage, and audit logs attributing every change. Moving to
folder-scoped and custom roles is on the roadmap once the stages are stable.

---

## ADR-005: Shared VPC per environment, no hub yet

**Context.** Workloads need private connectivity, controlled egress, private access to Google APIs and
consistent DNS. Teams want autonomy; security wants one place to look.

**Decision.** One Shared VPC host project per environment, owned by the network team. Service projects attach
to their environment's host and receive `compute.networkUser` on named subnets only. Cloud NAT per region,
PSC for Google APIs, DNS query logging. No connectivity between environments, and no hub.

**Alternatives.**
* *A VPC per project.* Maximum team autonomy, but every project needs its own NAT, DNS, firewall hygiene and
  private access set-up, and connecting them later hits VPC peering's non-transitivity and peering-group
  limits.
* *One Shared VPC for all environments.* Fewer resources, but prod and nonprod then share a routing domain,
  firewall rules and failure blast radius.
* *Hub-and-spoke with VPC peering and network virtual appliances.* Needed when traffic must pass a
  third-party firewall, but it costs appliance licences and operations, and peering is not transitive.
* *Network Connectivity Center with VPC spokes.* The preferred hub when one is needed: transitive routing
  between spokes and a single place for hybrid routes, without appliances.

**Consequences.** The network team is on the critical path for new subnets, and host project quotas (for
example subnet IP space and firewall rule counts) are shared by every service project in an environment.
When hybrid connectivity arrives, NCC can be added without renumbering because the address plan does not
overlap.

---

## ADR-006: Group-only, additive IAM

**Context.** Granting roles to individual users in Terraform turns joiners and leavers into pull requests and
leaves stale access when people move on. Authoritative IAM resources (`*_iam_policy`, `*_iam_binding`)
replace whatever else is on the node.

**Decision.**
* Humans get access only through groups managed in Cloud Identity or Workspace. The `iam` and
  `project-factory` modules reject any member that is not `group:`.
* `roles/owner` and `roles/editor` are rejected.
* All grants use additive `*_iam_member` resources.
* Service accounts get roles from the module that creates them, not from the `iam` module.

**Alternatives.**
* *Authoritative bindings per role.* Terraform becomes the single source of truth and drift is removed,
  which is attractive at project level. At organisation or folder level it can silently remove grants that
  Google service agents rely on, or a break-glass grant made during an incident.

**Consequences.** Access added outside Terraform is not removed automatically, so it must be detected
instead: IAM Recommender, Policy Analyzer and SCC findings. Group membership becomes the real access-control
surface and needs its own review process.

---

## ADR-007: Aggregated organisation sinks into Cloud Logging buckets

**Context.** Investigators need audit logs from every project in one place, protected from the people being
investigated, kept for a defined period and still available after a project is deleted.

**Decision.**
* Organisation-level aggregated sinks with `include_children = true` route logs into log buckets in a
  dedicated logging project under `common`.
* Separate buckets by purpose and retention: audit logs 400 days, network logs (flow, firewall, NAT) 30
  days.
* Writer identities are granted `logging.bucketWriter` with a condition limiting each to its own bucket.
* Optional Cloud Storage archive with a retention policy for long compliance windows.
* Data Access audit logs are opt-in per service because of volume and cost.

**Alternatives.**
* *Per-project sinks.* Project owners could remove them, and new projects would need them added.
* *BigQuery as the primary destination.* Powerful SQL, but needs a dataset schema strategy and partition
  management, and retention is managed as table expiry. Log Analytics on log buckets gives SQL when needed
  without a second copy.
* *Pub/Sub to a SIEM.* Right when a SIEM exists; the sink module can be extended with a Pub/Sub destination.
  Not assumed here.

**Consequences.** Logs are stored twice (the project's own `_Default` bucket and the central bucket) for
whatever the project's retention is. `_Default` exclusions in projects can reduce that. Locking a bucket or
archive is irreversible, so it is off by default and left to whoever owns compliance.

---

## ADR-008: Preventive guardrails first, detective controls second, VPC-SC in dry-run

**Context.** Controls that prevent a misconfiguration are cheaper than controls that detect it afterwards,
but a prevention that blocks legitimate work gets bypassed or removed.

**Decision.**
* Enforce a baseline of organisation policies at the organisation node (no SA keys, no public buckets, no
  external IPs, no default networks, OS Login, no serial ports, private Cloud SQL, internal-only protocol
  forwarding). Domain-restricted sharing and resource locations are enforced when the organisation supplies
  its values.
* Grant exceptions at folders, never projects, and keep each exception to the single constraint being
  relaxed (the `sandbox` folder allows external IPs).
* Use SCC for detection, streaming HIGH and CRITICAL findings to Pub/Sub. Accepted risks are muted in SCC,
  not filtered out of the stream.
* Ship VPC Service Controls as an optional module that defaults to dry-run, because an enforced perimeter
  with a missing ingress rule breaks CI, consoles and integrations immediately.

**Alternatives.**
* *Detective-only (SCC and alerts).* Every finding needs a human; the backlog grows faster than it is worked.
* *Enforce VPC-SC from day one.* Safer on paper, but the usual outcome is an emergency rollback and a
  perimeter nobody trusts.
* *Custom constraints for everything.* Precise, but each one is code to maintain. They are on the roadmap for
  cases the predefined constraints do not cover.

**Consequences.** Some legitimate patterns need a folder exception (for example a VM appliance that must
forward IP traffic). Several baseline constraints are already enforced by Google's secure-by-default policies
for new organisations; declaring them explicitly costs nothing and keeps older organisations consistent.
