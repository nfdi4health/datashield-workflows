# The problems of one variable entry of the plan (character(0) if none),
# worded by `texts$plan`: a valid R name, a known type (its `kind` already
# set from `types`, the type names the settings allow), at least two
# categories for a categorical one, else a range [min, max] with min < max.
# `label` names the entry in the messages. Used by validate_analysis_plan()
# and, for the generated variables file, by merge_variables_file().
check_plan_variable <- function(v, label, types, texts) {
  problems <- character(0)
  add <- function(key, ...) problems <<- c(problems, fill_template(texts$plan[[key]], list(LABEL = label, ...)))
  if (!(is.character(v$name) && length(v$name) == 1 && identical(make.names(v$name), v$name))) {
    add("variable_name")
  }
  if (is.null(v$kind)) {
    add("variable_type", TYPES = paste(types, collapse = ", "))
  } else if (v$kind == "categorical") {
    if (length(v$categories) < 2) {
      add("categories")
    }
  } else {
    r <- suppressWarnings(as.numeric(unlist(v$range)))
    if (length(r) != 2 || anyNA(r) || r[1] >= r[2]) {
      add("range")
    }
  }
  problems
}
