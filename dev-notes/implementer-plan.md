# Implementer: what is agreed, what is open (2026-11-09)

The next step of the issue flow, after the label check and triage. Nothing
here is built yet. The code that exists is in the private
`FlorianSchw/datashield-agent-runner` (two jobs: `implement` runs Claude and
can't write, `publish` is a clean machine that opens the PR), not yet run for
real; its scripts move here when building starts. Background:
[issue-agents.md](issue-agents.md). Decided with the user on 2026-11-06 and,
in one round going through all open points, on 2026-11-09.

## Flow

1. **Triage** sets its category label plus `bot-triaged`, and writes the spec
   (bugs and ideas). For DataSHIELD **ideas** the spec gets a disclosure
   section: which settings apply, from the list in
   `config/ds-package-rules.yml` (`function.server.disclosure.settings`; the
   file and path are a setting in `config/issue-triage.yml`, never
   hard-coded), and what happens below the threshold, or "no fitting option:
   needs your decision". A suggestion of the user's in the issue or a comment
   becomes the chosen one. Bugs keep the existing disclosure. Triage reads
   documentation, not code, so this is a proposal the implementer checks.
2. **The user sets `bot-proceed`**, the only manual step besides merging.
   `issue-label-check` keeps it only if an allowed login set it (so nobody
   else starts runs on the subscription); a second job of that workflow then
   sends `workflow_dispatch` to the runner. Everything after that runs on its
   own.
3. **The runner** verifies the approval itself: the bot's newest triage
   comment is the spec (no `<!-- agent-spec -->` marker), `bot-proceed` was
   last set by an allowed login, the spec is unchanged since.

No spec review step and no second approval.

## Decided by the user

- **Disclosure control:** the implementer follows the spec's choice and
  suggests details; the user decides in PR review. The PR description has a
  disclosure section: what leaves the server, the options used, what happens
  below the threshold, rejected alternatives, open doubts.
- **Disclosure reviewer:** works out what the server returns from the code
  first, then compares with the suggestion. The PR shows both views.
  Disagreements never go back to the writer.
- **Writer and two read-only reviewers** (disclosure, maintainability), all in
  the `implement` job. The maintainability check covers refactoring too (no
  separate refactor stage). Deterministic checks (tests, R CMD check) run in
  the job.
- **Two correction rounds** (2026-11-09, was one): clear problems from the
  checks and the maintainability reviewer go back to the writer, the
  reviewers check only those fixes. Matters of taste become PR comments.
- **Bots never close issues.** People do, by merging (`Refs`, see below).
- **The implementer's only source is the bot's newest triage comment**, as a
  spec of the conversation. Outsiders' text never reaches the agent that runs
  commands: triage reads it but can only fill in fields, and what it writes
  goes through `plain_comment_text()`. After a discussion, `bot-triage`
  refreshes the spec; the user reads it, then sets `bot-proceed`. What the
  spec misses, the implementer doesn't know.
- **New functions: open, for another day.** The 2026-11-06 rule (stop at a
  design note) and the runner prompt's "commit nothing" are replaced: with
  `bot-proceed` a new function means code and a PR. Whether triage writes the
  design note, and how (it can't load skills; its sections would be config
  here, the skill's template watched by the sync check), is not decided. The
  user's idea: name a native R package as the starting point of the
  implementation.

## Queue

- **The approved issues are the list:** `bot-proceed` without
  `bot-in-progress`, oldest approval first (label time from the timeline).
  One issue per run, `concurrency` one run at a time.
- **Chained:** at the end of a run the runner dispatches itself
  (`GITHUB_TOKEN` may start `workflow_dispatch`); an empty list ends the
  chain quietly. GitHub keeps only one waiting run, so dropped dispatches
  don't matter: the next run finds the issue anyway. Six approvals are done
  one after another, in approval order.
- **Start:** the dispatch after the label check, or by hand. **No scheduled
  run** of the implementer (user, 2026-11-09; replaces the daily run decided
  earlier the same day).
- A failed issue doesn't stop the chain; the next one starts.

## Labels and what the issue shows

| State | Labels |
|---|---|
| waiting | `bot-proceed` |
| running | `bot-proceed` + `bot-in-progress` |
| done | `bot-completed` |
| failed | `bot-failed` |
| needs the user's input | `bot-needs-input` |

`bot-proceed` stays during the run; completion and failure remove it (the
approval is used). The runner **never sets `bot-proceed`**: the label check
would remove it (the App isn't an allowed login), and the approval check
needs the user's login. A retry is the user setting it again; the run then
removes `bot-failed`. The labels go into repo-governance's
`labels/labels.json` with `bot-triaged`.

How a run ends:

- **Completed:** a normal PR into `dev` with `Refs #n` (see below), the
  reviewers' open points and the disclosure section listed.
- **Failed** (checks still failing after two rounds, a technical error): a
  **draft PR** with the partial code (can't be merged by accident; the bots
  skip it) and one comment: what was tried, which check failed with its key
  lines, the reviewers' remaining points, what would unblock it, a link to
  the run (private). If Claude Code wrote no summary, the runner writes a
  short one.
- **Needs input** (the code contradicts the spec's disclosure choice, or the
  spec is unclear): no code for that part, `bot-needs-input`, and a comment in
  a `> [!IMPORTANT]` box with what is unclear, the options seen and exactly
  which answer is needed. The answer leads to a new triage (spec updated),
  then `bot-proceed` again.

**Draft PRs and the bots, in every repository:** the roxygen, test and
authors callers skip draft PRs (`!github.event.pull_request.draft`) and add
`ready_for_review` to their triggers, so they run once a person marks a draft
ready.

## Subscription limits

Claude Code ends with an error at a limit (no `CLAUDE_CODE_RETRY_WATCHDOG`,
nothing waits inside the private repository). The runner tells it from other
failures by Claude Code's message, which carries the reset time (format to
confirm in the first test). Then: `bot-in-progress` removed, `bot-proceed`
stays (the approval stands, the issue keeps its place), no comment on the
public issue, an entry in the log, the chain stops. Nothing was pushed, so the
next attempt starts from scratch.

- **5-hour limit:** the runner starts a timer workflow in the target
  repository whose issue hit the limit (public, so its waiting is free), with
  `repository_dispatch` and the App token (contents: write, which it has). The
  timer sleeps until the reset plus a few minutes, then dispatches the runner.
  A hosted job runs at most 6 hours, enough for this.
- **Weekly limit:** logged as "paused until <date>"; the next approval or a
  manual start continues. No chained timers.

## Security

- The subscription token (`claude setup-token`, valid a year; personal Pro
  plan, maybe Max later; the model is an input, Sonnet 5.5 on Pro) sits only
  in the private runner repository.
- **The existing GitHub App** gets **Issues: read and write** (labels,
  comments); it has contents and pull-requests already. `implement` gets a
  read-only token, `publish` the writing one.
- **Network:** harden-runner is out (its free tier covers public repositories
  only). Claude Code's own sandbox runs Claude's commands with network access
  only to a host list, starting from the cloud environment's: CRAN, P3M,
  Posit Package Manager, Bioconductor, GitHub and its download hosts. The R
  library is installed before Claude starts (outside the sandbox); new
  packages go into a library inside the working folder. GitHub's own egress
  firewall (preview) later. First test: a DSLite test, R CMD check, an
  install, and a `curl` to an unlisted host, which must fail; `env` in
  Claude's shell must not show the token.
- **Dispatch token: one App** (user, 2026-11-10; replaces a separate
  small App, since three Apps would mean six secrets per repository): the
  bots' existing App got **Issues** and **Actions: read and write** and is
  installed on the runner repository too. The label check and the timer use
  the `APP_CLIENT_ID` / `APP_PRIVATE_KEY` the target repositories have
  already (nfdi4health: possibly as organisation secrets, then a new
  repository needs none), and make a token with only Actions, only for the
  runner repository. Cost: whoever can write to a target repository's
  workflows can mint a token with the App's other permissions on the runner
  repository too: starting runs (harmless, each run checks the approval),
  changing ordinary files and the `log` branch; not the workflow files (the
  App has no Workflows permission) and not the secrets, so not the
  subscription token. The implementer's commits carry the bots' name; its
  branches (`agent-suggest/`) tell them apart. (`repository_dispatch` into
  the runner stays rejected.)

## Cost: Actions minutes

The runner repository is private, so its runs use the account's monthly
quota (the defaults stop jobs when it is used up, no bill). A run is roughly
30 to 60 minutes per issue (estimate). Every job gets `timeout-minutes`;
nothing waits inside the private repository; no schedule there except the
log job. Measure from the log before deciding on a self-hosted runner.

## Log

On a `log` branch of the runner repository (for the record; the runner works
from the labels):

- `events.json`: one entry per event, sorted by repository, issue, time.
  **Append-only:** entries are never changed or removed, duplicates are
  recognised by a key (repository, issue, event, time, and the actor for
  label events), so nothing is lost when an issue, a run or its logs disappear
  from GitHub.
- `status.csv`: one row per issue, latest state and the durations (opened to
  `bot-proceed`, to the PR, to merged into `dev`, to released), rebuilt from
  `events.json`.
- **A daily job** (Node, about a minute) adds what the issue timelines (label
  changes with actor and time, the PR, closing; `next-release` and `released`
  from release-issues) and the runner's own runs (start, end, duration) show.
  It follows every issue that is or was in the flow until it is released or
  closed. Plus a keepalive job.
- **The runner adds at the end of each run** what no API knows: result,
  reason, correction rounds, pause and reset time.
- May move to `datashield-kpi-reporting` later (undecided).

## Where it is built

| Repository | What |
|---|---|
| datashield-workflows | the implementer as a reusable workflow (credentials as inputs; queue, verify, sandbox, publish, labels, comments), the timer, the dispatch job in `issue-label-check.yml`, triage's `bot-triaged` and disclosure section, the draft skip in the bot workflows |
| datashield-skills | procedure knowledge the implementer loads; follows this repository's config through its sync check |
| datashield-agent-runner (private) | subscription token, allowed login, target list, a thin caller, the log and its daily job |
| target repositories (dsSupportClient first; all testing there) | callers: label check with dispatch, triage, timer, release-issues |
| repo-governance | the labels |

**Build order:** the basics (one issue on a manual start, sandbox, publish,
labels), then reviewers and correction rounds, then queue, dispatch and timer,
then the log, then triage's additions, then the draft skip.

**The user, before the first test:** done 2026-11-10: Issues and Actions
permission for the App (accepted on both installations), the subscription
token and the App key as runner secrets.

## Overlap with datashield-skills

Facts and lists are defined in this repository's config; skills may repeat
them, since Claude Code can't read this config in a target repository, but
every repeated source file is listed in datashield-skills'
`sync/sources.json`, whose daily check opens an issue when one changes.
`ds-package-rules.yml` and `ds-argument-rules.yml` added there 2026-11-09
(nfdi4health/datashield-skills#1). `ds-package-rules.yml` is meant as the
community's complete source of truth.

Found and left for the community round on the rules: test categories exist
twice here, `config/test-categories.yml` (8) and `ds-package-rules.yml`
`tests.category` (9, plus `dgr` and the `bug` qualifier), and `datachk` means
different things in the two. The test bot keeps `test-categories.yml` until
that is settled.

## Agreed, to build in the runner

- ~~**Closing an issue:** `Closes #<issue>` in the commit message and the PR
  description.~~ **Changed (user, 2026-11-09):** the agent only mentions the
  issue: `Refs #<issue>` in its commits and the PR description, with a note
  that a person changes it to `Closes #<issue>` once the work is done.
  Unfinished work (reviewers disagree, follow-ups) then never closes the
  issue. `publish` strips every closing keyword from Claude's text, the
  issue's own too. The closing itself is `release-issues.yml` (built
  2026-11-09): `mark` on a PR merged into `dev` labels the issues its
  description or commits close `next-release` (GitHub ignores the keywords
  outside the default branch; a mere `Refs` doesn't count); `link` writes
  `Closes #n` for those into the `dev` → `main` PR's description before the
  merge, which closes them; `swap` relabels them `released` after it. No
  commit on `dev` is needed. Untested so far: whether GitHub closes issues
  when `merge-pull-request.yml` merges with `GITHUB_TOKEN`.
- **Branch and commit type:** `agent-suggest/fix/issue-<n>` with `fix:` for an
  issue labelled `bug`, `agent-suggest/feat/issue-<n>` with `feat:` for
  `enhancement`. Any other label stops the run. Set by `publish` from the label,
  never by Claude: the type decides the version. The label is the user's way to
  correct triage before approving. Replaces `branch_prefix` `agent/issue-` in
  `config/runner.json`.
- ~~**`cleanup-suggestion-branch.yml`** has to learn `agent-suggest/`.~~
  Done 2026-11-09 (also only branches of the repository itself, not a
  fork's of the same name; this repository calls it too,
  `cleanup-agent-branches.yml`). The
  roxygen, test and authors bots run on these branches, unlike
  `bot-suggest/` (drafts excepted, see above).

## Targets, branches, client/server pairs (user, 2026-11-10)

**Built 2026-11-12 (branch `agent-suggest/feat/implementer-batch`):**
`branch` (old `base` still read) and `server-branch`, both defaulting to
the repository's default branch; GitHub's issue type first
(`issue-types`), then the labels in order (`type-labels`, feature beats
fix, the writer gets a note to do both parts); `open-pull-request`;
the writer is told to stop and ask when the server package needs a change;
the runner reads the triage's `<!-- bot-triage-affects: … -->` marker
(server-only and both are refused with a note). The triage side of the
Affects line is a separate PR.

- **Other branch models:** not everyone works main / dev / feature. Each
  target says where work starts and where the pull request goes, one
  setting: **`branch`** (renamed from `base`, which only the runner's caller
  used). Left out: the repository's default branch (read from GitHub),
  never an assumed `dev`, and never a guess at "the latest branch". Setting
  it explicitly is fine and expected (dsAnalysis may name one too).
- **The server side as flat, individual settings**, not a nested object:
  `server` (owner/name) and `server-branch` next to `branch` in a
  target. A client/server pair has one owner
  (user: always so in practice), so one App installation and one token
  cover both; the App needs access to both repositories.
- **Server-only changes** (e.g. performance): the issue is opened in the
  server repository, which is then a target itself. Utility packages
  (dsAnalysis) are targets without a server.
- **Branch names and titles stay the standard:** `agent-suggest/<type>/issue-<n>`
  and `fix:` / `feat:`, for every repository.
- **Both `bug` and `enhancement`: feat beats fix** (user, 2026-11-10):
  `type-labels` becomes an ordered list, the first match decides (default
  `enhancement` → `feat`, then `bug` → `fix`); branch and pull request
  title take that type, the writer is told both parts are wanted, and its
  commits keep their own types. Today such an issue is refused.
- **GitHub's issue type instead of labels** (user agrees, 2026-11-10; not
  built): the issue type field (Bug, Feature, Task; set per organisation)
  is one value, so it can't conflict like two labels. The runner would take
  `fix` / `feat` from the type (Bug → fix, Feature → feat), and fall back to
  the labels (feat beats fix) where a repository has no types (personal
  accounts have none). Triage could set the type instead of, or besides,
  the label.
- **`open-pull-request`** (input, default `true`): `false` pushes the branch
  only and puts the comparison link, summary and reviews in an issue comment;
  labels as with a pull request; the cleanup never touches such a branch
  (it acts on closed pull requests). Re-targeting a pull request
  (Edit → base) keeps it open, so the cleanup doesn't touch it either.
- **Names confirmed (user, 2026-11-10):** `server` and `server-branch`.
- **Triage says which repositories are affected** (user, 2026-11-10), so the
  question comes before `bot-proceed`, not after a run: the triage caller
  gets the same input `server`; with it, the spec of a bug or idea ends with
  an "Affects" line — *this repository only* (default), *this repository
  and `owner/server`*, or *only `owner/server`* (then the issue belongs in
  the server repository). A proposal from the documentation (a server
  function `…DS` named, disclosure settings involved, results computed on
  the server), corrected like the rest of the spec (comment, `bot-triage`);
  visible text plus a hidden marker with the value, which the runner reads.
  Without `server` (utility packages, servers themselves): no line.
- **The implementer follows the line:** *this repository only* — as now,
  and the writer stops and asks if the code shows a server change is needed
  after all; *both* — no run until pair changes exist (a short note on the
  issue, no minutes spent), then the pair run; *only the server* — no run,
  a note to open the issue in the server repository.
- **Now:** the writer stops and asks (`bot-needs-input`) when a fix would
  need a server change; the server checkout is read-only, for the disclosure
  reviewer.
- **Later, after the first live test:** pair changes in one run — the issue
  in the client repository, both checkouts writable, the changed server
  installed for the tests, two pull requests with the same branch name
  (server first, links both ways; the client PR's own CI tests against the
  server's branch until the server PR is merged).

## Disclosure review: deviations go back, judgement stays (user, 2026-11-10)

**Built 2026-11-12 (branch `agent-suggest/feat/disclosure-deviations`):**
the disclosure review runs after round 0 (ending in a JSON block of
deviations, `splitDisclosureReview()` → `.agent/review-disclosure.json`);
deviations start a correction round like a must-fix point
(`nextRound()`, round 0 only); after correction rounds a re-check
(`disclosure-recheck`) updates the review and the open deviations, which
then appear as a warning at the top of the pull request.

The first run showed the question: if writer and disclosure reviewer
disagree, who corrects? Until now (decision of 2026-11-06) nothing went back
to the writer, and the user settled everything in PR review.

- **The disclosure reviewer sorts its findings:** *deviates from the spec*
  — the code does what the approved spec doesn't cover (new data leaves the
  server, a check removed or weakened, another threshold), checked against
  the spec's disclosure part, which the user approved; and *judgement* —
  doubts, alternatives, what the spec leaves open.
- **Deviations go back to the writer** like a maintainability `must_fix`,
  within the same correction rounds; the disclosure review therefore runs
  after round 0 too, and later rounds check only whether its deviations are
  fixed. One still open after the last round: a clear warning at the top of
  the pull request, or `bot-needs-input` if it is fundamental.
- **Judgement stays for the user** in the pull request, as before. The agents
  don't decide disclosure among themselves; they only enforce what the user
  approved.
- **Later:** sending a pull request back for another round (e.g. a
  `bot-revise` label set by the user, the review comments as input). A new
  run refuses an issue with an open, non-draft pull request today. Open:
  what the agent may read from pull request comments.

## The agents' definitions (user, 2026-11-10; built 2026-11-12)

The writer and reviewer prompts (`prompts/implementer-*.md`) are first
drafts. The maintainability reviewer in particular should cover more than
bugs and obvious maintainability problems, and not repeat what the roxygen
and test bots already review on the same pull request:

- **Linting and style:** the package's own style, `lintr` / `styler` where
  the package uses them (a deterministic step may be better than the
  reviewer reading for it).
- **Human readability:** names, structure, length of functions, comments
  where the code isn't self-explaining.
- **Reuse:** use the package's existing helpers and the functions of its
  dependencies (DataSHIELD client functions, `dsBaseClient`, …) instead of
  re-implementing them in base R.
- **Consistency** with the package's conventions (argument checks, messages,
  file layout).

Where the definitions live is part of it: the procedure may belong in
`datashield-skills` (a reviewer skill or agent definition, usable locally
too), the facts in this repository's config, the workflow only wiring them
(see "Overlap with datashield-skills").

**Built 2026-11-12** (branch `agent-suggest/feat/agent-definitions`, not yet
run):

- **Lints as a deterministic step:** `run-checks.sh` calls `lint-changes.R`,
  only on the lines the change added (`git diff -U0 origin/<base>...HEAD`),
  into `.agent/lint.md`: with the package's own `.lintr` if it has one,
  else layout linters only (braces, spacing, parentheses, trailing
  whitespace) — naming and assignment style stay the package's (the default
  linters would flag dsBaseClient's `ds.mean` and `=`). Lints don't count in
  the checks' `ok`; the reviewer turns them into `must_fix` points (or
  explains a false alarm), so the round logic stays as it is. `styler` not
  used: a reformatting step would touch lines the change didn't.
