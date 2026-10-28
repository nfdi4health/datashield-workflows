# Resolves a path given relative to this repository's root (e.g.
# "prompts/roxygen-review-prompt.md"): the caller repo's own file at that
# same relative path wins if it exists (an override — and what makes
# running directly inside this repository work), otherwise the copy in
# the `.shared-workflows/` checkout the workflows create. For prompt
# templates, which are replaced as a whole; config files are merged
# instead (read_config_yaml()).
resolve_shared_path <- function(rel_path) {
  if (file.exists(rel_path)) {
    rel_path
  } else {
    file.path(".shared-workflows", rel_path)
  }
}
