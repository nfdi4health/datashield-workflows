# Input review for v1 (B) — proposal, 2026-10-16

**Decided 2026-10-19 (user): 1–7 as proposed** (`review-scope`,
`review-branch`, one `datashield-type` incl. authors, `config-repo` /
`config-ref` removed, `base-branch` + `server-base-branch`,
`max-claude-calls` with 0 = off). **8: decide at the move**, when it's
clear where dsAnalysis lives. **Built 2026-10-19** on `v1/foundation` (1–7).

v1 is the one round of caller changes (move to
`nfdi4health/datashield-workflows`, `@v1`), so renames cost least now.
**Nothing renamed yet**: each row is for the user to accept, change or
drop. Plan: [v1-planning.md](v1-planning.md) §6 B.

Principles behind the proposals: a name says what the caller decides,
not how it worked historically ("sweep" is gone since 2026-10-14); one
input instead of two that only make sense together; the same name for
the same thing across workflows; no hard-coded owner in a default.

## Proposed changes

| # | Workflow(s) | Today | Proposal | Why |
|---|---|---|---|---|
| 1 | roxygen, tests | `scan-mode: auto \| all` | `review-scope: changed \| all` (default `changed`) | `auto` has meant `changed` for every event since 2026-10-14; the value no longer chooses anything automatic. The example callers' manual-run input is already called `scope` (Docs pending). |
| 2 | roxygen, tests | `sweep-base` | `review-branch` | Scheduled and manual runs no longer "sweep"; the input picks the branch they review (empty: the chosen branch on manual runs, `dev` on schedules). Branch names `bot-suggest/<kind>-sweep-<base>-YYYY-MM` would become `…-all-<base>-…` with it. |
| 3 | roxygen, tests | `datashield: true/false` + `datashield-type: client \| server \| utility` | one `datashield-type: none \| client \| server \| utility` (default `none`) | Two inputs that only work together ("required when datashield is true", checked by `check_datashield_type()`); one removes the invalid combinations. |
| 4 | authors | — | add `datashield-type` (same values) | The v1 plan counts DataSHIELD and other use separately, set by an explicit input; the authors bot itself doesn't use it. |
| 5 | package-release | `config-repo` (default `FlorianSchw/package-workflows`), `config-ref` | remove both | The shared checkout is at `github.job_workflow_sha` now, so the fallback `.releaserc.json` can come from it like every other shared file (a caller's own file still wins). The default hard-codes the old owner and breaks at the move. |
| 6 | ds-naming-check / -apply | `base-branch` (check) vs `target-branch` + `server-target-branch` (apply) | `base-branch` and `server-base-branch` in both | Same meaning (the branch the PR goes into), three names. Internal workflows — no outside callers yet. |
| 7 | ds-naming-check | `use-claude: true/false` + `max-claude-calls: 40` | `max-claude-calls` only, `0` = no Claude | Like 3: one number says both. |
| 8 | analysis | `dsanalysis-repository` (default `FlorianSchw/dsAnalysis`) | default changes with dsAnalysis's own home | Hard-coded owner; check where dsAnalysis lives at v1. |

## Checked and kept

- `open-suggestion-pr: add | replace` (roxygen, tests, authors) — clear
  enough; same name in all three.
- `accept-reasons`, `code-issue-confidence` — descriptions already name
  the config fallback; values are checked in R.
- `dslite-setup: auto | create | never`.
- Secrets `anthropic-organization-id`, `anthropic-service-account-id`,
  `anthropic-federation-rule-id`, `app-client-id`, `app-private-key`,
  `commit-push-pat` — mapped explicitly by callers; renaming them would
  touch every caller and the governance YAML for no gain.
- `r-cmd-check.yml` inputs (`os-list`, `r-version-list` as JSON arrays,
  `run-codecov`, `extra-*-packages`), `require-head-branch`'s
  `allowed-head`, `create-issue`'s `template`, `merge-pull-request`'s
  PR number, `plan-file`, `transformation-file`, `server-repository`,
  `server-ref`, `package-side`.

## Descriptions

- roxygen/tests `scan-mode`: the description explains `auto` = `changed`
  at length — goes away with 1.
- `anthropic-service-account-id` / `-federation-rule-id` say "for this
  repo"; with rules per owner (v1 plan §2) they become "for this
  repository's owner".
- The descriptions are what the docs tables show (`wf-inputs`), so the
  docs follow automatically; examples and page prose go in the batched
  docs pass.

## What a rename means for callers

Every rename in 1–5 is a caller change at v1; the federation rules'
`job_workflow_ref` claims change anyway with the move. Old names are not
kept as aliases: GitHub rejects a call with an input the reusable
workflow doesn't define, so a caller still using an old name fails at
once with a clear error instead of silently getting the default.