- **Where the definitions live (user, 2026-11-12):** the standard is the
  `r-code-style` skill in datashield-skills (usable locally too): the
  package first, reuse before writing (package helper → dependency → base R
  → a new dependency only for real work), efficiency where it matters
  (server round trips on clients; local work on aggregates: readability
  wins), readable names and functions, layout (blank lines between steps,
  braces, spacing). Its sync sources: `lint-changes.R` and the
  maintainability prompt. The prompts name the skill and keep only what is
  workflow-specific (scope, what not to review, the JSON answer).
- **Maintainability reviewer** (`prompts/implementer-maintainability.md`):
  reads the package and the skill first; looks for bugs, fidelity to the
  spec, reuse and efficiency, consistency (argument checks, messages,
  `datasources`, layout, naming), readability and layout, tests and the
  lints. Leaves out roxygen wording and further tests (the roxygen and test
  bots review the same PR) and disclosure (its own reviewer). A `must_fix`
  point names the helper or convention it means.
- **Writer** (`prompts/implementer-writer.md`): the skill up front, so
  fewer points come back.

## Tests from the spec, follow-ups, refactoring (user, 2026-11-12)

The "independent oracle" of the roles proposal below, built first
(branch `agent-suggest/feat/agent-definitions`, not yet run):

- **Tests from the spec, in a separate session before the writer** (input
  `oracle`, default true; `prompts/implementer-oracle.md`): the agent sees
  the spec, the code as it is and the existing tests, never the fix. It
  writes the tests the spec needs (a bug: reproduces it; an idea: the new
  behaviour, its edge cases and disclosure behaviour), expected values from
  the spec or computed independently (for DataSHIELD: plain R on the pooled
  data against the federated DSLite result), commits them as `test:` and
  leaves notes. `run-oracle.sh` throws its work away if it changed anything
  outside `tests/`, runs its test files on the code as it is and writes
  `.agent/oracle.json` / `oracle.md` (how many failed before: none failing
  for a bug means it isn't reproduced).
- **The writer makes them pass and may not change them** (`{{ORACLE}}` in
  its prompt): a test it thinks wrong stays, with the reason under "Tests I
  disagree with" in its summary; a person decides. `run-checks.sh` fails the
  checks when the oracle's files differ from its commit, so the change goes
  back in a correction round. The PR shows a "Tests from the spec" section.
- **Follow-ups:** the writer may reshape the code it changes (behaviour and
  disclosure as the spec says); code outside the change is never refactored
  in the same run, but listed under "Follow-ups" in its summary (file and one
  line each), so a person can open issues. The maintainability reviewer
  flags refactoring outside the change. So there is no separate refactor
  or performance stage: the reviewer judges efficiency within the change
  (`r-code-style`), the rest is follow-ups — later perhaps for the refactor
  agent of `issue-agents.md`.
- Open from the roles proposal: pooled data for packages without DSLite
  test data; a spec / plan agent; N solvers and the comparator.

**Documentation and tests inside the run (user, 2026-11-12).** Considered:
the roxygen and test bots committing straight into the implementer's PR, with
the report as a PR comment. Rejected: a comment with code in it doesn't get
read, and updating documentation and tests belongs to fixing a function or
adding a feature. So:

- tests early: the tests from the spec (above) and the writer's own;
- documentation last: a documentation step after the correction rounds
  (`prompts/implementer-roxygen.md`, `roxygen-docs` skill, only the
  functions the change touched, only `#'` lines, `roxygenise()`, `docs:`
  commit). `run-docs.sh` drops its commits if they change anything but
  roxygen lines, `man/` and the RoxygenNote, or if the checks, run again,
  pass no longer. The PR gets a "Documentation" section (one line);
- ~~the roxygen, test and authors bots skip `agent-suggest/<type>/issue-<n>`
  (`resolve-suggestion-scope.sh`)~~ Changed 2026-11-13 (user): the bots
  review these branches, but leave out the implementer's own commits by
  author (`datashield-implementer` in `bot_names`, `config/bot-authors.yml`);
  a person's later commits there are reviewed.

## Triage, found in the first implementer test (2026-11-10)

- dsSupportClient #83 (only the `method` part of the open #58) stayed
  `duplicate` of #58 after the maintainer's comment that it is split out on
  purpose. Wanted: an allowed login's objection to a duplicate verdict is
  decisive (prompt and/or a field), so a deliberate split isn't blocked.
  This time #83 was closed as a duplicate and #58 itself triaged with
  `bot-triage`. **Built 2026-11-12:** a maintainer's comment (a login in
  `allowed-logins`) is named "a maintainer" in the prompt, which says that
  such a "not a duplicate" decides; such a comment also starts a new
  triage after duplicate, spam or out-of-scope.
