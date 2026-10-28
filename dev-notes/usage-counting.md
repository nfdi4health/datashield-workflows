# Usage counting

Built 2026-10-02 for the KPIs the user has to report on service usage.
**Not yet run in CI.**

## Requirements (user, 2026-10-02)

- Runs **per workflow**, from the start — only for the Claude-assisted
  workflows (`roxygen-suggest.yml`, `test-suggest.yml`,
  `datashield-analysis-suggest.yml`) and `authors-suggest.yml` (user's
  choice; first built for all 14 reusable workflows, then narrowed).
- Two kinds of callers: package maintainers (known, public repos) and
  analysts using `datashield-analysis-suggest.yml` — **private repos,
  unknown to us**, sensitive until publication.
- So: nothing about the caller may be sent, no secret can be handed out,
  and a central job can't read the callers' Actions runs (pull approach
  ruled out).

## How it works

- **Counter:** the pre-release `usage-counter` of this repository has one
  file per counted workflow, outcome and channel:
  `<workflow>-<outcome>-<channel>` (24 files). Each counted workflow ends
  with a step "Count this run" — the composite action
  `.github/actions/count-run` — that downloads exactly one of its files
  with `curl`: no token, no secret, works from private repos. GitHub's
  `download_count` per asset is a number of runs since the start.
- **Outcome** (`count-run.sh`): `failed` if the job failed or was
  cancelled (`job.status`); `proposed` if the run wrote files for the
  suggestion PR (`updated_files.txt` not empty — the commit step's
  manifest, the same in all four workflows); `nothing` otherwise.
  Possible bugs reported without a file change count as `nothing`.
