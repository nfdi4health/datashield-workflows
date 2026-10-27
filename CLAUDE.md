# Project: package-workflows

## WHAT THIS REPO IS
Public, shared GitHub Actions repo used by repos across three GitHub accounts
(personal `FlorianSchw`, and two orgs — `nfdi4health` is one). Holds reusable
`workflow_call` workflows so CI/release/doc-assist logic is written once and
called from thin per-repo "caller" workflow files, rather than copy-pasted
per repo.

**Critical operational fact:** changes here only take effect for callers once
pushed to `main` (or whichever ref a caller pins to). A caller referencing
`@main` picks up the latest commit on next run — there is no separate "deploy"
step. When debugging a caller's behavior, always confirm which commit the
workflow run actually used before assuming a fix did or didn't work; a run
can be stale relative to what's currently on `main` if it started before a
push landed.

**Test bed:** `nfdi4health/dsSupportClient` (a DataSHIELD client package) is
the live caller used to validate changes before wider rollout.

## LAYOUT

- `.github/workflows/` — reusable workflows:
  - `r-cmd-check.yml` — R CMD check matrix + optional codecov upload.
    Inputs: `os-list`, `r-version-list` (JSON array strings; default
    release + oldrel-1/2), `run-codecov`, `extra-apt-packages`,
    `extra-r-packages` (plain names, `any::` added internally).
  - `package-release.yml` — semantic-release. Uses a caller-root
    `.releaserc.json` if present, else this repo's `.releaserc.json`
    from the workflow's own commit (`config-repo` / `config-ref` removed on
    `v1/foundation`, 2026-10-19). Pushes with the
    `resolve-push-token` App token → `commit-push-pat` → `GITHUB_TOKEN`.
    The shared config drafts the release and turns off the GitHub
    plugin's comments, labels and failure issue, so the App needs no
    Issues permission.
  - `trigger-release-publish.yml` — sends a `repository_dispatch`
    (`event_type: release-publish`) to the caller repo; the caller's own
    workflow listens for it and runs the release.
  - `merge-pull-request.yml` — merges a PR via `gh pr merge`. No PAT needed
    (`release` runs via `needs:`, not a fresh `push` event).
  - `require-head-branch.yml` — fails a PR whose head branch isn't
    `allowed-head` (e.g. only `dev` may merge into `main`).
  - `create-issue.yml` — opens an issue on check failure from
    `.github/pr-issue-template.md`.
  - `commitlint.yml` — conventional-commit lint using
    `config/commitlint-config.mjs`.
  - `authors-suggest.yml` — resolves each PR commit's author to
    their GitHub profile name and credits them in `DESCRIPTION` via a
    `bot-suggest/authors` sub-PR: `aut` if any of their commits changed
    `R/*.R`, else `ctb`; an existing `ctb` is upgraded to `aut`, nobody is
    downgraded or removed, other roles stay. Merge commits don't count.
    Reasons go into the sub-PR body (`suggestion_report.md`). Needs a
    caller trigger on all PRs (no `paths` filter), or tests/docs-only
    contributors are never seen. Bots are skipped per
    `config/bot-authors.yml` (overridable, merged, see `read_config_yaml()`
    below). New people: name split by `split_person_name()` (last word +
    particles like `van`/`de` = family; one-word names flagged). Matching
    (`find_author()`): commit e-mail (noreply ignored; e-mails are never
    written) or name ignoring case/accents/punctuation/order; same family +
    initial is only reported as "may already be listed" — in the sub-PR
    body, or via `comment_once()` on the PR if nothing else changed.
    `desc` writes `Authors@R` in its standard (tidyverse) format — a
    hand-formatted field is normalized once; deliberately not customized.
  - `roxygen-suggest.yml`, `test-suggest.yml` — LLM-assisted
    suggestion workflows; see below.
  - `cleanup-suggestion-branch.yml` — on PR close, deletes a `bot-suggest/*`
    head branch unless another open PR still uses it.
  - `suggestion-choices.yml` — on `pull_request: edited` of a roxygen or
    test bot PR by a person: makes the bot branch match the checkboxes in
    its description (keep, decline, or pick up a not-applied suggestion),
    no Claude call. Entry script `R/apply_suggestion_choices.R`, functions
    in `R/functions/choices/`; design in
    [dev-notes/suggestion-choices.md](dev-notes/suggestion-choices.md).
  - `workflow-keepalive.yml` — wraps `liskin/gh-workflow-keepalive@v1`
    (user's choice over custom `gh api` code). Inside a reusable workflow
    `GITHUB_WORKFLOW_REF` is the caller's, so it re-enables the calling
    workflow, resetting GitHub's 60-day inactivity timer. Callers add it
    as a job (`if: github.event_name == 'schedule'`) to each scheduled
    workflow.
  - `workflow-graphs.yml` — Mermaid diagrams of the caller's workflows in
    `.github/workflow-graphs/README.md` — high level only: a summary
    table and one diagram per situation (what runs when, what it
    produces, under which condition). Deterministic from the YAML,
    reading called reusable workflows for chains and conditions; what
    workflows produce comes from `config/workflow-outcomes.yml`. Only the
    marked block is replaced. On push /
    manual run: committed directly via `commit-and-push`; on a PR:
    nothing committed, one short comment that it should run on push
    instead (`comment_once()`); the example caller has no PR trigger. Entry
    script `R/workflow_graphs.R`; design in
    [dev-notes/workflow-graphs.md](dev-notes/workflow-graphs.md).
  - `datashield-analysis-suggest.yml` — for DataSHIELD **analysis
    projects** created with dsAnalysis, not packages. On a push that
    changes the analyst's plan (`config/analysis-plan.yml`), it drafts
    `R/NN_*.R` scripts per plan step. Every DataSHIELD call is checked
    against the installed client functions. All scripts run in
    dsAnalysis's testing mode (DSLite + mock data from the plan), with one
    repair round. What passes is proposed via a `bot-suggest/analysis/*`
    PR; scripts the analyst edited are never overwritten. Entry script
    `R/suggest_datashield_analysis.R`, functions in
    `R/functions/analysis/`, settings `config/analysis-suggest.yml`
    (paths, markers, limits, variable types, …), wording
    `config/analysis-texts.yml`, prompts `prompts/analysis-*.md`. A
    project's own copy of either config is merged over the defaults key
    by key (`read_config_yaml()`), like every config file since v1 (before,
    the others replaced the whole file). Adjustments go there rather than into R.
    Design, marker formats and the dsAnalysis checklist are in
    [dev-notes/analysis-suggest.md](dev-notes/analysis-suggest.md).
  - `ds-naming-check.yml`, `ds-naming-apply.yml` — DataSHIELD argument
    naming harmonisation (internal, kept off the docs until the rules are
    agreed). Run from a client package, which checks out its server
    package. Check: rules (`config/ds-naming-rules.yml`, merged key by key
    via `read_config_yaml()`, now in `shared/`) + Claude for unclear
    arguments → `.github/ds-naming/transformations.yml` in a review PR,
    people set `status: approved|skip`. Apply (on push of that file):
    approved renames via parse data in code/tests/roxygen/Rd/vignette
    chunks, one `refactor!:` PR per repository. Entry scripts
    `R/check_ds_naming.R`, `R/apply_ds_naming.R`, functions in
    `R/functions/ds-naming/`; generic `propose-branch` action. Design and
    state: [dev-notes/datashield-naming/](dev-notes/datashield-naming/README.md).
- This repository's own, non-reusable workflows (besides `ci.yml`,
  `self-test.yml`, `publish-docs.yml`, `collect-usage.yml`): `pr-checks.yml`
  (commit messages on PRs into dev/main, only `dev` into `main`) and
  `release.yml` (semantic-release of this repository: `vX.Y.Z`, moving
  `vX`, CHANGELOG.md, config `.github/release/releaserc.json` copied over
  the root `.releaserc.json` in the runner — the root one is the R-package
  default of `package-release.yml`). `release.yml` only runs once the
  repository variable `RELEASE_ENABLED` is `true` (at v1).