- **Answers to open questions start a new triage** (user, 2026-11-10;
  built 2026-11-12 on `agent-suggest/feat/triage-affects-questions`). Today, after `bug` or `idea`, only `bot-triage` repeats a
  triage, so a spec's open questions (dsSupportClient #58) can't be answered
  by comment. Wanted: a triage comment whose spec has open questions carries
  a second hidden marker (e.g. `<!-- bot-triage-open-questions -->`; the
  first-line marker stays, the gate, runner and related-issue reader rely on
  it); then a comment by the issue's author or an allowed login starts a new
  triage, with the usual wait. Other people's comments don't (the maintainer
  approves the spec). The comment says so under the open questions. No
  label: the issue keeps `bug` / `enhancement`. A spec without open
  questions stays as it is.
- **One answer-triage beyond the limit:** after a spec with open questions,
  one such triage is always allowed, even when `max-triages` is reached; if
  it again ends with open questions, the normal limit applies. `bot-triage`
  stays unlimited.

## Open for the refactoring: roles proposal (from another chat, 2026-11-11)

Not decided. A proposal for how the implementer (and the analysis bot)
could be structured, recorded as an open question for the refactoring pass.
The user likes the three-solver setup.

**Roles:**

- **The workflow orchestrates**, not an LLM: fixed steps, artifacts handed
  from job to job.
