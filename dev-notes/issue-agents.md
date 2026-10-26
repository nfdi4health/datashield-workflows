# Agents: issue flow, learning, refactor, researcher (brainstorm, 2026-10-16)

From another chat, **no decisions yet**. Recorded here with how it would
fit this repository; nothing built.

## Idea

1. **Triage** on every new issue (API, small model): bug, idea,
   question, duplicate, spam, needs-info. Most issues stop here.
2. **Spec review** for real bugs and plausible ideas (API, stronger
   model, reads the repository): a tightened spec — goal, acceptance
   criteria, likely files, size, risks, open questions, comparison with
   similar existing functions.
3. **Implementer** after a maintainer adds `bot-proceed`: runs on the
   Pro subscription, builds the reviewed spec, opens a PR. Overlap
   findings in the spec count as decided.

Guardrails (proposed): reviewer read-only and comment-only;
`bot-reviewed` is bot-only, proven by a bot-authored comment with a
hidden marker (not the label); unauthorized labels reverted; implementer
re-verifies before running. Re-review on meaningful new input (debounce
~30 min, ~3 automatic reviews per issue, per-repo daily cap, then a note
that a maintainer is needed); edits after approval drop `bot-proceed`.
Bot-created issues (drift sweeps): deduplicated by marker, capped per
run, labelled `bot-created`, never triaged. Spend bounded by a dedicated
Console workspace with a monthly limit. Thin shared issue templates
(idea, bug, maintenance; only the goal required) via a `.github` repo
plus the sync script.

DataSHIELD: a generated function index per package (signature, input
types, method, summary), refreshed on a schedule; the reviewer compares
close candidates (identical / differing / suggested route), advisory
only; curated "how this differs" notes for decided near-duplicates.
Agent ideas: datashield-researcher (index and overlap comparisons),
refactor agent (applies the naming transformation config).

## How it fits here

- **Same pattern as the suggestion workflows:** triage and spec review
  are single API calls with a forced/strict tool schema — Claude returns
  fields (category enum, spec sections), R or shell posts the comment and
  labels. WIF per repo × workflow, `count-run`, the usage-counting rules,
  one Console workspace per workflow type (here: the spend limit) all
  apply unchanged.
- **The implementer is the one place for Claude Code** (claude-code-action
  with `CLAUDE_CODE_OAUTH_TOKEN` from the subscription). That is the
  supported use of a subscription in CI, unlike our direct API calls
  ([claude-subscription-auth.md](claude-subscription-auth.md)); an
  open-ended "build this" task suits an agent. **Decided 2026-10-16**
  (details in [claude-subscription-auth.md](claude-subscription-auth.md)):
  agents only the user triggers run on the user's subscription from a
  central private repo (token, work list, one queue); everything others
  trigger runs on the API with WIF.

## Decisions on the agent setup (2026-10-16)

| Agent | Triggered by | Runs on |
|---|---|---|
| Triage | others (new issues) | API, owner pays |
| Spec review | others / automatic | API, owner pays |
| Implementer | the user (`bot-proceed`) | subscription, central private repo |
| Researcher (DataSHIELD-wide gap catalogue; per themed repo: methods, design note) | the user | subscription, central private repo |
| Refactor agent | the user | subscription, central private repo |

- **Researcher only researches:** its result is a design note (gap,
  method, sources, what the server returns, disclosure analysis) as an
  issue in the themed repo; the implementer writes code only after the
  user's `bot-proceed` on it.
- **Public vs. private:** the agents as reusable workflows in the public
  workflow repo (credentials as inputs: subscription token, API key or
  WIF), versioned with `@v1`; the private repo holds only the token, the
  target repo list, the work list and thin callers.
- **Skills/subagents for others:** a Claude Code plugin (skills such as
  "a client/server pair the DataSHIELD way", DSLite tests, design-note
  template), usable locally and by claude-code-action (`plugins` input).
  If it comes: **its own repo**, so its clone count isn't drowned by the
  CI checkouts of the workflow repo. Name (user, 2026-10-21):
  **`nfdi4health/datashield-skills`**. **Created 2026-10-26** (public,
  GPL-3.0): plugin + marketplace of the same name, four skills —
  `client-server-pair`, `dslite-tests`, `roxygen-docs`, `design-note`
  (with `template.md`) — built from this repository's role guidance,
  DSLite setup and datasets, test categories and demo example; keep them
  in step when those change. `claude plugin validate` passes (no icon,
  only needed for a directory listing). Install:
  `/plugin marketplace add nfdi4health/datashield-skills`, then
  `/plugin install datashield-skills@datashield-skills`.
- **Being told when an agent finished something substantial** (user's
  wish, 2026-10-16): its results are issues/PRs, so GitHub's own
  notifications (e-mail or GitHub mobile push) cover it — the agent
  assigns or @-mentions the user. Optional, separate from GitHub's
  notification flood: a push service such as ntfy (one `curl` to a
  private topic at the end of the job) or a Slack/Matrix webhook; no
  SMTP setup needed as for e-mail.
