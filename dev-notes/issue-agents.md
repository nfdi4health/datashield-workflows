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

More concrete version (2026-11-12): [feedback-loop.md](feedback-loop.md).

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

### A central hub for wishes and gaps (brainstorm with the user, 2026-11-11)

**Since 2026-11-13:** the hub is `nfdi4health/datashield-function-ideas`
(name chosen by the user; main only; the researcher on the user's
subscription). Built (not yet run): routing (`route-idea.yml`), the
researcher's pilot (`methods-scan.yml`, since 2026-11-16 `literature-watch.yml`), the gap links, the hub's basics
(README, issue forms, configs, callers). The rest below is still the
design.

**Where the researcher runs (user, 2026-11-13):** in the private runner
`FlorianSchw/datashield-agent-runner`, not in the hub. The runner holds
the subscription token (and the NCBI key) once, and its caller shares the
implementer's `concurrency` group, so the two never use the subscription
at the same time (GitHub keeps one pending run per group: a third start
while one runs and one waits replaces the waiting one). A public hub can't
call the private runner's workflow, so the hub's caller
(`literature-watch-start.yml`) checks the login and starts the runner's
workflow by `workflow_dispatch` with the bots' App (Actions: write on the
runner). The runner checks out the hub for its queries and proposes the
month's results to it by pull request
(App: Contents and Pull requests write on the hub). At the subscription's
usage limit the run stops asking and reports what it has.

