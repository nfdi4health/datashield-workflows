#!/usr/bin/env Rscript
# Checks a DataSHIELD package's argument names against the naming rules
# (config/ds-naming-rules.yml, a repository's own copy merged over it) and
# writes the transformation file people approve renames in:
#   1. read the package (the caller) and, if given, its server package
#      (SERVER_DIR), and pair client arguments with the server arguments
#      they are passed to;
#   2. classify every user-facing argument by code (role, object class);
#      server arguments take over their client counterpart's class;
#   3. Claude classifies what the code can't settle (at most
#      MAX_CLAUDE_CALLS functions; earlier answers are reused until the
#      argument's documentation changes);
#   4. propose names by the rules, distinct per function, client and
#      server in lockstep;
#   5. merge with the decisions in the previous file (PREVIOUS_FILE, the
#      open bot PR's or the branch's own), write file, report and PR text.
# Report-only checks: function names, argument order, test file names.
# Design: dev-notes/datashield-naming/README.md.

library(httr2)
library(jsonlite)
library(purrr)

functions_dir <- if (dir.exists("R/functions/ds-naming")) {
  "R/functions"
} else {
  ".shared-workflows/R/functions"
}
walk(list.files(file.path(functions_dir, c("shared", "ds-naming")), pattern = "\\.R$", full.names = TRUE), source)

rules <- read_config_yaml("config/ds-naming-rules.yml")
transformation_file <- Sys.getenv("TRANSFORMATION_FILE", ".github/ds-naming/transformations.yml")
previous_file <- Sys.getenv("PREVIOUS_FILE", transformation_file)
server_dir <- Sys.getenv("SERVER_DIR")
package_side <- Sys.getenv("PACKAGE_SIDE", "client")
max_calls <- as.integer(Sys.getenv("MAX_CLAUDE_CALLS", "40"))
use_claude <- max_calls > 0 && tolower(Sys.getenv("USE_CLAUDE", "true")) == "true" && nzchar(Sys.getenv("ANTHROPIC_API_KEY"))

# --- 1. Packages and links ------------------------------------------------------

own <- read_ds_package(".", package_side)
server <- if (package_side == "client" && nzchar(server_dir) && dir.exists(server_dir)) {
  read_ds_package(server_dir, "server")
} else {
  NULL
}
pkgs <- Filter(Negate(is.null), list(own, server))
links <- link_server_calls(own, server)

# --- 2. Classification by code --------------------------------------------------

rows <- classify_naming_rows(pkgs, links)
previous <- read_transformation_file(previous_file)
rows$id <- paste(rows$package, rows$`function`, rows$arg, sep = "::")
rows$fingerprint <- vapply(seq_len(nrow(rows)), function(i) code_fingerprint(c(rows$default[i], rows$doc[i])), character(1))

# Earlier Claude answers for unchanged arguments.
classifications <- previous$classifications
for (i in which(rows$id %in% names(classifications))) {
  cl <- classifications[[rows$id[i]]]
  if (!identical(cl$fingerprint, rows$fingerprint[i])) {
    next
  }
  rows[i, c("role", "class", "reason")] <- list(cl$role, no_class_as_empty(cl$class), cl$reason %||% "")
  rows$confidence[i] <- "medium"
  rows$source[i] <- "claude"
}

# --- 3. Claude for what the code can't settle -----------------------------------

ask <- which(needs_naming_classification(rows, rules))
fn_keys <- unique(paste(rows$package[ask], rows$`function`[ask], sep = "::"))
if (length(fn_keys) > 0 && use_claude) {
  naming_claude <- claude_client("ds-naming-classification", "prompts/ds-naming-classification-prompt.md")
  if (length(fn_keys) > max_calls) {
    message(sprintf("%d functions have unclear arguments; asking Claude about the first %d (MAX_CLAUDE_CALLS).", length(fn_keys), max_calls))
  }
  defs <- unlist(lapply(pkgs, function(p) lapply(p$defs, function(d) c(d, package = p$name))), recursive = FALSE)
  for (key in head(fn_keys, max_calls)) {
    idx <- ask[paste(rows$package[ask], rows$`function`[ask], sep = "::") == key]
    def <- Find(function(d) paste(d$package, d$name, sep = "::") == key, defs)
    # The function's counterparts on the other side.
    fn <- rows$`function`[idx[1]]
    if (rows$side[idx[1]] == "client") {
      linked <- unique(links$server_fn[links$client_fn == fn])
    } else {
      linked <- unique(links$client_fn[links$server_fn == fn])
    }
    answer <- tryCatch(ask_claude_for_naming(naming_claude, def, rows[idx, ], rules, linked, cache = length(fn_keys) > 1), error = function(e) {
      warn_failed_call(key, def$file, e)
      NULL
    })
    for (a in answer %||% list()) {
      i <- idx[rows$arg[idx] == a$arg]
      if (length(i) != 1) {
        next
      }
      rows[i, c("role", "class", "reason")] <- list(a$role, no_class_as_empty(a$class), a$reason %||% "")
      rows$confidence[i] <- "medium"
      rows$source[i] <- "claude"
      classifications[[rows$id[i]]] <- list(id = rows$id[i], role = a$role, class = a$class, reason = a$reason %||% "", fingerprint = rows$fingerprint[i])
    }
  }
} else if (length(fn_keys) > 0) {
  message(sprintf("%d functions have arguments the code can't place; without Claude they stay unresolved.", length(fn_keys)))
}
# Only answers for arguments that still exist are kept.
classifications <- classifications[intersect(names(classifications), rows$id)]

# --- 4. Proposals -----------------------------------------------------------------

rows <- propose_naming_rows(rows, links, rules)
entries <- merge_naming_entries(naming_entries(rows, links), previous$entries)

# --- 5. Outputs -----------------------------------------------------------------

# No dates or commits in the file: an unchanged result leaves it unchanged,
# so a re-run without news makes no commit. They go into the PR text.
repository_of <- function(p) {
  if (identical(p, own)) {
    return(Sys.getenv("GITHUB_REPOSITORY"))
  }
  Sys.getenv("SERVER_REPOSITORY")
}
commit_of <- function(p) {
  if (identical(p, own)) {
    return(Sys.getenv("GITHUB_SHA"))
  }
  Sys.getenv("SERVER_SHA")
}
meta <- list(
  rules_version = rules$meta$version,
  packages = lapply(pkgs, function(p) list(name = p$name, side = p$side, repository = repository_of(p)))
)
write_transformation_file(entries, meta, transformation_file, classifications)

checks <- lapply(pkgs, function(p) list(
  package = p$name,
  function_names = check_function_names(p, rules),
  order = check_argument_order(rows[rows$package == p$name, ], rules),
  tests = check_test_file_names(p, rules)
))
report <- format_naming_report(rows, entries, checks, transformation_file, rules$meta$version)
report_file <- file.path(dirname(transformation_file), "report.md")
writeLines(report$full, report_file, useBytes = TRUE)
checked <- sprintf("`%s` at %s", vapply(pkgs, repository_of, character(1)), substr(vapply(pkgs, commit_of, character(1)), 1, 7))
writeLines(c(report$summary, "", sprintf("Checked on %s: %s.", format(Sys.Date()), paste(checked, collapse = ", "))),
           "suggestion_report.md", useBytes = TRUE)
writeLines(c(transformation_file, report_file), "updated_files.txt")
summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary_file)) {
  write(report$summary, summary_file, append = TRUE)
}
message(report$summary)