- **KPIs:** workflow runs counted with `count-run` as now (also the agent
  workflows); plugin: daily clones / unique cloners from the traffic API
  (14 days back, admin token) stored by the KPI collector — an
  approximation (updates may count, one person on two machines twice),
  reported separately. No telemetry inside skills (would phone home from
  people's machines).
- **Already there, reusable:**
  - function index: `read_ds_package()` / `read_r_definitions()`
    (naming), `client_function_reference()` and the function catalogue
    (analysis bot) — signatures, docs, user-facing functions;
  - "refactor agent": `ds-naming-apply.yml` already applies the
    transformation config deterministically (code, tests, roxygen, Rd,
    vignettes); no LLM agent needed for that part;
  - markers in bot comments (`comment_once()`, `post_issue_once()`),
    capped and deduplicated bot issues (`report_sweep_code_issues()`).
- **Shared issue templates and their sync** belong to the private
  governance repo (rulesets already live there), not here.

## New processes (user's context, 2026-10-16)

The researcher and refactor agents are **separate processes**, not part
of the issue flow.

### Learning from what users keep

Not covered yet, and important for all bots: what users actually keep
(roxygen changes, tests, analysis scripts) should improve later answers.
No fine-tuning; three levels, each human-reviewed:

1. **Signals, per repository.** Already partly there: checkbox choices
   (kept / declined, `record_suggestion_choices()`), declined suggestions
   remembered per function, merged vs. closed bot PRs. Strongest signal,
   not yet collected: **what the user changed after merging** (the bot's
   proposal vs. the final file a few weeks later). Merging alone is weak —
   people merge without reading.
2. **Thresholds from data:** acceptance rate per reason and kind →
   `accept-reasons` per repository (the open "suggestion thresholds"
   item).
3. **Repository guidance distilled by Claude:** periodically, from the
   declines and post-merge edits, a short "house style" file (e.g. "no
   `\dontrun` examples", "tests use `withr` for temp files") proposed as a
   PR to the repository's own config override — the bot's equivalent of a
   CLAUDE.md, read into the prompts (cache-friendly, shared part). Kept
   accepted blocks/tests can serve as examples, as the test bot already
   does with example test files.

Privacy: learnings stay in their repository (they contain its code);
across repositories only counts, as with usage counting.

### Refactor agent (several jobs, better split)

1. **Performance of existing DataSHIELD functions**, with
   maintainability as a constraint. Measurable: dsBaseClient already has
   `perf` tests against stored profiles; a proposal must show the gain on
   them and keep the other tests green.
2. **New DataSHIELD functions built by Claude** — overlaps with the
   researcher (below); treat as its last stage.
3. **Refactoring this repository's workflows** — the review in
   [claude-workflow-review.md](claude-workflow-review.md) is a first
   manual round; an agent would propose PRs here.

The argument harmonisation is already deterministic
(`ds-naming-apply.yml`) and stays so.

### Researcher agent (gaps → DataSHIELD function pairs)

Find what researchers can do in plain R but not in DataSHIELD, research
how it could work federated and disclosure-safe, and build a client +
server pair. Example: cluster analysis, including searching the web and
papers for federated methods.

- **Overall DataSHIELD agent:** a gap catalogue across packages. Inputs:
  the function inventory (32 packages, `dev-notes/datashield-naming/`),
  references for "normal R analysis" (e.g. CRAN task views per theme),
  and **demand**: the analysis bot's `missing_function` gap issues are
  exactly what researchers wanted and couldn't do.
- **One agent per themed repository** (e.g. a cluster package): deeper
  research for its theme, then design, then implementation.
- **Stages with human gates:** gap list → design note (algorithm, what
  the server returns, **disclosure analysis**) → implementation PR with
  DSLite tests, including disclosure tests (nfilter settings). Disclosure
  control must be decided by people (and the DataSHIELD developers), never
  by the agent.
- **Surface:** a real agent (web search, papers, code, test runs, hours),
  so Claude Code (subscription) or Managed Agents, not single API calls.

## Points to settle before building

- **Prompt injection is mainly the implementer's risk**, not the
  reviewer's: the spec is derived from untrusted issue text and the
  implementer has write access. Beyond `bot-proceed`: no secrets in its
  job besides what it needs, a restricted tool list, PR only (never push
  to protected branches), the spec read from the bot's marked comment
  only, and the PR's normal checks and human review.
- **Label integrity** needs `issues: write` and an `issues: labeled`
  trigger; who may add `bot-proceed` (maintainers vs. triage-access
  collaborators) is the open question from the brainstorm.
- **Scope fit in triage:** a fixed enum value ("out of scope") with a
  reason is cheap to add; whether to act on it automatically is the
  decision.
- **Build order** from the brainstorm: label-integrity checks first
  (no Claude, small), then triage, then spec review; implementer last.
