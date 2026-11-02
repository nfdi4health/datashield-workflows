# datashield-workflows

Reusable GitHub Actions workflows for R packages and DataSHIELD analysis
projects: checks, releases, bot suggestions for documentation, tests and
contributor credits, and tested starter scripts for DataSHIELD analyses.

**Documentation: <https://nfdi4health.github.io/datashield-workflows/>** —
what each workflow does, copyable caller files, and the setup they need.

## Layout

| Path | Content |
|---|---|
| `.github/workflows/` | The reusable workflows, plus this repository's own: `ci.yml` and `self-test.yml` (tests), `pr-checks.yml`, `release.yml`, `publish-docs.yml` (builds the site), `collect-usage.yml` (usage counter files) |
| `.github/actions/` | Composite actions used by the workflows |
| `R/`, `config/`, `prompts/` | Scripts, settings and prompts of the bot suggestion workflows |
| `docs/` | Source of the documentation site (Quarto) |
| `examples/` | Example caller files, shown on the site |
| `tests/` | testthat and shell tests, made-up fixture packages, recorded Claude answers |
| `dev-notes/` | Internal design notes |

Preview the site locally with `quarto preview docs`. Run the tests with
`Rscript tests/testthat.R` and `bash tests/shell/test-scope.sh`.
