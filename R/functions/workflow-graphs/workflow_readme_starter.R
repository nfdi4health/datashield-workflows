# The README written the first time only, when
# .github/workflow-graphs/README.md doesn't exist yet: a short intro and
# the overview block (which brings its own "## All workflows" and
# "## Events" sections). Afterwards the text is the repository's own —
# later runs only replace the block (update_marked_blocks()). `wrapped` is
# the named list of blocks with their markers.
workflow_readme_starter <- function(wrapped) {
  c(
    "# Workflows",
    "",
    "The GitHub Actions workflows of this repository, and how they connect.",
    "The table and diagrams are generated from the workflow files by",
    "[workflow-graphs](https://github.com/nfdi4health/datashield-workflows) and",
    "updated when the workflows change. For the details of a workflow, see",
    "its file in `.github/workflows/`. Text outside the marked block is yours",
    "and never overwritten.",
    "",
    wrapped$overview
  )
}
