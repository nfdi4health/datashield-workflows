# Feedback loop: from people's choices to the bots' guidance (2026-11-12)

Nothing here is built yet. Comes from a discussion outside the coding
session (claude.ai, 2026-11-11/12) on how other teams run LLM agents in
their pipelines and what this repository could still take from that. The
user's view: getting towards a full loop is worth considering. Open
decisions are at the end.

Builds on the earlier sketch "Learning from what users keep" in
[issue-agents.md](issue-agents.md) (signals → thresholds → a distilled
"house style" per repository); this note is the more concrete version.

## Why

The bots already ask people to decide: every roxygen and test finding that
changes a file is a checkbox (`suggestion-choices.md`), the choice is
recorded as `choice` on the finding, and declined findings are remembered
until the code changes. But these decisions stay in each PR. Nothing
learns from them: a guidance line that people keep overruling is sent
again unchanged to every next run.

What other teams do (summary of the research): treat production outcomes
as the honest quality measure, turn rejected or corrected outputs into
eval cases, change prompts or guidance only through reviewed changes, and
check every such change against a fixed eval set before it ships.

## The loop

1. **Capture** (mostly there)
   - have: ticked / unticked per finding, with its kind (roxygen field such
     as `@details`, test `new` / `updated` / `deleted`);
   - missing, the richest signal: **edits after accepting** — a ticked
     suggestion that a person rewords before merging. The diff between the
     bot's text for that finding and the merged file says exactly what was
     wrong;
   - missing, optional: **a reason for declining** (`wrong` / `not wanted`
     / `style`), e.g. one extra checkbox line per finding. Without it a
     factual error and a matter of taste look the same.
2. **Collect.** When a bot PR is merged or closed: one small record per
   finding — repository, workflow, kind / field, choice, edit diff, model,
   prompt and config hash. Stored in the private repository next to the
   usage counting. Caller repositories opt in (an input), as these are
   their maintainers' decisions.
3. **Aggregate.** Acceptance per field / kind, split by model and config
   version ("`@details` declined 60 %", "updated tests mostly unticked").
4. **Distil, a person decides.** A periodic workflow (monthly?) gives
   Claude the declined and edited cases grouped by field and asks for a PR
   that changes **guidance config, not prompts** — `roxygen-style.yml`,
   `test-role-guidance.yml`, `datashield-role-guidance.yml` — each change
   with its evidence (counts + 2–3 real examples). The user accepts or
   declines that PR like any other suggestion. Accepted rejection cases go
   into the eval set (below).
5. **Verify.** The eval set runs on that PR, so a refinement can't quietly
   break what worked; next period's acceptance shows whether it helped.

## Guardrails

- **Project override or shared default.** The configs already merge a
  project's file over the defaults: a pattern from one repository or one
  person goes into that project's override; only a pattern across
  repositories changes the shared default. Many decisions will be the
  user's own — this keeps the loop from tuning everything to one taste.
- **Minimum evidence** before a change is proposed, e.g. ≥ 10 cases from
  ≥ 2 people (to be tuned).
- **Acceptance is not the only target.** The easiest way to raise
  acceptance is to suggest less. Track it next to how many suggestions are
  made and the bug-finding rate on the eval set; a bot that grows timid
  shows up as a regression.
- **Provenance.** Each guidance line the loop changes links its evidence,
  so it can be traced or undone.

## What it depends on

1. **A repeatable eval set** (instead of only the manual CI test round,
   `ci-test-round.md`, which can't be repeated the same way twice):
   - fixtures with planted defects (extend `tests/fixtures/ds-client`:
     10–20 known bugs — a wrong argument check, a missing disclosure
     check, docs that contradict the code); score how many the roxygen
     review ("possible bugs") and the test review find — deterministic,
     the answers are known;
   - analysis plans with known answers on the mock data (derived
     categories, n, direction of coefficients);
   - runs on changes to `prompts/**`, `config/claude.yml`,
     `config/*-guidance.yml`, `R/functions/**`, and before a model switch
     (e.g. the pending Opus 5 → 5.5 for the test profiles);
   - start with 30–50 hand-written cases.
2. **Provenance on every bot output**: model, prompt hash and config
   version in each bot commit or PR (trailer or report footer).
   `TESTED_WITH` in the analysis scripts is a start; without it the
   aggregation can't tell which change moved acceptance.

## First step (no new infrastructure)

A script that reads the `choice` fields of merged and closed bot PRs in
the caller repositories via the GitHub API and prints acceptance per
field / kind. About an afternoon; shows whether there are clear patterns
before anything else is built.

## Related points from the same discussion (not part of the loop)

- **Several solvers per analysis step** (`analysis-suggest.md`): useful
  mainly for data management, where errors spread furthest. Diversity
  without new prompts: different models per candidate (config list
  `solver_variants`), optionally a one-line hint per candidate after the
  `<!-- per request -->` cache break. Pick the winner deterministically:
  passes the checks → same resulting data on the mock data → shortest.
  Only after the eval set exists.
- **Check results, not only runs**: the mock data is generated locally, so
  a data management step can be compared against the same derivation in
  plain R (categories, counts, complete-case n). Catches silent errors a
  test run can't.
- **Let a later step reopen an earlier one** (a structured "needs X from
  data_management" note) instead of only failing.
- **Adversarial self-test** for issue → triage → spec → implementer: a
  fixture issue with an injection payload; passes if the spec doesn't
  carry the instruction and the sandbox blocks any outbound call.

## Open decisions

- Where the records live (private repository as with usage counting?) and
  whether caller repositories opt in or out.
- Whether to capture a decline reason, and how (extra checkbox, label).
- Period of the distil step and the evidence threshold.
- **Privacy vs. the earlier sketch:** issue-agents.md says learnings stay
  in their repository and only counts cross repositories. The records here
  (edit diffs, examples in the distil PR) contain the caller's code. Either
  keep the diffs in the caller repository and send only counts to the
  private one, or make the opt-in explicitly cover code excerpts.
- Which comes first: the eval set (prerequisite for safe changes) or the
  first-step script (to see whether there are patterns at all).
