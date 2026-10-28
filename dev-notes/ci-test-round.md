# CI test round on dsSupportClient

Prepared 2026-10-14. Most features since late September were tested
locally only. This round checks them in real CI on
nfdi4health/dsSupportClient (callers on `dev`, all `@main`). Tick items
here or move results into the feature's dev-note; afterwards update
"Not yet confirmed in real CI" and the items in CLAUDE.md STILL OPEN.

**Update 2026-10-20:** the round now runs against branch
`v1/foundation`, not `@main` — it adds the v1 changes (`$/` actions,
renamed inputs, YAML config, the policy file, prompt changes). The
dsSupportClient callers for it, and what else is needed (federation rules
matching `@refs/heads/v1/foundation`), are in
[v1-callers/dsSupportClient/](v1-callers/dsSupportClient/README.md).
The items below still apply, with the new input names (`review-scope`
instead of `scan-mode`).

## Results of 2026-10-21 (dsSupportClient PR #46, branch `test/v1-foundation`)

Confirmed in real CI against `v1/foundation`:

- **Federation rules** pinned to `…@refs/heads/v1/foundation` (by hand
  in the Console; switch back after the round): both Claude bots got a
  token.
- **Full review** (manual, scope `all`): roxygen → #47 (16 applied,
  3 not applied, 2 possible bugs), tests → #48 (14 new tests passing a
  real run, 8 failed and only reported, 3 possible bugs — a real defect
  in `ds.tableBatch()`, already known in #21).
- **Checkboxes** (`suggestion-choices.yml`) on #47: ticking and unticking
  applied to the bot branch; ~1 min per click, mostly installing R (left
  as is, user's decision); quick clicks queue, waiting runs are merged.
- **Cleanup** on closing #48: the bot branch was deleted.
- **"changed" mode on a PR** (one comment line in `R/ds.wrapper.R`): both
  bots reviewed only that file; tests → #49 (3 new tests), roxygen →
  nothing to change plus a possible-bug comment; link comment on #46.
- Authors bot, commitlint, R CMD check: green.

Found and fixed during the round:

- `github.job_workflow_sha` is empty: every workflow had checked out
  `main`'s scripts and config (`bot-authors.json` missing). Now the
  `shared-files` action copies the repository at the running commit
  (`25acb84`); Self-test green.
- `suggestion-choices` skipped full-review PRs (`bot-suggest/docs-all-…`);
  dsSupportClient had no caller for it (`9030d7e`, caller added).
- Report text pointed to `accept_reasons` in `config/claude.yml`
  (`23f82bb`); full-review PR titles no longer say "Monthly … sweep"
  (`c659378`).

After the move to nfdi4health/datashield-workflows (2026-10-21): a full
review on `ci/datashield-workflows` logged in with the new CEL rule and
opened #51 with the new title "Roxygen documentation: full review".

Still open: `workflow-graph` on the push of the merge into `dev`, the
release chain (`dev` → `main`, `dry-run`), a scheduled run, and
the federation rules (now one CEL expression each, any ref — done).

## Before starting

- `main` of package-workflows contains everything to test (callers use
  `@main`; a run started before a push uses the old commit — check the
  commit in the run's "Checkout shared scripts" step).
- dsSupportClient callers are compatible as they are (checked
  2026-10-14: roxygen grants `issues: write`; the test caller's
  `scan-mode` expression still works).
- Optional, to cover more: add the `suggestion-choices` caller
  (`examples/suggestion-choices.yml`) — needed for step 4.

## Steps

1. **PR with a contract change** (replay of PR #21): branch off `dev`,
   change one exported function's behaviour so one existing test becomes
   outdated, touch a second R file too, open a PR into `dev`. Runs:
   roxygen, tests, authors, R CMD check, commitlint.
   - **Tests run without credentials** (`run_test_blocks()` via callr):
     tests still pass/fail as before; the job log has no "could not
     find function"; "Test data:" is a real summary, not "could not be
     determined".
   - **Bot branch fetch without stored credentials**: on later runs the
     log doesn't say "Could not fetch bot-suggest/…".
   - **Test report**: one merged report with checkboxes, "New tests",
     "Changes to existing tests" (the outdated test updated with reason
     `contract_changed`), "Possible bugs in the code" if any, summary
     line, hidden state; "added to Suggests: …" if a test used an
     undeclared package (and DESCRIPTION in the bot PR).
   - **Roxygen report**: merged report, possible bugs with verdict and
     confidence (only high/medium), commit tags.
   - **Cost lines**: "Claude usage (…)" per call; roxygen output tokens
     vs. the ~1.1–2.8k before; test review with two files → "cache read"
     > 0 on the second function.
   - **Authors**: sub-PR or nothing, as appropriate.
2. **Second push to the same PR**: only the new commit is reviewed; the
   bot PRs are built on (not rebuilt, no force push), the "reviewed up
   to" marker moves, earlier findings stay or are crossed out with a
   reason; repeated failures are not commented again; no duplicate issue.
3. **Merge a bot PR, push again**: the merged bot PR's changes aren't
   suggested again; cleanup deletes the bot branch.
4. **Checkboxes** (needs the suggestion-choices caller): untick a new
   test → the bot branch drops it within a minute; tick it again → back.
5. **Manual sweep**: run test-suggest by hand on `dev` → branch
   `bot-suggest/tests-sweep-dev-YYYY-MM`, PR against `dev`; many
   functions → "cache read" > 0 from the second; re-run in the same month
   updates that PR.
6. **Usage counting**: after the runs, the `usage-counter` release's
   download counts for roxygen-suggest, test-suggest, authors-suggest
   (`-dev`) went up; next day `usage-data` has them.
7. **Scheduled (wait for 1 November, 06:00 UTC)**: both monthly sweeps
   start on `main` but sweep `dev`; the keepalive job runs.

## Not covered here (need another repository or a decision)

- Release version write: needs `dry-run: true` removed (first real
  release, user's decision).
- Test file schemes for categorised repositories: a dsBaseClient fork.
- DataSHIELD `utility` type: dsAnalysis's own test caller.
- Analysis starter: the test repository from a dsAnalysis template.
- Naming workflows: a client/server fork pair with the App on both and a
  federation rule for `ds-naming-check.yml`.
- Workflow graphs PR note: dsSupportClient's caller has no PR trigger.