- **Spec / plan agent:** turns the triage spec into a structured file
  (`spec.json`: what changes, inputs, expected behaviour, edge cases).
- **Test / oracle agent:** never sees solver code. Writes the reproducing
  test and a reference result — for DataSHIELD, plain R on the pooled data
  against the federated result in DSLite, within a tolerance. For a bug,
  the test must be confirmed **failing before** any solver starts.
- **N solvers** (usually 3; N by risk, N = 1 for small bugs), isolated
  (`strategy.matrix` jobs or worktrees), deliberately diverse (framing,
  model).
- **Deterministic gates:** testthat, R CMD check, lintr, federated vs
  pooled comparison, disclosure check.
- **Comparator, mostly deterministic:** agreement across candidates, extra
  edge-case inputs, old vs new on unrelated inputs, prefer the smallest
  diff; disagreement goes to the human.
- **Fresh, narrow reviewers** (statistical correctness, disclosure, simplicity):
  they only flag, never gate.
- **Human approves** from a structured report.

**Analysis scripts from metadata** (`datashield-analysis-suggest.yml`):
several independent plans → the human approves a plan (cheapest
checkpoint) → synthetic data with a planted effect → N scripts in DSLite
must recover the effect and agree → conformance review → the human runs on
the real servers.

**Mapping:** roles as skills in `datashield-skills`; handoffs via artifacts
(`spec.json`, tests, `candidates/`); solver and reviewer jobs without
secrets and read-only, only the final publish step writes.

