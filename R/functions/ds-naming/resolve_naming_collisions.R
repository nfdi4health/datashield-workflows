# Makes one function's proposed names distinct (`rows`: that function's
# arguments, in order). When several arguments get the same name:
#   - several inputs of one object class (two data frames -> two "df")
#     follow `multiple_inputs`: the established pairs listed under its
#     exceptions (x, y for ds.cor, ...), else numbered (df1, df2) — but
#     only when every one of them was classified with high confidence;
#   - otherwise (a role such as checks or method, a weaker
#     classification, a column or style name) the argument that already
#     has the name, or the one known alias of it, keeps it;
# the others get no proposal and a conflict note, for a person to decide
# (a function with two "checks" flags usually has one DataSHIELD check
# and one passed on to R). Last, a proposed name that another, kept
# argument already has is a conflict too.
resolve_naming_collisions <- function(rows, rules) {
  scheme <- rule_name(rules$multiple_inputs$scheme)
  fn <- rows$`function`[1]
  pairs <- Filter(function(e) fn %in% unlist(e$functions), rules$multiple_inputs$exceptions)
  fixed <- if (length(pairs) > 0) {
    unlist(pairs[[1]]$names)
  } else {
    character(0)
  }
  movable <- !is.na(rows$proposed) & rows$match != "exception"
  conflict <- function(i, text) {
    rows$note[i] <<- text
    rows$proposed[i] <<- NA
    rows$match[i] <<- "conflict"
  }

  sep <- rule_name(rules$style$separator)$name
  # Generic names (x, y, V1, M2.name, the class's aliases) can be numbered;
  # descriptive ones (sex, age, keep.cols) say what the input is and keep
  # their name, spelled in the general style.
  generic <- function(i) {
    stem <- sub("[._]names?$", "", rows$arg[i])
    grepl("^[A-Za-z][0-9]?$", stem) || rows$arg[i] %in% c(rows$proposed[i], unlist(rules$classes[[rows$class[i]]]$aliases))
  }
  for (name in unique(rows$proposed[movable])) {
    idx <- which(movable & rows$proposed %in% name)
    if (length(idx) < 2) {
      next
    }
    is_class <- all(startsWith(rows$rule[idx], "classes."))
    if (is_class) {
      descriptive <- idx[!vapply(idx, generic, logical(1))]
      for (i in descriptive) {
        rows$proposed[i] <- to_naming_style(rows$arg[i], sep)
        rows$rule[i] <- "style"
        rows$match[i] <- if (rows$proposed[i] == rows$arg[i]) {
          "canonical"
        } else {
          "style"
        }
        rows$note[i] <- sprintf("descriptive name kept: several %s inputs", rows$class[i])
      }
      idx <- setdiff(idx, descriptive)
      if (length(idx) < 2) {
        next
      }
    }
    if (is_class && length(fixed) >= length(idx)) {
      new_names <- fixed[seq_along(idx)]
    } else if (is_class && scheme$name == "numbered" && all(rows$confidence[idx] == "high")) {
      new_names <- paste0(name, seq_along(idx))
    } else {
      holder <- idx[rows$arg[idx] == name]
      if (length(holder) == 0) {
        holder <- idx[rows$match[idx] == "alias"]
      }
      if (length(holder) != 1) {
        holder <- integer(0)
      }
      keeps <- ""
      if (length(holder) == 1) {
        keeps <- sprintf("; `%s` keeps it", rows$arg[holder])
      }
      for (i in setdiff(idx, holder)) {
        others <- paste(sprintf("`%s`", setdiff(rows$arg[idx], rows$arg[i])), collapse = ", ")
        conflict(i, sprintf("`%s` is proposed for %s too%s", name, others, keeps))
      }
      next
    }
    rows$proposed[idx] <- new_names
    rows$rule[idx] <- "multiple_inputs"
    rows$rule_open[idx] <- rows$rule_open[idx] | (scheme$open && length(fixed) < length(idx))
    rows$match[idx] <- ifelse(rows$arg[idx] == new_names, "canonical", "rule")
  }

  target <- ifelse(is.na(rows$proposed), rows$arg, rows$proposed)
  for (i in seq_len(nrow(rows))) {
    if (is.na(rows$proposed[i]) || rows$proposed[i] == rows$arg[i]) {
      next
    }
    clash <- setdiff(which(target == rows$proposed[i]), i)
    if (length(clash) > 0) {
      conflict(i, sprintf("`%s` is already the name of another argument", rows$proposed[i]))
    }
  }
  rows
}
