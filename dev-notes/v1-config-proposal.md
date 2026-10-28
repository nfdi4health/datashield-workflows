# Config files and the policy file for v1 (C, D) — proposal, 2026-10-16

**Decided 2026-10-19 (user):** C1 all YAML, all merged; C2 own reader
for `claude.yml` (no `config` package, no `R_CONFIG_ACTIVE`); C3 **clean
break** — no project has overrides (checked the local clones of
dsSupportClient, dsSurvivalClient, dsAnalysis, mepr), so old JSON
overrides are simply no longer read, no fallback (point 4 below is
dropped); D the policy file as drafted, routing included. Not built
yet — together with B.

**Proposal only, nothing changed.** Plan: [v1-planning.md](v1-planning.md)
§6 C and D. Decided earlier (CLAUDE.md, policy file item): one policy
file for roxygen, tests and authors, merged key by key like the
analysis config, and done together with switching every override to
merging.

## C — today

| File | Format | Read by | A project's own copy |
|---|---|---|---|
| `claude.yml` | YAML, `config` profiles | `config::get()` | replaces the file |
| `analysis-suggest.yml`, `analysis-texts.yml`, `ds-naming-rules.yml` | YAML | `read_config_yaml()` | **merged** key by key |
| `report-style.yml` | YAML | `report_style()` | replaces |
| `workflow-outcomes.yml` | YAML | `workflow_graphs.R` | replaces |
| `roxygen-style.json`, `test-role-guidance.json`, `datashield-role-guidance.json`, `test-categories.json`, `datashield-example-env.json`, `dslite-canned-datasets.json` | JSON | `read_json_config()` | replaces |
| `bot-authors.json` | JSON | R **and** `jq` in `determine-changes.sh` | replaces |
| `commitlint-config.mjs` | JS | commitlint | replaces (commitlint's own) |

The cost of "replaces": a project that overrides one guidance line holds
a full copy, and every key added to the defaults later never reaches it.

## C — proposal

1. **All YAML, all merged.** The six JSON files and `bot-authors.json`
   become YAML (same keys; the long guidance arrays of strings become
   block scalars `|`, which also reads better). Every R reader goes
   through `read_config_yaml()`. Merge rule as today: maps merge, lists
   and values are replaced as a whole — so `accept_reasons: [missing]`
   in a project means exactly that list.
2. **`claude.yml` without the `config` package.** Read with
   `read_config_yaml()`, then `modifyList(cfg$default, cfg[[profile]])`
   for a profile (what `config::get()` does, plus merging with the
   project's copy). The scripts pass the profile explicitly (they
   already do for `claude_client()`), so `R_CONFIG_ACTIVE` leaves the
   workflows. One dependency less, and the clash with a package's own
   `config.yml` no longer matters.
3. **Shell side:** `determine-changes.sh` reads `bot-authors.yml` with
   `yq` (preinstalled on GitHub-hosted Ubuntu runners), merging the
   project's copy the same way:
   `yq eval-all '. as $f ireduce ({}; . * $f)' shared.yml own.yml`
   (`*` merges maps and replaces arrays — the same rule as R).
   The shell tests get a `yq` stand-in like the `jq` one.
4. **Old JSON overrides** in a project: read once with a warning
   annotation ("config/x.json is no longer read from v2 — rename it to
   config/x.yml"), for the v1 line only. Cheap, and nobody silently
   loses an override at the switch.
5. **`commitlint-config.mjs` stays** — commitlint's own format.

Not merged on purpose: `analysis-plan.yml` (the analyst's plan, not a
setting) and `.releaserc.json` (semantic-release's own lookup).

## D — the policy file

`config/suggestion-policy.yml`: the tunable rules of the roxygen, test
and authors bots in one readable place, read by R and written into the
tool schemas and prompts from the same source (so a reason's meaning is
stated once). Draft: [v1-drafts/suggestion-policy.yml](v1-drafts/suggestion-policy.yml).

What moves there (today in R or in `claude.yml`):

| Rule | Today |
|---|---|
| reasons per task, their meaning, which are accepted | `suggestion_reasons()`, `accept_reasons` in `claude.yml`, enum descriptions in `build_submit_*_tool.R`, the list in `roxygen-review-prompt.md` |
| which possible bugs are reported, and which get an issue | `code_issue_confidence` in `claude.yml`; "issue only at high" in `handle_failed_new_test()` |
| `max_new_tests` | `claude.yml` |
| author roles (`aut` for R code, else `ctb`, upgrade only) and name particles | `credit_contributor()`, `split_person_name()` |
| where each kind of finding goes (PR description, comment, issue, log) | `publish_test_report()`, `suggest_roxygen.R` — the routing the user wants configurable |

What stays in code (safety invariants, listed in
`dev-notes/suggestion-thresholds.md` and not configurable): a test is
never changed to match output that may be wrong; only failing tests are
updated; nothing reaches a branch except through a suggestion PR; the
mechanical filters (whitespace-only changes, duplicate assertions);
generated code runs without credentials.

Inputs keep overriding the file (`accept-reasons`,
`code-issue-confidence`), as today over `claude.yml`.

**Routing constraint:** an `issue` destination needs `issues: write` on
the caller job; roxygen callers grant it since 2026-09-30, test callers
too, authors callers don't — so the authors section offers only
`comment` and `report`.

## Order

C first (the readers and the merge), then D on top (one new file, the
rules moved into it, the schema/prompt texts generated). Both together
are one caller-visible change at v1: projects with their own JSON
overrides rename them, nothing else.