**Pitfalls named:** correlated errors (same model, same prompt → same
mistake), rubber-stamping reviewers, cost creep, over-engineering — start
with spec → oracle → 2 solvers → gates → human.

**Compared with today:** one writer, `run-checks.sh` (rcmdcheck), a
maintainability and a disclosure reviewer, up to two correction rounds; no
separate oracle, no candidates, no comparator. Reviewers already only
report (except the correction round).

**Assessment (Claude, 2026-11-11), for the discussion:**

- The **independent oracle** is the biggest gain and the cheapest step: a
  test written without seeing the fix, failing first, plus pooled vs
  federated comparison, checks correctness instead of plausibility. Worth
  building before solvers.
- **N = 3:** the value is in the comparison, so it needs the oracle and
  the comparator first, else three candidates just triple the review. Cost
  is mainly subscription quota (three runs per issue hit the 5-hour limit
  sooner, `implementer-timer.yml` waits more often) and Actions minutes
  (three jobs installing R packages; a shared cache helps). Diversity
  matters more than N: with one model on the subscription, vary framing
  (minimal fix / rewrite of the function / test-first).
- Scaling N by risk fits the triage: `bug` with a clear spec → N = 1,
  `enhancement` or server-side change → N = 3.
- Isolation fits what exists: the writer job already has no writing
  token; matrix jobs per candidate, the publish job picks one.
