# Checks the fixed core of an analysis plan and returns the problems found
# (character(0) if none), worded by `texts$plan`. Only what the workflow
# itself relies on is checked: the symbol, the studies with their server
# packages (mock data, installs) and the variables (mock data). Steps only
# need a title and a unique id, and an optional `depends_on` may only name
# steps earlier in the plan; everything else in a step is free and goes
# to Claude as written. An optional `package-status` list may only use
# package_statuses(). Unknown top-level entries are allowed. `types` are
# the variable types the settings allow; read_analysis_plan() has already
# set each known type's `kind`.
validate_analysis_plan <- function(plan, types, texts) {
  problems <- character(0)
  add <- function(key, ...) problems <<- c(problems, fill_template(texts$plan[[key]], list(...)))
  label <- function(key, name, section, index) {
    if (is.character(name)) {
      return(fill_template(texts$plan[[key]], list(NAME = name)))
    }
    fill_template(texts$plan$label_entry, list(SECTION = section, INDEX = index))
  }
  is_name <- function(x) is.character(x) && length(x) == 1 && identical(make.names(x), x)
  duplicated_of <- function(x) paste(unique(x[duplicated(x)]), collapse = ", ")
  # The text values of one field across a list of entries, skipping entries
  # that aren't lists or whose field isn't text.
  text_values <- function(entries, field) {
    values <- lapply(entries, function(e) {
      if (is.list(e) && is.character(e[[field]])) {
        return(e[[field]])
      }
      NULL
    })
    unlist(values)
  }

  if (!is_name(plan$symbol)) {
    add("symbol")
  }

  studies <- plan$studies
  if (!is.list(studies) || length(studies) == 0) {
    add("no_studies")
  } else {
    for (i in seq_along(studies)) {
      s <- studies[[i]]
      l <- label("label_study", s$server, "studies", i)
      if (!is_name(s$server)) {
        add("server_name", LABEL = l)
      }
      pkgs <- s$packages
      if (!is.list(pkgs) || length(pkgs) == 0 || is.null(names(pkgs)) || any(!nzchar(names(pkgs)))) {
        add("packages", LABEL = l)
      } else {
        bad <- names(pkgs)[!vapply(pkgs, function(v) (is.character(v) || is.numeric(v)) && length(v) == 1, logical(1))]
        if (length(bad) > 0) {
          add("one_version", LABEL = l, PACKAGES = paste(bad, collapse = ", "))
        }
        # YAML reads an unquoted 6.10 as the number 6.1: only quoted versions are exact.
        unquoted <- names(pkgs)[vapply(pkgs, is.numeric, logical(1))]
        if (length(unquoted) > 0) {
          add("version_quotes", LABEL = l, PACKAGES = paste(unquoted, collapse = ", "))
        }
      }
    }
    servers <- text_values(studies, "server")
    if (anyDuplicated(servers)) {
      add("duplicate_servers", NAMES = duplicated_of(servers))
    }
  }

  variables <- plan$variables
  if (!is.list(variables) || length(variables) == 0) {
    add("no_variables")
  } else {
    for (i in seq_along(variables)) {
      v <- variables[[i]]
      l <- label("label_variable", v$name, "variables", i)
      if (!is_name(v$name)) {
        add("variable_name", LABEL = l)
      }
      if (is.null(v$kind)) {
        add("variable_type", LABEL = l, TYPES = paste(types, collapse = ", "))
      } else if (v$kind == "categorical") {
        if (length(v$categories) < 2) {
          add("categories", LABEL = l)
        }
      } else {
        r <- suppressWarnings(as.numeric(unlist(v$range)))
        if (length(r) != 2 || anyNA(r) || r[1] >= r[2]) {
          add("range", LABEL = l)
        }
      }
    }
    names_seen <- text_values(variables, "name")
    if (anyDuplicated(names_seen)) {
      add("duplicate_variables", NAMES = duplicated_of(names_seen))
    }
  }

  steps <- plan$steps
  if (!is.list(steps) || length(steps) == 0) {
    add("no_steps")
  } else {
    for (i in seq_along(steps)) {
      s <- steps[[i]]
      if (!is.list(s) || !is.character(s$title) || !nzchar(s$title)) {
        add("step_title", LABEL = label("", NULL, "steps", i))
      } else if (!is.character(s$id) || !grepl("^[A-Za-z0-9_-]+$", s$id)) {
        add("step_id", TITLE = s$title)
      }
    }
    ids <- text_values(steps, "id")
    if (anyDuplicated(ids)) {
      add("duplicate_steps", NAMES = duplicated_of(ids))
    }
    # depends_on: ids of steps earlier in the plan (scripts run in plan order)
    for (i in seq_along(steps)) {
      s <- steps[[i]]
      if (!is.list(s) || !"depends_on" %in% names(s) || is.null(s$depends_on)) {
        next
      }
      deps <- unlist(s$depends_on)
      earlier <- text_values(steps[seq_len(i - 1)], "id")
      if (!is.character(deps) && length(deps) > 0) {
        add("depends_on", TITLE = s$title, STEPS = paste(deps, collapse = ", "))
      } else if (length(setdiff(deps, earlier)) > 0) {
        add("depends_on", TITLE = s$title, STEPS = paste(setdiff(deps, earlier), collapse = ", "))
      }
    }
  }

  statuses <- plan$`package-status`
  if (!is.null(statuses) && (!is.character(unlist(statuses)) || !all(unlist(statuses) %in% package_statuses()))) {
    add("package_status", ALLOWED = paste(package_statuses(), collapse = ", "), FOUND = paste(unlist(statuses), collapse = ", "))
  }

  problems
}