- **Channel** (user's decision, 2026-10-02): `release` if a `v*` tag of
  this repository points to the commit the run used
  (`github.job_workflow_sha`, checked with a public `git ls-remote
  --tags`); `dev` otherwise (`@main`, a branch). Separates real use from
  development and testing by *version*, not by repository: dsSupportClient
  is both a test bed and a real user — its normal callers pinned to `@v1`
  count as `release`, a caller pointed at `@main` or a feature branch for
  testing counts as `dev`. Until versioning exists, everything is `dev`
  (the user: "until v1 this is testing"). Testing v2 on `@main` / a
  branch keeps counting as `dev` while `@v1` users count as `release`.
  **Before the first real release, delete the old unused `v1` tag**
  (`8d11341`), or runs of exactly that commit would count as `release`.
- **Once per run:** all four are single-job workflows; the step sits at
  the end of that job. Roxygen, tests and authors don't count runs their
  scope step skipped (bot branches, forks, Dependabot, tags). No extra job
  — GitHub bills private repos per job, rounded up to a minute. (If a
  matrix workflow is ever counted: only in `strategy.job-index == 0`.)
- **Never breaks a run:** `if: always()` (also counts failed runs),
  `continue-on-error: true`, the script always exits 0, `--max-time 10`.
- **Collector** (`collect-usage.yml`, not reusable, runs in this repo
  only): daily at 05:17 UTC, by hand, and on pushes to `main` that change
  workflows. It creates the release if missing, uploads the missing files
  for every workflow calling `count-run` (a newly counted workflow is
  covered automatically), and appends the day's totals to `usage.csv` on
  the orphan branch `usage-data`
  (`date,workflow,outcome,channel,runs_total`; a second run on the same
  day replaces that day's rows).
- **KPI:** runs in a period = `runs_total` on its last day minus on the
  day before it starts, summed over outcomes for all runs. GitHub keeps
  the totals forever, so a missed day only makes the split coarser.

## Decisions

- **No opt-out input** (user, 2026-10-02): no data is sent, and the
  service-usage KPIs make counting part of the service anyway.
  Transparency instead: `docs/getting-started.qmd#usage-counting`, and
  the data protection note in dsAnalysis's README.
- **Only four workflows** (user): the Claude-assisted ones and
  `authors-suggest.yml`.
- **Outcome and channel** (user, 2026-10-02): proposed / nothing / failed
  × release / dev. Own test runs are separated by version, not by a
  repository variable or list (rejected: dsSupportClient is both test bed
  and real user).
- **No distinct-repository count:** it would need an identifier, i.e. data
  about the caller. Not done, given the analysts' private projects.

## Limits

- The counts are public (release asset download counts).
- Downloading a file by hand counts as a run; the release notes ask not
  to.
- Runs before the first collector run aren't counted: the step's
  download fails until the release exists. The collector runs on the push
  that adds the steps, so the gap is minutes.
- External users on `@main` count as `dev` — the docs should recommend
  pinning `@vX` once versions exist.

## In CI (2026-10-02)

The collector ran on the pushes: release `usage-counter` with its 24
files, `usage.csv` on `usage-data` (all 0). Two fixes on the way:
`abc3d29` — the search also matched `collect-usage.yml` itself (its own
grep pattern) and created six files for it; now only `uses:` lines count,
and unused files are removed if never downloaded. `1e5a576` — the
recording step aborted on the first day: `grep -v` exits 1 when no rows
are left, and Actions runs `bash -e` (the local test ran without `-e`;
it now uses it). Still to see: a real count from a caller's run.

## First real check

After pushing: the collector run on `main` creates the release with 24
files; a run of a caller's workflow raises one file's count by one (the
API's `download_count` may lag a little) — the job log says which ("Counted
this run as …"); the next collector run writes `usage.csv`.

Tested locally: `count-run.sh` for every outcome, both channels (the old
`v1` commit as a stand-in release, real `ls-remote`), no sha, and a
missing release (exit 0); the collector's recording step against a bare
repo (columns, same-day replace, next day).

## Plan for v1 and the move (decided 2026-10-16, nothing built)

- **Counter stays in the public workflow repo** (renamed
  `datashield-workflows`, in nfdi4health): downloads must work without a
  token, also from private analyst repos. Only `count-run`'s URL changes
  with the move.
- **New dimension `datashield` / `other`**, from an explicit input
  (analysis and naming always DataSHIELD; roxygen, tests and — since
  2026-10-19 on `v1/foundation` — authors have `datashield-type`, "none"
  = other; `count-run` takes it as a new input at the counting switch); the user's non-DataSHIELD
  runs drop out of the KPIs on their own. Test runs in the workflow repo
  itself are not counted.
- **Fresh counting at v1:** the new file names (with the dimension)
  start at 0; one last snapshot of the old 24 files goes into the KPI
  repo as pre-v1 history; then the old files are removed.
- **Central private repo `datashield-kpi-reporting`** (nfdi4health).
  **Built 2026-10-26, split instead of moved (user's decision):** this
  repository keeps creating the counter files (`collect-usage.yml`, now
  "Usage counter files", own token, no longer writes `usage-data`); the
  KPI repo only reads the public counts daily (`R/collect_counts.R`,
  `.github/workflows/collect.yml`) into `usage.csv` on its `main` —
  no App or secret there, so more people with access there can't write
  here. The history of `usage-data` (2026-10-02 to 2026-10-25) was
  copied. Open: a ruleset on its `main` (no force push, no deletion; the
  collector pushes with `GITHUB_TOKEN`, so no PR requirement); delete
  `usage-data` once `v1/foundation` is merged (`main`'s old collector
  writes it until then).
- **Not losing raw counts:** a missed collector day loses nothing
  (download counts are cumulative); the risk is a deleted or re-created
  counter file (count back to 0) — ruleset on the `usage-counter` tag,
  only admins delete releases, the collector never deletes a file with
  downloads; the daily snapshot in the KPI repo is the backup.
- **Priority:** complete, safe raw counts first; monthly/quarterly
  reports later.
- **Plugin KPI** (if a plugin comes, in its own repo `nfdi4health/datashield-skills`): daily clones and
  unique cloners from the traffic API (admin token), see
  [issue-agents.md](issue-agents.md).
- **Idea for later, not built:** Claude costs per workspace from the
  Admin API's cost reports (needs the Admin API key of the Anthropic
  setup automation).
