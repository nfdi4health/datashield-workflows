# v1 planning round (2026-10-16)

The user's plan for the next days, discussed item by item. **Planning
only, nothing built.** Details live in the notes linked per item.

Order: decisions and infrastructure design → move/rename + `v1` (one
round of caller changes) → refactoring → new workflows.

## 1. Move, rename, versioning, testing

- Transfer `FlorianSchw/package-workflows` → **`nfdi4health/datashield-workflows`**
  (the user does the transfer). One repo for everything; DataSHIELD vs.
  other use is a counting dimension, set by an explicit input.
- Branch model main / dev / feature; default branch `main`; automatic
  semantic-release on merge into `main` (`vX.Y.Z` plus a moving `v1`).
  Only `dev` may merge into `main` (own `require-head-branch.yml`).
- **Prerequisite:** workflows use actions and scripts from their own
  commit (`.shared-workflows` copied by the `shared-files` action — not a checkout at `github.job_workflow_sha`, which is empty — and local action
  paths) — else `@v1` and self-tests run `main`'s code.
- **Testing:** actionlint, zizmor, shellcheck; testthat (Claude mocked)
  and bats; self-test workflows on **made-up fixture packages only**
  (plain R package, DataSHIELD client/server pair, dsAnalysis project)
  with recorded Claude answers — all on every PR and push. A real-Claude
  smoke test (one call per kind, 5 calls, ~$0.30–1) on PRs into `main`
  (required by the `main` ruleset) and monthly. Federation rules for
  the repo's own tests match by prefix (`@refs/pull/<n>/merge`); its own
  test runs are not counted.
  - **Built (branch `v1/foundation`):** `ci.yml` (testthat, shell tests,
    actionlint, shellcheck, zizmor; green since `e3db7a6`). End-to-end
    runs of `suggest_roxygen.R` and `suggest_tests.R` on the made-up
    `tests/fixtures/r-package` with recorded answers
    (`tests/fixtures/claude-answers/r-package.json`, by tool name, in call
    order), in-process via `run_entry_script_mocked()` (httr2's mocking:
    Claude gets the recorded answer, GitHub a 404) —
    `test-entry-scripts.R`. Naming check/apply run end to end on the
    `ds-client`/`ds-server` pair.
  - Authors bot end to end too (git commits in the fixture, recorded
    GitHub API answers).
  - **Decided 2026-10-19 (user):** the workflow-level self-test gets a
    hidden test input (e.g. `self-test-fixture: r-package`, empty for
    callers): fixture instead of the caller checkout, recorded answers
    instead of the token step, no push or PR. The smoke test's
    federation rule is created at the move, for
    `nfdi4health/datashield-workflows` directly. **Built** the same day:
    `self-test.yml` (roxygen, tests, authors; analysis not yet).
  - **Still to build:** the analysis bot end to end (needs DSLite +
    dsBase in CI — heavier; the stepwise logic is unit-tested), the
    workflow-level
    self-test (the reusable workflows themselves on a fixture: needs a
    way to point them at a fixture instead of the caller checkout and to
    skip the token step and the push — a test-only input or a
    `CLAUDE_REPLAY` env; to decide with the user, as it touches the
    workflows' interface). The smoke test with real calls needs a
    federation rule for this repository.

## 2. Secrets

No change for now: callers keep mapping their secrets (App or PAT).
Federation rules per GitHub owner (all its repos, one rule per workflow),
not per repo. Other organisations bring their own Anthropic organization.

## 3. Subscription vs. API

Others trigger → API with WIF. Only the user triggers (implementer,
researcher, refactor agent) → the user's subscription from a central
private agent repo. See [claude-subscription-auth.md](claude-subscription-auth.md)
and [issue-agents.md](issue-agents.md).

## 4. KPI repo

Private `nfdi4health/datashield-kpi-reporting`; collector moves there;
raw counts first; fresh counting at v1. See
[usage-counting.md](usage-counting.md).

## 5. Infrastructure as code (Anthropic + GitHub secrets)

- **Where:** the user's existing private governance repo (rulesets),
  extended — "GitHub and Anthropic configuration as code". Agents never
  run there (they read untrusted issue text); the KPI repo stays
  separate (others may get access).
- **Anthropic side:** a YAML (workspaces, service accounts, one
  federation rule per workflow per owner) reconciled by a script through
  the Admin API: create what's missing, report differences, delete
  nothing without confirmation. Only the user's own Anthropic
  organization.
  - Service accounts and federation rules need an **`org:admin` OAuth
    token** (an Admin API key can't manage them). In CI via **WIF**: one
    federation rule with `oauth_scope: org:admin`, created once in the
    Console, accepting only `main` of the governance repo in the
    `anthropic-admin` environment. No stored key; tokens live minutes.
  - No permission subsets for admin tokens; the boundary is who can get
    one (the rule). Payment and spend settings aren't in the Admin API;
    **spend limits per workspace stay a one-time Console setting** and
    cap the damage of the main abuse path (someone creating a rule for
    their own repo).
  - Rules can't be edited, only archived and recreated → **new IDs** →
    callers' secrets change; the script reports which, and the GitHub
    side can write them. The repo move needs new rules anyway.
- **GitHub side:** secrets and variables of the user's repos from the
  same YAML; a fine-grained PAT (Secrets: write, Variables: write,
  selected repos, with expiry) in the `github-admin` environment.
- **Triggers:** PR → checks without any credentials (no admin token on
  PR branches); push to `main` → apply (the merge of the user's own PR is
  the approval); manual run as an alternative. A required reviewer on the
  environments is optional.
- **Security:** 2FA (passkey) on GitHub and the Anthropic Console; one
  environment per credential; actions pinned to commit SHAs; manual and
  `main` triggers only, no untrusted input; ruleset on `main`: PRs only,
  no force push or deletion, **signed commits** (the user wants signing;
  today the user pushes over HTTPS with a PAT — SSH signing works
  independently: a key used only for signing, registered on GitHub as a
  signing key; set up when the governance repo is built).

**Checked against Anthropic's docs (2026-10-20)** — corrections to the
above:
- Federation rules **can be updated** (`POST /v1/organizations/federation_rules/{id}`:
  `match`, `target`, `name`, scope, workspaces; only `issuer_id` is
  fixed). IDs stay stable, so neither the move nor a wider match changes
  callers' secrets.
- A prefix match on `job_workflow_ref` is a CEL `condition`
  (`claims.job_workflow_ref.startsWith("<repo>/.github/workflows/<file>@")`);
  `claims` are exact only. Rules on GitHub's shared issuer must also pin
  the tenant (`repo:<owner>/…` subject prefix or `repository_owner`).
- Only an `org:admin` OAuth token works on these endpoints (no Admin API
  key). The workload's token can manage only `workspace:developer` /
  `workspace:inference` rules and developer-role service accounts; the
  `org:admin` bootstrap rule (admin service account, subject pinned to
  the governance repo's `main` exactly, a dedicated issuer recommended)
  is made in the Console once.
- GitHub OIDC tokens carry `jti`: one exchange per token.

**Decided 2026-10-20 (user): governance repo first** (order b): its
first run widens dsSupportClient's existing rules to a prefix match, then
the CI test round. Scripts in R, not bash (user). Work in
`repo-governance` on a feature branch.

**Outcome 2026-10-21: the Anthropic side stays manual.** Built and run
(federated `org:admin` rule, token exchange succeeded), but every Admin
API call answered 404 (403 for workspaces), also with the user's own
`ant auth login` token: the Admin API is unavailable for individual
Anthropic accounts ("Florian's Individual Org"), and converting to a team
organization is not an option (user). Should have been checked first.
The script was removed; `anthropic/config.json` in repo-governance stays
as the hand-kept record of all service accounts, rules and IDs, the
README there describes how a rule is set up by hand. Rules are changed in
the Console. Revisit only if the bots move to a team or institute
organization (e.g. at the move to nfdi4health).

**Drafts** (not applied): rulesets for `main`, `dev` and `v*` tags, this
repository's own PR-check caller and release (`v` tags, moving `v1`),
and the governance YAML structure — [v1-drafts/](v1-drafts/README.md).

## 6. Refactoring — all before v1 (user's decision)

From [claude-workflow-review.md](claude-workflow-review.md) and the open
items, **all of A–J before v1**:

- **A** Self-contained workflows (actions and scripts from their own
  commit) — prerequisite for `@v1` and the self-tests.
- **B** Review all inputs once (names such as `sweep-base` that no longer
  fit, descriptions, defaults); `datashield` input for authors.
  Proposal (8 changes, for the user): [v1-input-review.md](v1-input-review.md).
- **C** Config files: all YAML, all merged key by key over the defaults
  (today JSON/YAML mixed, most overrides replace the whole file).
- **D** The policy file `config/suggestion-policy.yml` (reasons,
  thresholds, report routing).
  C and D proposal (for the user): [v1-config-proposal.md](v1-config-proposal.md),
  draft file [v1-drafts/suggestion-policy.yml](v1-drafts/suggestion-policy.yml).
- ~~**E** `strict: true` for all Claude calls (drops the analysis bot's
  "array as JSON string" workaround).~~ Done (`f3ef6a7`).
- ~~**F** Failure classification once per function, plus an R pre-check for
  obvious failures.~~ Done (`f3ef6a7`).
- ~~**G** One `claude` object instead of global variables.~~ Done
  (`407431b`).
- ~~**H** Merge the two R-file parsers (`parse_r_file()`,
  `read_r_definitions()`).~~ Done: `read_r_definitions()` and
  `roxygen_params()` moved to `shared/`; `parse_r_file()` and
  `package_function_names()` find definitions through it (R's parser
  instead of a column-0 regex), keeping `parse_r_file()`'s output for the
  write-back (minus the unused `fn_header`). A file that doesn't parse
  now counts as having no function (warning). Tests in
  `test-shared-parse.R`.
- ~~**I** Test and roxygen main loops as functions; shared skeleton.~~
  Done: `review_files()` (shared loop: parse, review, sum stats and
  changed files) with `review_roxygen_file()` / `review_test_file()` as
  the per-file step, each taking a `ctx` list instead of the entry
  script's variables; `try_claude_call()` (failed call → warning +
  retry note, shared); the test bot's per-test-file loop is
  `apply_function_test_changes()`, `run_quietly` is
  `run_tests_quietly()`. The entry scripts keep setup and reporting.
  Tests with made-up Claude answers in `test-roxygen-bot.R` and
  `test-test-bot.R` (`local_global_mock()` in the helper). Behaviour
  unchanged except the failed-call log line of the test bot, which now
  names `fn()` like its warning.
- **J** Review prompts and context; remove hard-coded workarounds — e.g.
  `ds.glmSLMA` / forest plots are both prose in
  `analysis-script-prompt.md` and `excluded_functions` in
  `analysis-suggest.yml`: exclusions only in config, each with a reason,
  written into the prompt by R. Start with a systematic prompt audit
  (outdated rules, instructions the schema or R already enforce,
  duplicates, context sent but unused).
  ~~Step 1 done: [prompt-audit.md](prompt-audit.md) — 9 findings, 6 with
  proposed hunks (A–F), nothing applied. Step 2 (choose hunks, test
  before/after in the CI round) needs the user; hunk B depends on C.~~
  **Done 2026-10-26:** hunks A–F applied (2026-10-19) and run in the CI
  test round (2026-10-21, roxygen and tests on dsSupportClient, no
  regressions seen); second pass (prompts, R special cases, context
  sizes) found nothing further — details at the end of
  [prompt-audit.md](prompt-audit.md). Flags 7–9 stay, each with the
  condition to revisit.

## 7. New workflows — after v1 (user's decision)

None before v1: they build on the refactored foundation, and they are
the first real use of the new branch model (feature → dev → main,
release). Order: label integrity → learning loop (collecting only) →
issue triage → spec review → central agent repo with implementer,
researcher, refactor agent. Design in [issue-agents.md](issue-agents.md).