**Files and name (user, 2026-11-16):** the workflow is the *literature
watch* (`literature-watch.yml`; "scan" read like a security scan). A run
takes all queries (or one); the month's results are two files under one
folder, the data (`literature-watch/data/YYYY-MM.yml`: IDs, titles and
method names per query, never the papers' text) and the report built from
it (`literature-watch/reports/YYYY-MM.md`), in one pull request per month;
a re-run of one query replaces only its entry. No mode or query in the
names. The `scans/YYYY-MM.yml` of the design below is this data file.

**Variants (user, 2026-11-16):** each method comes with a `variant`, how
the paper deviates from the plain method ("time-varying covariates",
"stratified", "penalised (lasso)"; empty for the plain one), kept apart
from the name so the counts stay clean. Reason: DataSHIELD often has the
plain method but not the variant, so the "Exists?" step below compares
method *and* variant, and the vocabulary maps variants too. The report
lists the variants named most often.

**Fields, sampling and the backfill (user, 2026-11-16; after the pilot
and PubMed's counts per year, which the user checked on the website):**

- **The pilot's answer:** abstracts name 70% of the main analyses but only
  18% (Sonnet, after the fixes: 14%) of the secondary methods, so the watch
  reads methods sections. Sonnet 5.5 reads (Haiku before); with the
  statistics subsection first, "named only in an abstract" fell from 184 to
  20 in the same papers.
- **The search:** `"Epidemiologic Studies"[MeSH Terms] AND (<field>) AND
  "pubmed pmc open access"[filter] NOT (review[pt] OR systematic review[pt]
  OR meta-analysis[pt])`; the design part and the filters are added by the
  code, the field part comes from the hub's config, as broad parent
  headings marked `[majr]` (MeSH explodes them, so e.g. "Cardiovascular
  Diseases" includes myocardial infarction and stroke).
- **Eleven fields** (from DataSHIELD's own publication list,
  papers.datashield.org, plus fields where it isn't used yet):
  cardiovascular, metabolic, mental-health, cancer, respiratory-allergy
  (without infections), infections (COVID-19 dominates 2020-2023),
  pregnancy-child, environment, nutrition, omics, lifestyle. Open-access
  research articles 2022-2026: from about 3,900 (environment) to 68,600
  (infections) per field, about 304,000 in all.
- **A random sample per field and publication month**, not the newest
  papers: all matching IDs of the month are listed once in a fixed random
  order (with their count, so shares scale to the month's total) and the
  first `target` are read. Raising the target later (25 -> 50 -> 75 ...)
  reads only the next ones in the same order, so the data is a clean
  random sample at every stage, and a month with fewer papers is simply
  complete. Stages: 25 per month for the last 5 years (newest first, about
  16,500 papers), then 50 for 10 years, then more as capacity allows,
  possibly everything as a slow drip.
- **A paper register:** each paper is read by Claude once, whichever field
  or month finds it again; per paper the IDs, publication month, journal,
  publication type, MeSH terms, PMC licence, the fields that found it and
  the methods with their variants; never the text.
- **Pace, measured 2026-11-16 on Max 5x:** 199 papers (about 40 Sonnet
  calls, 9.5 minutes) used 10% of a 5-hour session and about 1% of the
  week, so about 2,000 papers per session and roughly 20,000 per week.
  Default: one run a night, capped at 1,500 papers (about half the weekly
  limit stays free); settings in the hub's config (target per month, years
  back, papers per run) and a one-off override when started by hand (e.g.
  more over Christmas). Each run first reads the newest complete month,
  then uses what's left for the backfill, and stops at the usage limit.
- **Monthly runs read the month before last** (MeSH indexing and PMC
  deposits lag), 50 per field.
- **Ranking:** by share over the last 3 years, trend as tie-breaker; the
  10-year series is for trend lines and context. Trends by year (a month
  of 25 papers is too noisy), as shares, never counts (volume tripled
  2017-2025); 2022-2023 marked in charts: all fields dip there, most likely
  NLM's switch to automated MeSH indexing.
- **Models:** Sonnet reads the papers; Opus classifies the names, decides
  "Exists?" and does the research step (about 10 calls a month).
- **For the user's meeting on 3 December:** the first stage's data and
  report (11 fields, 5 years, trends, variants); a candidate list only if
  the "Exists?" step is built and has run by then.

**Classification and "Exists?" by Claude, no per-entry review (user,
2026-11-16).** Nobody has time to check dozens of vocabulary entries or
mappings by hand, and nobody knows every DataSHIELD function by heart. So
Claude does both jobs with a stronger model, and safeguards in code take
the place of a person's review:

- **Who does what:**
  - Sonnet reads the papers (step 2; Haiku until the pilot, 2026-11-16).
  - **Opus 5.5** classifies the month's new free-text names: which are the
    same method, method or variant, new method. This is few calls, only the
    names not yet in the vocabulary.
  - **Opus 5.5** decides "exists in DataSHIELD?" for method *and* variant:
    `yes`, `partial` (e.g. only per study, not pooled; or only some
    options), `development` (only in a development or GitHub-only package),
    `none`, or `unclear`.
- **What it reads for "Exists?":** the candidate DataSHIELD functions' own
  documentation (title, description, arguments) from the function
  inventory, refreshed from the package catalogue (packages.datashield.org)
  each run, and the catalogue's package status (production / development
  / retired). R preselects the candidates by name and keywords, so Claude
  gets a short list, not 1,000 functions.
- **Safeguards instead of a review:**
  - **Evidence required:** every `yes` / `partial` / `development` names the
    function and quotes the line of its documentation that shows it. R
    checks that the function is in the inventory and that the quote occurs
    in its documentation. If either fails, the verdict becomes
    `unconfirmed`, never `yes`.
  - **Unsure stays unsure:** `unclear` is a valid answer. It is listed as
    such, neither hidden nor counted as a gap.
  - **Stable:** verdicts and classifications are stored with their
    evidence (in the vocabulary file) and asked again only when the
    function inventory changes or a method's names change, so the answers
    don't drift from run to run.
- **What people see:** only the monthly short list of the top candidates
  with their verdict and evidence. Questioning a wrong verdict there is one
  entry, not a list to check. The vocabulary file grows by itself; nobody
  ticks boxes for it.
- **Not decided yet:** the granularity rule (when a variant becomes a
  method of its own; draft: when it needs its own DataSHIELD function) and
  whether `partial` counts as a gap for ranking. To be settled with real
  examples from the pilot.

Originally: not built; no repository yet. Problem: the community had no natural place
for gaps, demand and who works on what (an Excel file in someone's cloud,
hard to keep up). Idea: one public repository as the entry point for wishes
not aimed at a specific package.

- **Owner:** `nfdi4health` (the user's funder; the user co-leads the
  statistical development theme). Transfer possible later. **Name: TBD.**
- **Content:** issues for concrete wishes (two templates: analysis method /
  other, e.g. utilities), maybe Discussions for vague ones; a GitHub
  Project as the overview (theme, status, target package, who works on it,
  demand). Demand: reactions, paper counts, the analysis bot's gap issues.
- **Scope of automation:** the researcher agent and the analysis bot only
  produce analysis-function wishes; utility wishes come from people.
- **The analysis bot's gap issues go there:** change `gap_issue_repo` in
  `config/analysis-suggest.yml` and add an issue template in the hub.
  Checked: the link carries only the step title and the note on what is
  missing — no plan, study or repository name; the analyst opens the issue
  under their own account (visible username, their own choice). The step
  title can still reveal a research question: the template should ask for
  the method only, and the title should be the method, not the step.
- **Routing:** a label per topic package (e.g. `dsClusterAnalysis`) maps,
  via a config list, to a repository; the workflow copies the issue there
  (GitHub's transfer only works within one owner) with a link back; the
  hub issue stays open as the demand record, status mirrored back. Who may
  route: an `allowed-logins` label check as for `bot-proceed`. Light hub
  triage (new? exists already? which package? duplicate?); the full spec
  comes from the target repository's own triage. **Issues only** as the
  first level; later perhaps fork → new function → PR via the implementer
  for repositories the user doesn't control.
- **Researcher, monthly:** PubMed and PMC (NCBI E-utilities, free) with
  named queries in a config file (not settled yet; tried on the PubMed
  site first, a dry run in the hub), only papers since the last run →
  method extraction with a cheap model against a controlled list →
  normalisation (synonym list, a stable method key) → exists in DataSHIELD
  (catalogue, function inventory, hub issues) → exists in native R (CRAN
  task views, CRAN database) → deeper research (federated approaches,
  first disclosure view) only for the top candidates.
- **No flood: a monthly PR**, like the roxygen and test bots' PRs. It adds
  a data file (e.g. `scans/2026-11.yml`: methods, counts, existence,
  decisions), which over the months is the trend record. The description
  lists at most `max_candidates` (10, config) new candidates: name, short
  description, paper count and trend, two or three example papers, exists
  in DataSHIELD (no / partly, package), native R package.
- **Three boxes per candidate (user, 2026-11-11):** *open issue* (on
  merge), *not now*, *don't suggest again* (back only if its paper count
  clearly rises, e.g. doubles, config). **Exactly one per candidate,
  required** (user: "a fan of actually taking a decision"): a status check
  fails while a candidate has none or more than one, so the PR can't be
  merged undecided.
- **"Not now"** candidates are listed every month in a "Deferred" section
  outside the 10 slots, with their own boxes; staying deferred needs no
  new tick there.
- **Filtered before the top 10** (the next candidate moves up): an open
  hub issue, one closed as completed or as not planned, *don't suggest
  again*, deferred ones (in their own section). Exact via a hidden marker
  with the method key in every issue the workflow opens; for issues people
  opened, Claude matches against the open issues (an enum of real numbers,
  like the analysis bot's `existing_issue`) and the marker is added. Demand
  for tracked methods still goes into the data file, and a short list
  without boxes ("already tracked: #12, 41 papers, rising") ends the PR;
  no monthly comments on issues.

#### Researcher pipeline sketch (Claude, 2026-11-11; not decided)

Reusable workflows and R functions here, like the other bots; the hub holds
a thin caller, its configs and the data files (another community could run
its own hub). Claude only where code can't decide; cheap before expensive.

```
                    monthly schedule / manual run (dry-run option)
                                     |
literature-watch (was methods-scan)
 0 State      R      last run date, decisions (data files), hub issues
                     and their method markers, vocabulary
 1 Fetch      R      PubMed/PMC E-utilities per query since last run
 2 Extract    Sonnet batches of papers -> methods with variant
 2b Classify  Opus   the month's new names -> same method / variant /
                     new method (written into the vocabulary)
 3 Count      R      per method and variant: papers, share, trend
 4 Exists?    Opus   method and variant against the function docs
                     (R preselects, checks the evidence); stored with
                     its evidence, asked again when the inventory changes
 5 Rank       R      drop filtered -> top max_candidates (10)
 6 Research   Opus   only those: description, federated approaches in
                     the literature, native R package, first disclosure
                     view (web search)
 7 Propose    R      scans/YYYY-MM.yml + PR, three boxes per candidate
PR edited -> methods-choices: exactly one box each -> commit status
PR merged -> methods-issues: open issues (method marker), record decisions
```

- **Fetch:** NCBI allows 3 requests/s without a key, 10 with a free key
  (optional secret); a cap per query in the config.
- **Extract:** the Message Batches API suits a monthly job (results within
  hours, cheaper; check current prices before deciding).
- **Count:** relative to the month's total, else a month with more papers
  looks like rising demand.
- **Exists?:** by Claude (Opus) with evidence, see "Classification and
  'Exists?' by Claude" above; the vocabulary file keeps the verdicts, so
  most later answers are lookups. ~~`config/methods.yml` maps method →
  known DataSHIELD functions and R packages, curated by hand~~ (replaced
  2026-11-16).
- **Propose:** the PR lists the top candidates with verdict and evidence
  (three boxes each) and "Already tracked" (counts, no boxes). ~~"New
  method names" with one decision box each~~ (replaced 2026-11-16: Claude
  classifies the names, no boxes for the vocabulary).
- **Files in the hub:** `config/literature-watch.yml` (queries,
  `max_candidates`, doubling rule, caps), the vocabulary (maintained by
  the workflow: method, synonyms, variants, DataSHIELD verdict with
  evidence, R packages; path to be decided, e.g.
  `literature-watch/vocabulary.yml`, since it is data, not a setting),
  `literature-watch/data/YYYY-MM.yml` and `reports/YYYY-MM.md`.
- **Abstract or methods section — open, a pilot decides.** Structured
  abstracts usually name the main model (Cox, logistic, mixed models) but
  rarely secondary methods (imputation, splines, propensity scores,
  weighting) — often exactly the DataSHIELD gaps. Full text only exists
  for the PMC open-access subset (biased) and is much larger; the methods
  section can be cut out of the JATS XML by code. Likely a hybrid: the
  abstract for every paper, the methods section where open-access full
  text exists, the source recorded per method.
- **First run vs. regular runs (user: the first real run has a lot more to
  do)** — phases, each ending with something the user looks at:
  0. **Pilot:** ~100 open-access papers, methods from abstract vs. methods
     section compared; a report, nothing committed.
  1. **Vocabulary round:** seeded from the function inventory and the CRAN
     task views; extraction on a sample (one month); Claude classifies the
     names and decides "Exists?" (2026-11-16); the PR shows the resulting
     vocabulary for a look, no candidates and no boxes.
  2. **Backfill:** e.g. 12 months, one chunk per month, each writing its
     own `scans/YYYY-MM.yml`, so a failed run resumes at the next missing
     month; counts only (no research step, no candidate PR); the 6-hour
     job limit may need "submit batches" and "collect results" in separate
     runs (batch IDs in a small state file); a cost cap (papers per run).
  3. **First candidate PR** with trends from the start, still at most 10.

  Then regular months are small. Manual-run input `mode`: `pilot` /
  `vocabulary` / `backfill` / `monthly`, plus `since` for the backfill;
  the schedule always runs `monthly`.
- **Open:** API with WIF (fits structured, plain API work) or the
  subscription for the research step; size of the first trial; how deep the
  research step's disclosure view goes (a first impression; the real
  disclosure work belongs in the design note later).

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