- Branch-protection rulesets (formerly `rulesets/` + `apply-ruleset.yml`)
  now live in a separate private repo.
- `.github/actions/` — composite actions: `anthropic-token` (suggestion
  workflows), `count-run` (usage counting, see below),
  `resolve-suggestion-scope` (roxygen/tests/authors: skip,
  mode and branch from the event; its folder also holds
  `determine-changes.sh`, what is new since the last run, and
  `review-history.sh`, the last review from the run history),
  `resolve-push-token` (also `package-release.yml`),
  `commit-updated-files` (also `authors-suggest.yml`), `commit-and-push`
  (plain commit to the current branch, commit message as input;
  `workflow-graphs.yml`, meant for future generated-file workflows too),
  `propose-branch` (commit a manifest on top of the checkout, force-push
  a fixed branch, open or update its PR; any checkout incl. a second
  repository; the ds-naming workflows). `resolve-push-token` takes
  `repositories` for a token reaching more repositories of the owner.
- `R/` — entry scripts `suggest_roxygen.R`, `suggest_tests.R`,
  `suggest_authors.R`, `workflow_graphs.R`, `suggest_datashield_analysis.R`,
  `check_ds_naming.R`, `apply_ds_naming.R`
  (env/config wiring + main loop only) and `R/functions/` (all logic, one
  function per file), split into `shared/` (config/prompt files, GitHub
  API, report layout, reading R files, the Claude call) and one folder per
  workflow: `roxygen/`, `tests/`, `authors/`, `workflow-graphs/`,
  `analysis/`, `ds-naming/`. Each entry script loads only
  `shared/` plus its own folder (`purrr::walk()`), so a function used by
  two workflows must move to `shared/` — no calls across workflow
  folders (checked on the 2026-09-26 split, again 2026-10-04). **One
  deliberate exception:** `apply_suggestion_choices.R` loads `roxygen/`
  and `tests/` too, because it re-applies their suggestions and rebuilds
  their reports with their own functions. No R inlined in workflow
  YAML.
- `config/`, `prompts/` — guidance, prompt templates and
  Claude call settings for the suggestion workflows.
- `dev-notes/` — internal design notes and status per suggestion workflow
  (not published).
- `tests/` (branch `v1/foundation` until merged) — `testthat/` (R
  functions sourced into the global environment by `helper-load.R`;
  Claude and GitHub answered by stand-ins: `local_global_mock()`,
  `run_entry_script_mocked()` with recorded answers from
  `fixtures/claude-answers/`), `shell/test-scope.sh` (stand-ins for
  `gh`/`jq`), `fixtures/` (made-up packages only: `r-package`,
  `ds-client` + `ds-server`). Run by `ci.yml` with the static checks;
  locally `Rscript tests/testthat.R` and `bash tests/shell/test-scope.sh`.
  `self-test.yml` (not reusable) runs `roxygen-suggest.yml` and
  `test-suggest.yml` and `authors-suggest.yml` themselves with the input `self-test-fixture:
  r-package` (fixture instead of the caller checkout via
  `tests/self-test/use-fixture.sh`, no token, `CLAUDE_RECORDED_ANSWERS`
  → `use_recorded_answers()`, nothing pushed or counted, results as an
  artifact) and checks them with `tests/self-test/check-results.sh`.
  A change to an entry script or a bot's output should keep
  `test-entry-scripts.R` passing (or update its recorded answers).
  External actions are pinned to commit SHAs with the version as a
  comment; Dependabot updates them — pin new ones the same way.
- **Usage counting:** the Claude-assisted workflows (roxygen, tests,
  analysis scripts, naming check) and `authors-suggest.yml` end with a "Count this run"
  step — the composite action `count-run` — that downloads one file from
  the `usage-counter` pre-release, `<workflow>-<outcome>-<channel>`
  (outcome proposed / nothing / failed; channel release = a `vX` tag
  points to the commit that ran, dev = `@main` or a branch, i.e.
  development and testing). Anonymous; the download counts are the runs.
  Only these (user's choice: Claude-assisted + authors). `collect-usage.yml` (not reusable,
  "Usage counter files") keeps the release complete — the files for every
  workflow calling `count-run`, with this repository's own token. The
  daily counts are recorded by the private
  `nfdi4health/datashield-kpi-reporting` (`R/collect_counts.R`, daily
  workflow, `usage.csv` on its `main`), which only reads the public
  release — no credential for this repository there (split, set up
  2026-10-26). On `main` here the old collector still
  writes the `usage-data` branch until v1 is merged; delete that branch
  then.
  **A new Claude-assisted workflow gets the same last step** (copy it,
  with its own `workflow:` name); the collector adds its files. Design:
  [dev-notes/usage-counting.md](dev-notes/usage-counting.md).
- `docs/` — Quarto site, published to GitHub Pages by `publish-docs.yml`
  (non-reusable, like `collect-usage.yml`). One page per workflow, grouped in the
  sidebar via `docs/_quarto.yml` (sections: Getting started, Pull request
  checks, Release, Bot suggestions, Analysis projects, Workflow upkeep;
  Roadmap last, whose "Recent changes" section serves as release notes).
  A long
  page gets sub-pages as a nested sidebar section whose `href` is the main
  page: Test suggestions (`test-suggest-review.qmd`,
  `test-suggest-datashield.qmd`), Under the hood
  (`suggestions-internals-roxygen.qmd`, `…-tests.qmd`), Workflow graphs
  (`workflow-graphs-details.qmd`). The main page keeps what a user needs
  to set it up (what it does, example, inputs/secrets/permissions); the
  background goes to sub-pages. Inputs/secrets/permissions tables are
  generated from the workflow YAML by `docs/_shortcodes/workflow.lua`
  (`wf-inputs`, `wf-secrets`, `wf-permissions`); `example` includes a file
  from `examples/` — generic caller files, `@main`. The tables follow
  workflow changes automatically; page prose, examples and
  `docs/roadmap.qmd` are updated in a batched docs pass when the user asks
  — until then, note what's needed under "Docs pending" in STILL OPEN.
  "Under the hood" (`docs/suggestions-internals.qmd` plus its two
  step-by-step sub-pages) has step diagrams and tables of the R functions
  of the roxygen and test workflows, with source links — update them when
  adding, renaming or removing a function
  in `R/functions/shared/`, `roxygen/` or `tests/` (the links include the
  folder) or changing the order of steps. Preview with
  `quarto preview docs` (`.claude/launch.json` has a `docs` entry).

## SUGGESTION WORKFLOWS — shared mechanics