- Open: how the oracle gets pooled data for packages without DSLite mock
  data.

**User's answers (2026-11-11):**

- "Different models" means different LLM models (e.g. Sonnet vs Opus),
  combined with different framings. All are Claude models: the run can
  choose one per solver (Claude Code's model setting), within what the
  subscription allows; other vendors would need API keys and are not
  planned. Same-family models still share some mistakes, so the framing
  stays varied too.
- **Package code:** when all candidates pass and differ, the **smallest
  diff** wins.
- **Analysis scripts:** keep the alternatives — different approaches or
  packages for the same step are worth showing the analyst, not just one
  winner. How (all scripts in the PR, one chosen plus the others folded
  in the description, …) is open.
- **Input idea (user, 2026-11-11):** the solvers as a list of models, one
  team per entry, e.g. `solver-models: '["claude-opus-5-5",
  "claude-sonnet-5-5", "claude-fable-5-2"]'` → three solvers. A JSON array
  string like `os-list` in `r-cmd-check.yml`, so it goes straight into
  `strategy.matrix` with `fromJSON()`. The same model may appear twice
  (different framings). Open: framing per entry (by position, or objects
  `{model, framing}`), and scaling by risk (e.g. a second list for small
  bugs, or only the first entry for them).
- **Proposed shape (2026-11-11, after the user's wish: no extra workflows,
  no constant caller changes, freedom for other users):** the teams per
  kind of issue live in a config file, `config/implementer.yml`, read like
  every other config (shared defaults, a target repository's own copy
  merged over them key by key):

  ```yaml
  solvers:
    bug: [claude-opus-5-5]
    enhancement: [claude-opus-5-5, claude-sonnet-5-5, claude-fable-5-2]
    default: [claude-opus-5-5]   # issues of no known kind
  ```

  The kind comes from what the implementer already reads (issue type,
  else the type label). One reusable workflow, one caller; changing the
  teams means editing that file in the target repository, never a
  workflow. An optional input `solvers` (the same mapping as a JSON
  string) could override it for a whole runner, but isn't needed at first.
  Later kinds (e.g. `server` for changes on the server side) are new keys,
  not new inputs.

  **Unsolved (user, 2026-11-11):** the user is wary of the number of
  config files across the workflows; a config file may still be the right
  place, but input vs config file is left open. A target repository needs
  no file of its own as long as the defaults suit it.

## Open

1. **New functions:** see above, for another day.
2. **Bypass:** if the runner's GitHub App is not App `5023737`, add it to
   `protect-bot-branches` in repo-governance.
3. **`bot-suspicious`:** the implementer refuses to start while the label is
   on, until a person has looked and removed it.
4. **Stale spec:** after a bug or idea, comments don't refresh the spec, and
   nothing warns. When `bot-proceed` is set and people commented after the
   bot's last spec, remove the label with a note to set `bot-triage` first.
5. **Label check elsewhere:** `dsAnalysis` and `datashield-workflows` have
   `bot-proceed` but no label check caller. Each target repository needs it
   before the implementer runs there.
6. **Parked:** a refactor agent (covered by the maintainability check for
   now), a disclosure reverse-engineering agent (the community works on
   something similar), a self-hosted runner, push notifications (GitHub's own
   for now).

## Triage, follow-ups

Live on `main` and tested for real on dsSupportClient (2026-11-07). None of
these is needed for the above:

- A "Related" line for similar issues (up to three, numbers checked), recently
  closed issues in what Claude reads, and an issue's state, such as "a PR is
  open".
- Whether a smaller model is enough: compare the Cost page of the `issue-triage`
  workspace with the quality of the specs. The defaults still to confirm are
  the seven categories and the model.
- A corrected answer: editing a comment starts no triage, only a new comment
  does. Add `issue_comment: edited` if this comes up on real issues.
- The cache warning in the triage job ("cache write denied"): R packages are
  installed each time, about a minute, because the job has no `actions: write`.
  Left that way on purpose.
- Issue templates, optional: they help the quality of reports, with the function
  as a helpful field, not as a filter. They belong in the governance repository,
  and must never list `bot-proceed`.

## Other open points from this work

- `dev-notes/issue-agents.md` still says nothing is built, and has an uncommitted
  edit in the main checkout.
- `setup-r` stalled several times on 2026-11-06 and 2026-11-07, on Ubuntu 24.04
  and on 26 alike, so the image is not the cause. The slow and fast 24.04 runs
  differed in region, which is only a hunch. If it goes on: skip R setup in the
  three repo-governance jobs, which only need two R packages. `ubuntu-latest`
  stays.
- Usage counts: the counter files were not maintained from 2026-10-16 to
  2026-11-06, so runs without a file went uncounted. Fixed, but they can't be
  recovered, so the KPIs of that time are too low.
- repo-governance: `feat/protect-bot-branches` is unpushed (check App ID
  `5023737` first), `governance-as-code` is obsolete, and `RULESET_ADMIN_PAT` is
  a repository secret although the README asks for a protected environment
  (`anthropic-admin` needs it too, then). Narrow `R/functions/**` in
  `anthropic.yml` to its own files, so label changes stop starting it.
- Rule IDs as secrets could become repository variables, all together, ideally
  with service accounts per owner (open list in `CLAUDE.md`).

## For later: `client-server-pair` skill in `datashield-skills`

A design rule from testing triage on #71, to add when there is time. A server
function fails below a disclosure limit, and that stays. A client wrapper may
catch that and carry on with the other studies: leaving out connections is
normal for sub-analysis, so it adds nothing an analyst couldn't do by hand, and
the failure already showed the study didn't pass. But the output has to say
which studies were used; that is about a correct analysis, not disclosure.
