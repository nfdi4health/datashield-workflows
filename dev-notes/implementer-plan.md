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

## Targets, branches, client/server pairs (user, 2026-11-10; not built yet)

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

## Triage, found in the first implementer test (2026-11-10)

- dsSupportClient #83 (only the `method` part of the open #58) stayed
  `duplicate` of #58 after the maintainer's comment that it is split out on
  purpose. Wanted: an allowed login's objection to a duplicate verdict is
  decisive (prompt and/or a field), so a deliberate split isn't blocked.
  Worked around by closing #58.

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
