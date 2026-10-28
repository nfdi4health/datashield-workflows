# datashield-workflows

Reusable GitHub Actions workflows for R packages: checks, releases, and bot
suggestions for documentation, tests and contributor credits.

**Documentation: <https://nfdi4health.github.io/datashield-workflows/>** —
what each workflow does, copyable caller files, and the setup they need.

## Layout

| Path | Content |
|---|---|
| `.github/workflows/` | The reusable workflows (plus `publish-docs.yml`, which builds the site) |
| `.github/actions/` | Composite actions used by the workflows |
| `R/`, `config/`, `prompts/` | Scripts, settings and prompts of the bot suggestion workflows |
| `docs/` | Source of the documentation site (Quarto) |
| `examples/` | Example caller files, shown on the site |
| `dev-notes/` | Internal design notes |

Preview the site locally with `quarto preview docs`.
