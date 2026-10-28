# v1 drafts (2026-10-16)

Files for the v1 setup of this repository, drafted while the user was
away — **nothing here is wired in or applied.** Plan:
[../v1-planning.md](../v1-planning.md).

| File | Goes to | Applied by |
|---|---|---|
| `ruleset-main.json` | governance repo (ruleset on `main`) | user |
| `ruleset-dev.json` | governance repo (ruleset on `dev`) | user |
| `ruleset-release-tags.json` | governance repo (`v*` tags) | user |
| ~~`self-pr-checks.yml`~~ | now `.github/workflows/pr-checks.yml` (2026-10-20) | — |
| ~~`self-release.yml` + `self.releaserc.json`~~ | now `.github/workflows/release.yml` + `.github/release/releaserc.json` (2026-10-20; off until the variable `RELEASE_ENABLED` is `true`) | user sets the variable at v1 |
| `governance.yml` | governance repo (structure only) | user |
| `suggestion-policy.yml` | `config/suggestion-policy.yml` | with C and D |

## Rulesets

GitHub's ruleset export format, importable in the repository settings
(Rules → Rulesets → Import) or through the API. Decided 2026-10-19.

- **main:** no deletion, no force push, PR required with 0 approvals
  (one maintainer; the PR itself is the gate), merge commits only
  (keeps the dev commits for semantic-release; hence no "linear
  history"). Required checks: the three CI jobs and the head-branch check
  (only `dev` may merge). The release App may bypass, for its
  CHANGELOG commit (`actor_id` 0 is a placeholder for the App's ID).
- **dev:** the same without the head-branch check; squash allowed; plus
  the commit-message check. `do_not_enforce_on_create` so the branch can
  be created.
- **release tags:** only the release App may create, move or delete
  `v*` tags.

Decided: **no signing rule yet** (add once the signing key is set up);
the **smoke test** becomes a required check on `main` once its
federation rule exists and it has run green once. Check names are those
of `ci.yml` and of the reusable workflows called from
`pr-checks.yml` (`<job id> / <job>`); they change if those jobs are
renamed.

## Release of this repository

semantic-release on `main` with `v`-prefixed tags (`v1.0.0`), the GitHub
release published directly, the major tag `v1` moved by `successCmd`,
and a **CHANGELOG.md** committed to `main` by the release App
(user's decision). The R-package default config stays the root
`.releaserc.json`; this repository's own config is
`.github/release/releaserc.json`. Not passed with `--extends` as first
planned: semantic-release prefers a config file over `--extends`, so the
root file would win — the release job copies its own config over the
root file in the runner instead (never committed).

Before the first real release: delete the old unused `v1` tag
(`8d11341`, CLAUDE.md "Versioning").

## Governance YAML

Structure for the reconcile script of the plan's section 5, with made-up
names: workspaces, one service account per owner, one federation rule
per owner × workflow (plus this repository's smoke test on PR refs),
and per repository the secrets with where each value comes from. The
script and the Admin API calls aren't drafted — they live in the private
repo and need the `org:admin` token setup first.

## Policy file

`suggestion-policy.yml`: draft of `config/suggestion-policy.yml` (plan
§6 D) — reasons with their meaning and whether they are accepted, the
possible-bug thresholds, author roles and name particles, and the
routing of each kind of finding. The routing rows are meant to describe
today's behaviour, so that adopting the file changes nothing by itself —
check each against `publish_test_report()` and `suggest_roxygen.R` when
adopting it (e.g. a full review without file changes has no bot PR, so
"report" there falls back to the issue). Why and
what stays in code: [../v1-config-proposal.md](../v1-config-proposal.md).