Details per workflow: [dev-notes/roxygen-suggest.md](dev-notes/roxygen-suggest.md),
[dev-notes/test-suggest.md](dev-notes/test-suggest.md).

- **Auth: WIF, no static API key.** The `anthropic-token` action exchanges
  the job's GitHub OIDC token for a short-lived Anthropic token. Nothing
  is hard-coded: callers pass `anthropic-organization-id`,
  `anthropic-service-account-id` and `anthropic-federation-rule-id` as
  required secrets, so any repo can use its own Anthropic org and pay for
  its own usage. Console layout: one **workspace per workflow type**
  (docs, tests), one **service account per repo** (member of both
  workspaces; the Cost page groups by service account), one **federation
  rule per repo × workflow** (`subject_prefix: repo:<owner>/<repo>:*` plus
  a `claims` matcher on `job_workflow_ref`, targeting the repo's service
  account in that workflow's workspace). Because each workflow needs its
  own rule ID, callers map secrets explicitly — not `secrets: inherit`.
- **Claude settings:** `config/claude.yml` (not a root `config.yml`: R
  packages using the `config` package often have one, which would override
  it), one `default` profile plus one per
  task (`roxygen-review`, `test-review`, `test-failure-classification`),
  read with `claude_settings(profile)` (default merged with the profile;
  no `config` package, no `R_CONFIG_ACTIVE` — since 2026-10-19 on
  `v1/foundation`). Every Claude call goes through
  `call_claude_tool()` (forced tool call; it sets the tool name from config).
- **Claude returns fields, R assembles the output.** Never trust prompt
  wording where a structural constraint (schema field, `maxItems`, enum)
  is possible.
- **Threshold for what gets proposed:** Claude states a reason per change
  from a fixed enum (`suggestion_reasons()`, reasons and their meaning in
  `config/suggestion-policy.yml`), R keeps only the accepted
  ones — the `accept-reasons` input, else those marked `accept: true` in
  the policy file (`accepted_reasons()`) — and adds mechanical
  filters.
  A revisable decision, recorded in
  [dev-notes/suggestion-thresholds.md](dev-notes/suggestion-thresholds.md)
  — update that note when changing it.
- **Where shared files come from:** callers get this repo checked out into
  `.shared-workflows/`. Config files are YAML and read with
  `read_config_yaml("config/x.yml")`: the shared copy with the caller's own
  file at the same path merged over it key by key (lists replaced) — on
  `v1/foundation` since 2026-10-19 for every config (before: only the
  analysis and naming configs; the others replaced the whole file and were
  JSON). Prompt templates are still replaced as a whole
  (`resolve_shared_path()`). `bot-authors.yml` is also read by
  `determine-changes.sh`, merged the same way with `yq`.
- **Committing:** scripts write `updated_files.txt`; `commit-updated-files`
  commits exactly those files. `changed` mode (PR or push; what's new
  since the last run, `determine-changes.sh`):
  - **Bot branch:** per-file commits on `bot-suggest/<kind>/<branch with
    / → ->`, opened as a sub-PR *back into that branch*, never committed
    onto it directly, so its author reviews every suggestion.
  - **An open sub-PR is built on:** the branch is merged in with the
    user's version winning, the run's suggestions are added and pushed
    without force. Roxygen and tests (`pr-body-mode: replace`) rebuild
    the description as one merged report; others append theirs. It
    carries a hidden `reviewed up to <sha>` marker (and for roxygen and
    tests the findings, `<!-- bot-suggest-state: … -->`), plus one
    `retry <file>` line per file whose Claude call failed
    (`note_retry_file()` → `retry_files.txt`); `determine-changes.sh`
    checks those again on the next run, even without new commits.
    Temporary API failures are retried within the run (`req_retry()` in
    `call_claude_tool()`); a call that still fails gives a warning
    annotation (`warn_failed_call()`), the job stays green.
    An access token that expires during a long run is renewed once
    (`refresh_anthropic_token()`, from the IDs the workflows pass to the
    R step as `ANTHROPIC_ORG_ID` / `_SERVICE_ACCOUNT_ID` /
    `_FEDERATION_RULE_ID`); the analysis bot blanks them, and GitHub's
    OIDC request variables, for the analyst's scripts.
  - **Rebuilt** (force-push) when none is open, with
    `open-suggestion-pr: replace`, after a history rewrite, or when the
    merge fails.
  - **Link comment** on the originating PR when the sub-PR is newly
    created and `origin-pr-number` is set.

  `all` mode (full review): checks out and scans the `review-branch` (`sweep-base` until v1; empty: the
  chosen branch on manual runs, `dev` on schedules, since a schedule
  starts on `main`), one commit on `bot-suggest/<kind>-all-<base>-YYYY-MM` (`-sweep-` until v1),
  force-pushed, plus a PR against the base; a re-run in the same month
  updates that month's open PR instead of failing or duplicating it. In
  both modes only an
  *open* PR counts as existing. `resolve-push-token` provides an App
  token when configured, so the bot's PRs trigger the caller's required
  checks (`GITHUB_TOKEN`-created ones don't) — which is why the
  suggestion jobs skip `bot-suggest/*` head branches, so the bot never
  reviews its own PRs. All `bot-suggest/*` branches are removed by
  `cleanup-suggestion-branch.yml` once their PR is merged or closed.
  **Pitfall:** `actions/checkout` stores `GITHUB_TOKEN` as an extra HTTP
  header (`persist-credentials`) that wins over a token in the remote URL.
  Pushes must reset it (`git -c "http.https://github.com/.extraheader="
  push`, `git_push_with_token()` in `commit-updated-files.sh`), otherwise they go
  out as `github-actions` and the PR's workflows need approval / don't
  run (seen on the force push to dsSupportClient PR #25).

## STILL OPEN

The user-facing subset of this list is published in `docs/roadmap.qmd`
(no internal details: other accounts, dsSupportClient, App specifics).
Update it when an item here is added, changed or done. Feedback channel:
issues for now (may change — it is named only in `docs/roadmap.qmd#feedback`
and `CONTRIBUTING.md`); no PRs until a branch model and rules exist.

- ~~Docs pending~~ Done in the docs pass of 2026-09-26: authors page (roles,
  names, matching, `desc` format; no `paths` filter), test page rewritten
  and renamed to `test-suggest.qmd` (redirect from the old URL via
  `aliases`), roxygen report, suggestions page (titles, statistic line,
  existing-test actions, `report-style.yml`), App Client ID in Getting
  started and all examples, roadmap. The dev-note is now
  `dev-notes/test-suggest.md`. Next changes: note them here again as
  "Docs pending".

- ~~**Test bot: generated tests run in the bot's own R process**~~ Done
  (2026-10-14, tested locally, not yet in CI): `run_test_blocks()` runs
  them via `callr::r()` with the variables of `credential_variables()`
  (shared, also used by `run_analysis_scripts()`) blanked; the test-data
  summary's `Rscript` gets them blanked too. The test and analysis
  workflows check out with `persist-credentials: false`, so no token sits
  in `.git/config`; `fetch_bot_branch()` passes `GH_TOKEN` for its one
  fetch when no stored header exists (pushes already use the token in the
  remote URL). Roxygen/authors/naming still persist credentials — they
  run no generated code.

- ~~**Test bot: undeclared packages in generated tests**~~ Done
  (2026-10-14, tested locally, not yet in CI): both. The prompt prefers
  base R, testthat and declared packages; `declare_test_packages()` adds
  packages the proposed test files use (`pkg::`, `library()`,
  `require()`, `requireNamespace()`) to Suggests, proposed with the tests
  (finding kind `dependency`, "added to Suggests: …" in the summary line).
  Docs pending: `test-suggest.qmd` (Suggests additions; tests run without
  credentials).

- **Docs pending** (changes of 2026-10-02, internals pages already done):
  `test-suggest.qmd` "Test files": test files are named after the R file
  (`test-<R file>.R`, `test-<category>-<R file>.R`), not the function;
  suggestions page: failed Claude calls are retried within the run, give
  a warning annotation (job stays green), and are checked again in the
  next run while a bot PR is open (`retry` lines next to the marker).
  Since 2026-10-04 also: a page for `suggestion-choices.yml` (what the
  checkboxes do, the caller, the commit status, declined suggestions
  remembered until the code changes), the suggestions page and the
  roxygen/test pages (reports now have checkboxes), getting started (the
  new caller), the `workflow-graphs` outcomes (`config/workflow-outcomes.yml`)
  and the roadmap.

- Versioning: all workflows are referenced `@main`, and `package-release.yml`
  reads its release config from `main` too. The old `v1` tag is unused.
  **Decided in the v1 planning round (2026-10-16)** — details, and the
  state of the work on branch `v1/foundation`, in
  [dev-notes/v1-planning.md](dev-notes/v1-planning.md):
  - ~~**Branches:** trunk-based — `main` + short-lived feature branches via
    PR, `main` protected (commitlint, `actionlint`). No `dev`: here a
    release is a tag, not a merge into `main`.~~ Replaced: main / dev /
    feature, only `dev` merges into `main`, release on every merge into
    `main` (rulesets drafted in `dev-notes/v1-drafts/`).
  - **Releases:** semantic-release tags `vX.Y.Z` and moves the major tag
    `vX`; callers pin `@v1`; breaking changes (`feat!:`) become `v2`.
  - **Testing:** dsSupportClient points a caller at `@<feature-branch>`.
  - ~~**Prerequisite:** all internal references are hard-coded to `main`~~
    Done on branch `v1/foundation` (2026-10-16, not yet run from a
    caller): composite actions are referenced with GitHub's
    **self-repository syntax** `uses: $/.github/actions/…` — resolves to
    the file's own repository at the running commit, no checkout
    (changelog 2026-07-30; runner ≥ 2.336.0, not on GHES; no `@ref`).
    ~~`.shared-workflows` (R scripts, config, prompts) is checked out at
    `github.job_workflow_sha`~~ — **that context property is empty**
    (first test-round run, dsSupportClient PR #46, 2026-10-21: the authors
    bot got `main`'s files, `bot-authors.json` instead of `.yml`), and
    actions/checkout then silently takes the default branch. **Fixed
    2026-10-21:** the composite action `shared-files` (`uses:
    $/.github/actions/shared-files`, after the caller's checkout, which
    would clean the workspace) copies this repository from its own action
    folder — the runner fetches it at the running commit — into
    `.shared-workflows` (`package-release.yml`: `.shared-config`;
    `create-issue.yml` reads its template from there); `count-run` reads
    the commit from its folder name. Not yet confirmed in CI. Inline
    `${{ }}` in `run:` scripts moved into `env:`; checkouts
    `persist-credentials: false` (pushes and fetches pass their token;
    now none keeps it); App tokens request only contents +
    pull-requests. The repo name `FlorianSchw/package-workflows` is still
    hard-coded in `count-run.sh` (change at the move). actionlint (1.7.12)
    predates `$/`: `ci.yml` ignores that message.
  - **Federation rules** match `job_workflow_ref` exactly (incl.
    `@refs/heads/main`); tags need a prefix/condition match.
  - **Usage counting** relies on it: runs on a `vX` tag count as
    `release`, everything else as `dev`. Delete the old unused `v1` tag
    (`8d11341`) before the first real release, and recommend pinning
    `@vX` in the docs.
- **v1 work on branch `v1/foundation`** (2026-10-16, pushed, not merged —
  `main` only with the user): this repository's own CI (`ci.yml`:
  testthat incl. end-to-end runs of the roxygen, test and authors bots on
  `tests/fixtures/r-package` with recorded Claude/GitHub answers, shell
  tests, actionlint, shellcheck, zizmor; green); external actions pinned
  to commits (Dependabot updates them); refactoring A, E–I done (one
  R-file parser, main loops as `review_files()` +
  `review_roxygen_file()` / `review_test_file()`). Reports and drafts
  waiting for the user: prompt audit (`dev-notes/prompt-audit.md`, hunks
  A–F), input renames B (`dev-notes/v1-input-review.md`), config/policy
  C+D (`dev-notes/v1-config-proposal.md`), rulesets, own release,
  governance YAML (`dev-notes/v1-drafts/`). Decisions of 2026-10-19 on
  all of these: in the notes; built: B (except 8), C, D.
  **Docs pending at v1** (user-facing pages, batched): config files are
  YAML and merged over the defaults (override table and wording in
  `suggestions.qmd#adjusting-the-guidance`, file names on the authors,
  roxygen and test pages); `config` package and `R_CONFIG_ACTIVE` gone;
  the policy file `config/suggestion-policy.yml` (suggestions page:
  what gets proposed, the override table, routing; `accept_reasons` no
  longer in `claude.yml`); the input renames (B) on the input tables'
  prose and in `examples/` (`review-scope`, `review-branch`, one
  `datashield-type` incl. authors, no `config-repo`/`config-ref`) — the
  examples call `@main`, so they change when v1 is merged. Also from the
  test round (2026-10-21): full-review PR titles ("… : full review"); the
  test bot's bug issue gets one post per function and run — a new issue
  lists all the failing tests (code folded), an open one only a short
  "still failing" comment with the test names
  (`test-suggest-review.qmd#failing-tests`); the checkboxes also work on
  full-review PRs. Release page: the shared release configs use the
  `conventionalcommits` preset (2026-10-21), so `feat!:` as well as a
  `BREAKING CHANGE:` footer make a major release (with the default angular
  preset only the footer did); a caller's own `.releaserc.json` needs the
  preset itself to get that; squash-merging non-conventional commits
  (e.g. dsSupportClient #21) needs a conventional title, and a
  `BREAKING CHANGE:` line for a major release (dsSupportClient's first
  real release is meant to be 2.0.0, user 2026-10-21).
- **Moved 2026-10-21:** `FlorianSchw/package-workflows` →
  **`nfdi4health/datashield-workflows`** (transfer + rename by the user;
  `b51dc5f` on `v1/foundation`: examples, docs, README, `count-run`, the
  analysis gap issues; workflow graphs still recognise the old name, which
  GitHub forwards). The 9 federation rules' `job_workflow_ref` changed by
  hand in the Console; dsSupportClient's callers updated on `dev` (its
  `main` follows with the next release merge). **dsAnalysis moved to
  nfdi4health too (2026-10-26/27):** its references on branch
  `ci/nfdi4health-move` (PR into `dev`; callers stay `@main`, since its
  inputs still have the old names), its two rules' CEL condition needs
  `repository_owner_id == "60613705"` (changed by the user in the
  Console).
  The other callers (dsSurvival, dsSurvivalClient, DataSHIELD_CONF_DEMO)
  still use the old path through the redirect. `main` of this repository still
  has the old names until v1 is merged. Docs site now
  `nfdi4health.github.io/datashield-workflows` (no redirect from the old
  one). Sections below still say package-workflows / FlorianSchw in
  places — historical.
- Federation rules for the other two accounts, before rolling out beyond
  dsSupportClient.
- **Federation rules are managed by hand in the Console** (2026-10-21):
  the Admin API is unavailable for individual Anthropic accounts, so the
  repo-governance automation was removed; `anthropic/config.json` there
  is the record of all 9 rules / 5 service accounts with their IDs (keep
  it in step with the Console). Details in
  [dev-notes/v1-planning.md](dev-notes/v1-planning.md) §5. ~~For the CI
  test round: pin `@refs/heads/v1/foundation`, switch back after~~
  **Since the move (2026-10-21) all 9 rules use one CEL expression**
  (no subject, no static claims): `repository_owner_id` and
  `repository_id` of the repository, and
  `claims.job_workflow_ref.startsWith("nfdi4health/datashield-workflows/.github/workflows/<file>@")`
  — any branch or tag, both GitHub subject forms; nothing to switch back.
  Template in repo-governance's README.
- **High priority — service accounts per GitHub owner instead of per
  repository** (raised 2026-10-20; the user talks to the people involved
  first, keep everything as is until then). Decided in principle in
  [dev-notes/v1-planning.md](dev-notes/v1-planning.md) §2, but the
  Console still has one per repository: 5 service accounts / 9 rules
  (datashield: ds-survival + ds-survival-client; FlorianSchw: ds-analysis
  + datashield-demo-analysis; nfdi4health: ds-support-client) would become
  3 / 7, one rule per owner × workflow with an explicit
  `repository_id in [...]` list (not all of an owner's repositories). Gains:
  fewer objects, a new repository is one line, the same service account
  and rule IDs for all of an owner's repositories (organization secrets in
  datashield and nfdi4health). Costs: no cost split per repository on the
  Cost page; caller secrets change for merged repositories; obsolete rules
  archived by hand. Lives in repo-governance (`anthropic/config.json`:
  `owner` + `repositories` map instead of one `repository`).
- **Review of the Claude-assisted workflows** (2026-10-14): token levers
  and refactoring, ordered —
  [dev-notes/claude-workflow-review.md](dev-notes/claude-workflow-review.md).
  Decided: manual runs review only what changed since the last review,
  no hidden git ref as memory; built from the run history (see the
  trigger-model item). Analysis step by step with `depends_on`: done (see
  the analysis item).
- **CI test round prepared** (2026-10-14): what to trigger on
  dsSupportClient and what to check, for everything built since late
  September — [dev-notes/ci-test-round.md](dev-notes/ci-test-round.md).
- Not yet confirmed in real CI: ~~`all` mode of both suggestion workflows~~
  (both ran when started by hand: roxygen → dsSupportClient PR #25, tests →
  PR #28; a scheduled run is still ahead);
  ~~`test-suggest.yml` actually generating, running and proposing
  tests~~ confirmed on dsSupportClient PR #21 → sub-PR #24 (tests for an
  already-tested function, `bad_test` classification comment, sub-PR
  updated instead of duplicated); deletion notes not yet seen;
  the version write (`desc_set_version()` in the `prepare` step) — the
  `dev` → `main` chain (head-branch check, `merge-pull-request.yml`,
  release trigger, `package-release.yml`) ran on dsSupportClient PR #20,
  but in `dry-run` mode, which skips `prepare`. dsSupportClient's release
  caller sets `dry-run: true` until its first real release.
- Release config (`.releaserc.json`, `@semantic-release/github`), undecided:
  - `draftRelease`: keep drafts (manual publish after a final look) or
    publish directly?
  - Release comments on issues/PRs: useful as a record that a bug was
    fixed in version X. Currently off. If turned on: plain text such as
    `"Included in version ${nextRelease.version}."` (the default links to
    the release, dead for most readers while it is a draft); only issues
    referenced by commits (`closes #12`) get it; requires **Issues: Read
    and write** on the GitHub App (dsSupportClient's App lacks it) and on
    `docs/getting-started.qmd`, otherwise the first real release fails at
    the comment step, after tag and release exist.
  - `released` label and failure issue: currently off.
- Suggestion thresholds: current accept lists are a first guess. Tune from
  data (log reasons vs. merged/closed suggestion PRs); ideas in
  [dev-notes/suggestion-thresholds.md](dev-notes/suggestion-thresholds.md).
  Ran in real CI on dsSupportClient PR #21 (reviewing tested functions
  confirmed); whether reasons dropped anything is only in the job logs,
  and no deletion notes were produced yet.
- ~~Model per task: all profiles in `config/claude.yml` use the `default`
  model (`claude-sonnet-5`). Tests likely deserve a stronger model than
  roxygen~~ Done: `test-review` and `test-failure-classification` use
  `claude-opus-5` with adaptive thinking, `effort: high`, larger
  `max_tokens` (32000 / 16000) and the server-side refusal fallback
  (`fallbacks: default` + beta header); `call_claude_tool()` stops with a
  clear error on `max_tokens` / `refusal`. Roxygen stays on Sonnet 5.
  Still open: watch cost per run on the Cost page (tests now review every
  selected function with Opus). Forced tool calls with thinking work on the
  Claude API; they would 400 on Opus 5.5 / Fable 5.1 (use `auto` then).
- Shared caching for `r-cmd-check.yml` — flagged, not started.
- **Claude prompt caching — checked, set aside (2026-09-26).** Console logs
  of dsSupportClient runs: test review (Opus 5) ~4–8k input / ~1.2–1.9k
  output tokens per function, failure classification ~1.9k / ~170;
  roxygen (Sonnet 5) ~3.6–10k input / ~1.1–2.8k output. A few cents per
  function; output is about half (tests) to two thirds (roxygen) of the
  cost, and caching only lowers input cost. Roxygen can't benefit: the
  tool schema (first in the cache prefix) lists each function's params.
  Tests could save ~15–25% of input cost in multi-function runs (sweeps),
  but only after reordering `test-review-prompt.md` so the shared part
  (instructions, guidance, support files, test data) comes first with a
  `cache_control` breakpoint, and the function-specific part last.
  Revisit if sweep costs grow. **Done in the cost pass of 2026-10-05**
  (setup files had grown, e.g. dsBaseClient ≈ 60k characters): the test
  prompt is split at `<!-- per function -->` (`split_cached_prompt()`)
  when the run reviews more than one file (the cache lives minutes, runs
  are hours or days apart),
  the test tool schema is the same for every function of a run (no
  per-function enums — R checks returned values), roxygen returns only
  the fields it changes, and every call logs its token usage
  (`log_claude_usage()`). **Not yet verified in CI:** "cache read" > 0
  from the second test function of a run. Proposed, not applied (no
  eval): Opus 5.5 (cheaper, but forced `tool_choice` is a 400 there —
  code support built 2026-10-14: `tool_choice_type: auto` per profile →
  strict tool, instruction, one retry; switch after the Opus 5 baseline
  of the CI round and compare), effort `medium` for tests, Sonnet for the
  failure classification.
  Details: [dev-notes/claude-costs.md](dev-notes/claude-costs.md).
- ~~**Rename the workflows before rolling out to more repos**~~ Done
  (2026-09-26): `test-coverage-suggest` → `test-suggest`, `R-CMD-Check` →
  `r-cmd-check` (casing), `check-description-authors` → `authors-suggest`
  (it proposes, like its siblings; entry script `suggest_authors.R`, docs
  page `authors-suggest.qmd` with a redirect), example `docs-suggest.yml`
  → `roxygen-suggest.yml`. Everything else kept — clear enough, and every
  rename breaks callers. `<thing>-suggest` kept for roxygen/tests so the
  federation rules' `job_workflow_ref` claims stay valid. ~~Proposal (not
  decided): prefixes by group — `check-*`
  (`check-r-package`, `check-commit-messages`, `check-pr-source-branch`),
  `release-*` (`release-package`, `release-trigger`, `release-merge-pr`,
  `release-failure-issue`), `suggest-*` (`suggest-roxygen-docs`,
  `suggest-tests`, `suggest-authors`, `suggest-cleanup-branches`),
  `maintain-keepalive`. Breaking: every caller's `uses:` path and the
  federation rules' `job_workflow_ref` claims change; docs/examples too.
  Combine with removing `app-id` (both need caller changes).~~
- **`datashield-type: utility`** (built 2026-09-29, not yet run in CI or
  end to end). This type covers analyst-side helpers that are neither
  client nor server, e.g. `FlorianSchw/dsAnalysis` and
  `dife-bioinformatics/mepr`.
  - **DSLite per function:** a function uses DSLite only if
    `uses_ds_connections()` detects connection use: a `datasources`
    argument, `datashield.*()` or `ds.*()` calls. Such functions follow the
    client path. Other functions get `utility_local` test guidance: a temp
    directory, and install, network and RStudio calls mocked. For roxygen
    they get the `utility` role guidance without the login example.
  - **Study group:** found through the package or its Depends/Imports.
  - **Unknown `datashield-type`:** now stops the run
    (`check_datashield_type()`, the user's choice).
  - **Checked locally** against the dsAnalysis clone. Details in both
    dev-notes.
  - **First real check:** the user's test work on dsAnalysis. Its caller
    needs `DSLite` and `dsBase` in `DESCRIPTION` (e.g. Suggests) for the
    connection functions.
  - ~~**Docs pending:**~~ Done in the docs pass of 2026-10-01:
    `test-suggest-datashield.qmd` (now "DataSHIELD packages", with a
    utility section), `roxygen-suggest.qmd` (a table of the three types).
- **DataSHIELD analysis starter** (`datashield-analysis-suggest.yml`):
  stage 1 built on 2026-09-30 and tested locally (Claude and the installs
  replaced by stand-ins, DSLite real). Not yet in CI: a real Claude
  answer, the pak installs, the PR.
  - **Test bed:** a GitHub repo created with dsAnalysis, with the three
    Anthropic secrets. The user will set it up.
  - **Step by step with `depends_on`** (built 2026-10-14, tested with
    stubs, not yet with DSLite or in CI): steps are written and tested one
    at a time in plan order (`draft_steps_in_order()`); a step waits while
    one it depends on fails (plan `depends_on`, else all earlier steps);
    each prompt gets the scripts so far and the objects on the servers;
    the shared prompt part is cached. **Docs pending:** `depends_on` and
    the order on the analysis pages, a commented `depends_on` in
    `examples/analysis-plan.yml`.
  - **Later stages:** models, figures/tables, and then tuning of the
    incremental updates. Structured `model:` steps could be built from an
    R template instead of Claude
    ([dev-notes/claude-workflow-review.md](dev-notes/claude-workflow-review.md)).
  - **dsAnalysis:** its changes are a checklist in
    [dev-notes/analysis-suggest.md](dev-notes/analysis-suggest.md),
    including a bug in `add_dsPackage()`.
  - ~~**Docs pending:**~~ Done in the docs pass of 2026-10-01:
    - sidebar section "Analysis projects" with
      `datashield-analysis-suggest.qmd` (main page) and
      `datashield-analysis-details.qmd` (plan fields, checks, catalogues,
      project files, settings);
    - the plan template as `examples/analysis-plan.yml`, shown via
      `{{< example FILE TARGET >}}`;
    - site and index description "…for R packages and DataSHIELD analysis
      projects" (the GitHub repo description itself is the user's to
      change);
    - roadmap, Claude setup, Getting started.

    The analysis config files are described on the details page; the
    override table in `suggestions.qmd` only points there, because they
    merge instead of replace.
- **Unified trigger model for roxygen, tests and authors** (built
  2026-10-01, tested locally in sandbox repos, **not yet in CI** — re-test
  on dsSupportClient, the list is in the dev-note; ~~**Docs pending**~~
  done 2026-10-01: `suggestions.qmd#what-gets-reviewed`, the three pages,
  examples, Overview, Under the hood, release note as "Recent changes"
  in `docs/roadmap.qmd`): support push runs, review only what's new since
  the last run (PR opened → whole PR; later pushes and plain pushes →
  `before..after`). The bot branch is built on instead of rebuilt
  (`open-suggestion-pr: add | replace`), with one concurrency group per
  branch and `scan-mode: auto`. The "reviewed up to" state is a hidden
  marker in the open bot PR's description, otherwise the event's
  `before`; a dropped run while no bot PR is open is an accepted gap.
  Edge cases: merges from other branches, merged bot PRs,
  rebases, deletions, tags, forks, Dependabot. `sweep-base` defaults to the chosen branch
  on manual runs and `dev` on schedules; sweep branch names include the
  base. Decisions, consequences and the test list are in
  [dev-notes/suggestions-trigger-model.md](dev-notes/suggestions-trigger-model.md).
  **Changed 2026-10-14** (tested locally with `gh`/`jq` stand-ins, not in
  CI): scheduled and manual runs review only what changed since the last
  review of the branch, read from the run history
  (`review-history.sh`: each review leaves a `bot-suggest review` notice
  annotation, failed calls their warnings; no storage, no ref — user's
  decision); commits a PR run already reviewed are left out for all other
  runs; `auto` = `changed` for every event, `all` = deliberate full
  review; `sweep-lookback-days` / `sweep-rotation-months` removed.
  **Breaking for callers:** roxygen and test caller jobs must grant
  `actions: read` and `checks: read`; dsSupportClient's test caller should
  drop its `scan-mode` expression (else every schedule is a full review).
  **Docs pending:** trigger sections of the roxygen/test pages (the test
  page still describes lookback/rotation), suggestions page, Getting
  started (permissions), example callers (a `scope` dispatch input,
  permissions), release note.
- **Test workflow: test file schemes and existing setups** (designed
  and built 2026-10-01, tested locally with mocked Claude, **not yet in
  CI**; first real check: a repository named by category, e.g. a
  dsBaseClient fork). The case: dsBaseClient/dsBase use
  `test-<category>-<function>.R` (`arg`, `smk`, `disc`, …, several files per
  function), and we only find `test-<function>.R`. The design:
  - find all of a function's test files;
  - recognise the scheme automatically (no input), with new tests placed
    per category by Claude (enum) and category meanings from config;
  - `dslite-setup: auto | create | never` (`auto`: only when no approach
    to connecting is recognisable anywhere under `tests/testthat/`);
  - show Claude the sourced connection helpers and example tests.

  Added while building: new tests go before a file's clean-up
  ("shutdown" test, disconnect), and a new file can get top-level setup
  and teardown code. Category meanings: `config/test-categories.yml`.
  Decisions and implementation in
  [dev-notes/test-suggest.md](dev-notes/test-suggest.md).
  ~~**Docs pending**~~ Done 2026-10-01: `test-suggest.qmd#test-files`,
  `test-suggest-datashield.qmd#connecting` (the `dslite-setup` modes),
  "What Claude gets" in `test-suggest-review.qmd`, the override table in
  `suggestions.qmd`, the example caller, and "Recent changes" in the
  roadmap.
- **Roxygen: one merged report per bot PR, possible bugs with a verdict**
  (built 2026-10-02 after dsSurvivalClient PR #37, tested locally,
  **not yet in CI**). With an open bot PR, functions are reviewed on top
  of the block it proposes (unless the user edited the docs since);
  Claude marks repeats of earlier findings and judges them; the
  description is rebuilt from all findings, each tagged with its commit,
  no-longer-valid ones crossed out with the reason. Possible bugs:
  reasoning first, then verdict and confidence; only `defect` with high
  or medium confidence (input `code-issue-confidence`, else
  `code_issue_confidence` in `config/claude.yml`; `none` skips them
  entirely). Later, if wrong bugs
  persist: thinking for the roxygen review. Not now (user's decision):
  skipping whitespace/comment-only changes. Details in
  [dev-notes/roxygen-suggest.md](dev-notes/roxygen-suggest.md).
  **Tests got the same scheme** (built 2026-10-02, tested locally, not
  in CI): the bot branch's test files are put in place before the run
  (unless the user changed them), repeats of earlier failures aren't
  classified/commented/filed again, a reported test that passes now is
  resolved, report with a new "New tests" section. Details in
  [dev-notes/test-suggest.md](dev-notes/test-suggest.md). Tests also got
  "Possible bugs in the code" (failure classification and reports with a
  confidence, same `code-issue-confidence` input; issues only at high)
  and no duplicate issues any more (`post_issue_once()`).
  **Docs pending:**
  - `roxygen-suggest.qmd` report section: one report, commit tags,
    crossed-out findings, "Latest review", verdict/confidence for
    possible bugs, the `code-issue-confidence` input (the table is
    generated); maybe a commented line in the example caller;
  - `suggestions.qmd#what-gets-reviewed`: an open bot PR's proposal is
    the starting point; hand edits to its description are overwritten
    (comments are fine);
  - `test-suggest.qmd` report section: "New tests", "Possible bugs in
    the code", one merged report, repeated failures not commented again;
    `test-suggest-review.qmd#failing-tests`: confidence, issues only at
    high, one issue per function; the `code-issue-confidence` input;
  - `suggestions.qmd#what-gets-proposed`: the `accept-reasons` input
    (roxygen and tests) besides the config file;
  - roadmap "Recent changes".
- **Usage counting** (built 2026-10-02 for service-usage KPIs, **not yet
  in CI**): per workflow, outcome and channel, anonymous, no opt-out
  (user's decision); see
  the LAYOUT entry and
  [dev-notes/usage-counting.md](dev-notes/usage-counting.md). Docs done:
  `getting-started.qmd#usage-counting`, roadmap "Recent changes". Still
  to do: the data protection note in dsAnalysis's README (its CLAUDE.md,
  item D11).
- ~~**Policy file for the bot's rules**~~ Done on `v1/foundation`
  (2026-10-19): `config/suggestion-policy.yml` — reasons with meaning and
  `accept`, `max_new_tests`, `possible_bugs` (`report`, `open_issue`),
  author roles and name particles, `routing` per situation (on a PR /
  without a PR: comment, issue, log; checked by `check_routing()`),
  read with `suggestion_policy()`; reason meanings written into the tool
  schemas and the roxygen prompt (`format_reason_meanings()`).
  `accept_reasons`, `code_issue_confidence`, `max_new_tests` left
  `config/claude.yml`. Docs pending at v1. The original item: today reasons, action↔reason mapping, the `aut`/`ctb` rule, name
  particles and report routing live partly only in R code. Move the
  tunable policy to one readable file that R and the tool schemas read
  (schema descriptions from the same source); keep safety invariants
  (never adapt a test to possibly buggy output, only failing tests are
  updated, nothing without a suggestion PR) in code, documented in the
  decision record. Overridable per repo like the other config files.
  Decided (2026-09-30): **one file** for roxygen, tests and authors,
  merged key by key over the defaults like the analysis workflow's config
  (`read_config_yaml()`). Do it together with switching the other
  workflows' overrides from "replace the file" to merging, otherwise a
  project's older copy loses rules added later. The analysis workflow
  keeps its own settings; only its tool schema descriptions move into the
  policy file. ~~Open: should roxygen callers grant `issues: write`?~~
  Done (2026-09-30, user's decision): roxygen callers grant
  `issues: write`, and possible code bugs from a sweep without a
  suggestion PR go to a monthly issue (`report_sweep_code_issues()`)
  instead of the job log. ~~**Docs pending:**~~ Done 2026-10-01: the
  roxygen page's report section, and the "Recent changes" in the roadmap
  (as a required caller change).
- ~~**Report routing is code, not config:**~~ Done with the policy file
  (`routing`, today's behaviour as the default). The original item: where test failures, possible
  bugs, deletion notes and code issues go (PR comment, PR description,
  issue, log) is decided in R (`publish_test_report()`,
  `suggest_roxygen.R`). The user expects it to be configurable — do it as
  part of the policy file (`config/suggestion-policy.yml`, see "rules
  partly only in code"). Constraint: an issue needs `issues: write`,
  which roxygen callers don't grant.
- ~~**GitHub App `client-id`:**~~ Done:
  `actions/create-github-app-token@v3` deprecates `app-id` in favour of
  `client-id` — a *different value* (the App's Client ID, `Iv23li…`, not
  the numeric App ID). `resolve-push-token` takes `client-id` and falls
  back to `app-id` in a separate step (passing `app-id` at all triggers
  the deprecation warning); the four workflows using it accept an
  `app-client-id` secret. Confirmed in CI on dsSupportClient (all four
  callers switched to `APP_CLIENT_ID`; no deprecation warning). `app-id`
  removed on 2026-09-26, together with the renaming.
- **Ubuntu 26 on `ubuntu-latest` from 2026-10-19:** P3M binaries
  (`use-public-rspm`) may lag for a new Ubuntu → source builds, slow or
  failing. ~~Plan: pin all workflows (and r-cmd-check's `os-list` default)
  to `ubuntu-24.04` before then; move to 26.04 deliberately once P3M
  serves binaries for it, tested on dsSupportClient first.~~ Decided
  (2026-09-26): no pin, stay on `ubuntu-latest`. After 2026-10-19, if
  dependency installs get slow or fail, check P3M support for 26.04
  first; pinning to `ubuntu-24.04` remains the fallback.
- **DataSHIELD argument naming harmonisation** (designed 2026-10-14;
  check and apply workflows **built the same day, tested locally on a
  fixture pair, not yet on a real package or in CI**; keep off
  `docs/roadmap.qmd` and `examples/` until the rules are agreed with the
  DataSHIELD developers in person — the callers are in the dev-note
  folder). Goal: a breaking release with one
  argument name per object class/role across all DataSHIELD packages
  (today e.g. `newobj` vs `newobj.name`), done by a workflow, covering R
  code, server side, tests, test file names, roxygen and vignettes.
  Everything is in [dev-notes/datashield-naming/](dev-notes/datashield-naming/README.md):
  survey results, an inventory of 32 packages × prod/dev (1,077
  user-facing functions; Python prototype + 3.8 MB CSV, git-ignored), the
  draft rules (now `config/ds-naming-rules.yml`; YAML with per-line
  comments; `name: [a, b]` = open, the check uses the front-runner and
  marks `rule_open`), and what was built ("Built" section).
  - **First real run done locally** (2026-10-14, dsBaseClient + dsBase
    v7.0-dev, no Claude): 336 proposals; applying all of them leaves every
    file parsing, no missed use or call of an old name (details and the
    fixes it needed in the dev-note).
  - **Next:** a real Claude answer and both workflows in CI (needs a
    federation rule for `ds-naming-check.yml` per repo, the App on client
    and server repo of the same owner — a fork pair under one account
    would do); `propose-branch` (push + PR) is untested.
  - **Not built yet:** Claude on vignette prose (advisory), the
    throwaway DataSHIELD stack in CI, deprecation shims, function renames
    and argument reordering (reported only), `@param` texts from
    `param_doc`.
  - **Agreed shape:** rules config → deterministic detect (report +
    transformation config, one entry per function × argument) → Claude
    classifies only what code can't (low-confidence args, names like `x`
    used for 8 classes) as `proposed` entries → human approves →
    deterministic, idempotent apply via the R parse tree, client and
    server in lockstep, one PR per package onto a shared branch → Claude
    advisory on vignette prose. Safety net: a throwaway DataSHIELD stack
    (or DSLite) in CI running the integration tests.
  - **Decided:** class names without `.name` suffix (`df`, not
    `df.name`); test files `test-[<category>[_<category>]-]<target>[-<variant>].R`
    with the category optional.
  - **Coordinate first:** dsBase/Client v7.0-dev already renames
    arguments (`xvect` → `x`, `x` → `x.name`, new `classConsistencyCheck`
    instead of the survey's `checks`). Open questions are listed in the
    dev-note.
  - **Second idea, not started:** functions taking one vector should
    accept several columns or a selector (all categorical/continuous).
- **Issue agents** (brainstorm from another chat, 2026-10-16, no
  decisions): triage and spec review on the API, an implementer on the
  Pro subscription (claude-code-action) after a maintainer's
  `bot-proceed`, label integrity, a DataSHIELD function index for
  overlap checks. Plus new processes: learning from what users keep
  (signals → thresholds → a reviewed per-repo "house style" file), a
  refactor agent (performance, new functions, this repo's workflows) and
  a researcher agent (gap catalogue → design with disclosure analysis →
  client/server pair). Fit with this repo and open points in
  [dev-notes/issue-agents.md](dev-notes/issue-agents.md).
- **Claude Pro/Max subscription instead of WIF** (asked 2026-10-14, not
  pursued): the workflows call the Messages API directly, which a
  subscription doesn't cover. A plain API-key alternative to WIF is not
  wanted (user); running the Claude step through Claude Code would let a
  subscription pay but gives up the controlled, schema-forced call.
  Reasons and trade-offs in
  [dev-notes/claude-subscription-auth.md](dev-notes/claude-subscription-auth.md).
- Internal only — keep these off `docs/roadmap.qmd` (user's decision):
  - **Name of a generated DSLite setup file:** `setup.R` if none exists,
    else `setup-dslite.R` (must start with `setup` for testthat to run
    it). Chosen to avoid cluttering packages with files; revisit after
    colleagues' feedback.
  - ~~**Changing existing tests:** the test workflow currently never
    modifies existing tests~~ Done: existing tests are updated / deleted /
    reported under the safeguards in `dev-notes/suggestion-thresholds.md`,
    using test results and history evidence (function diff in PRs).
    Tested locally end to end (mocked Claude), not yet in CI — replay a
    PR like #21 (contract change + outdated test) as the first real check.
  - ~~**Max number of test suggestions:** currently 5~~ Done:
    `max_new_tests` (10) in `config/claude.yml`. Sweep cost is handled by
    scope instead: ~~`sweep-lookback-days` / `sweep-rotation-months`~~
    (removed 2026-10-14) scheduled and manual runs review only what
    changed since the last review (run history). A cheaper sweep model was considered and not done — the
    existing-test diagnosis needs the strong model.
  - **Author contributions in `DESCRIPTION`:** ~~`aut` vs `ctb`~~ done
    (`R/` changes → `aut`, otherwise `ctb`, upgrade only; tested locally
    with a mocked GitHub API, not yet in CI). ~~**Names** — the full name
    is added as given name, and `find_author()` matches by plain text~~
    done (given/family split, e-mail/normalized-name matching, possible
    matches reported; replayed PR #21 locally). Decided against for now:
    a per-repo login → name mapping file (`config/authors.json`) —
    revisit only if wrongly split or differing profile names become a
    real problem. Later option: a minimum change size for `aut`, and
    `Co-authored-by:` trailers.
  - **README update workflow:** a new workflow that keeps a package's
    README up to date — scope to be clarified.
  - **Several functions per `.R` file** (e.g. `utils.R`): skipped for now
    (user's decision, 2026-10-01). `parse_r_file()` only takes the first
    function, for roxygen and tests alike. If revisited, the open points
    are: review only the changed functions in PR/push runs, write blocks
    back bottom-up, how to handle undocumented internal helpers (`@noRd`
    or skip), shared docs (`@rdname`/`@describeIn`), and tests per
    function.
  - **Workflow graphs** (new reusable workflow, built 2026-09-26): tested
    locally against dsSupportClient's workflow files (block handling,
    idempotency, chain detection). First CI run on
    dsSupportClient's `dev` generated the README, but the push to
    `.github/workflows/README.md` was rejected (App lacks the Workflows
    permission, which every file in that folder needs) → moved to
    `.github/workflow-graphs/README.md`; the rerun committed it on `dev`.
    Three rounds of user feedback on the live README (2026-09-26): now a
    summary table (name/file, bullets) and one diagram per situation with
    outcomes and conditions fitted per situation; the per-workflow detail
    section was dropped (too specific — the files are the place for
    that). The PR diagram preview was dropped for a one-line note (user's
    choice). Not yet verified in CI: that note. Further layout feedback
    possible. Design and open points in
    [dev-notes/workflow-graphs.md](dev-notes/workflow-graphs.md).
- ~~Reusable workflow keepalive: GitHub disables scheduled workflows after
  60 days without repository activity. Callers with cron jobs (monthly
  sweeps, scheduled R CMD check, …) currently each add their own
  `liskin/gh-workflow-keepalive@v1` job (dsSupportClient's R-CMD-Check
  caller does, with `actions: write`). Wanted: one centrally maintained
  reusable workflow for it, plus a docs page and example.~~ Done:
  `workflow-keepalive.yml`. dsSupportClient's R-CMD-Check, docs and test
  callers use it (no direct `liskin` any more); it only runs on a
  scheduled trigger, so it is not yet confirmed in real CI.
