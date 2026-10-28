# Writes the transformation file: a short how-to header, `meta` (rules
# version, repositories and commits checked) and one entry per function x
# argument that the rules would rename or that needs a decision. People
# edit `status` (and, if they want, `proposed`) by hand; the apply
# workflow renames what is "approved". `classifications` are Claude's
# answers (id, role, class, reason, fingerprint of the argument's default
# and documentation), kept at the end of the file so later runs don't ask
# again until that text changes.
write_transformation_file <- function(entries, meta, path, classifications = list()) {
  header <- c(
    "# DataSHIELD argument renames, written by the ds-naming-check workflow.",
    "# Review each entry and set `status`:",
    "#   approved  rename `current` to `proposed` (you may change `proposed`)",
    "#   skip      keep the current name; later runs keep this decision",
    "# `proposed` and `unresolved` entries are left alone by ds-naming-apply.",
    "# `rule_open: true`: the rule itself is not agreed yet (front-runner used).",
    "# `linked`: client/server counterparts, renamed in lockstep when approved too.",
    ""
  )
  order <- c("id", "package", "side", "function", "current", "proposed", "status", "rule", "rule_open", "match",
             "role", "class", "confidence", "source", "reason", "linked", "note")
  # Empty fields (and rule_open: false) are left out, so entries stay short;
  # `proposed` is always written, as "" when there is none to fill in.
  empty <- function(v) length(v) == 0 || (is.atomic(v) && length(v) == 1 && (is.na(v) || identical(v, "") || identical(v, FALSE)))
  entries <- lapply(unname(entries), function(e) {
    if (empty(e$proposed)) {
      e$proposed <- ""
    }
    e <- e[intersect(order, names(e))]
    e[!vapply(e, empty, logical(1)) | names(e) == "proposed"]
  })
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  # true/false, not the yaml package's default yes/no
  logical_handler <- function(x) structure(ifelse(x, "true", "false"), class = "verbatim")
  body <- yaml::as.yaml(list(meta = meta, entries = entries, classifications = unname(classifications)),
                        indent.mapping.sequence = TRUE, handlers = list(logical = logical_handler))
  writeLines(c(header, body), path, useBytes = TRUE)
}
