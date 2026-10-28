# dsSupportClient callers for the v1 test round (2026-10-20)

Drafts for `nfdi4health/dsSupportClient`'s `.github/workflows/`, made
from its files at `84312ae`. Copy them over the files of the same name,
on a branch of dsSupportClient, for the CI test round
([../../ci-test-round.md](../../ci-test-round.md)). They call
`@v1/foundation`; at the move they become
`nfdi4health/datashield-workflows/...@v1`.

## Changed files (here)

| File | Changes |
|---|---|
| `docs-suggest.yml` | `datashield: true` dropped (`datashield-type: client` alone); `actions: read` + `checks: read`; manual runs get a `scope` input (changed / all) passed as `review-scope`. |
| `test-suggest.yml` | the same; the `scan-mode` expression is gone, so a scheduled run reviews only what changed since the last review (a full review: run it by hand with scope `all`). |
| `suggestion-choices.yml` | **new** (2026-10-21, was missing): the checkbox workflow, from `examples/`; also full-review PRs (`bot-suggest/docs-all-…`, `…/tests-all-…`). |
| `check-author-included.yml` | `datashield-type: client` (for the usage counts only); `id-token: write` dropped — the authors bot calls no Claude. |

## Unchanged files — only the ref

`R-CMD-Check.yml`, `cleanup-suggestion-branch.yml`, `commitlint.yml`,
`release-publish.yml`, `release-trigger.yml`, `require-head-branch.yml`,
`workflow-graph.yml`: replace `@main` with `@v1/foundation`, e.g.

```bash
sed -i 's#\(nfdi4health/datashield-workflows/.github/workflows/[a-z-]*\.yml\)@main#\1@v1/foundation#' .github/workflows/*.yml
```

`release-publish.yml` passes no `config-repo` / `config-ref`, so it needs
nothing else; it stays `dry-run: true`.

## Before the first run

- **Federation rules:** the roxygen and test rules match
  `job_workflow_ref` exactly, today with `@refs/heads/main`. A run from
  `@v1/foundation` presents
  `nfdi4health/datashield-workflows/.github/workflows/<file>@refs/heads/v1/foundation`
  and is refused until a rule matches it — add one per workflow for the
  test round (or make the claim a prefix match up to `@`).
- **Config overrides:** none in dsSupportClient (no `config/` folder),
  so the switch to YAML and the policy file needs nothing there.
- The App needs no new permissions.
