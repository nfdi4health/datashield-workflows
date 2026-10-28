# Packages the proposed test files use (`pkg::fn`, library(), require(),
# requireNamespace()) but DESCRIPTION doesn't declare: added to Suggests,
# so R CMD check doesn't warn "'::' or ':::' import not declared" (seen in
# dsAnalysis with withr::local_tempdir()). Every proposed test passed a
# real run, so these packages are installed. Base packages and the package
# itself are left out. `paths` are the test files this run proposes.
# Returns the added package names; DESCRIPTION is written if there are any.
declare_test_packages <- function(package_name, paths) {
  used <- character(0)
  for (p in paths[file.exists(paths)]) {
    pd <- tryCatch(utils::getParseData(parse(p, keep.source = TRUE)), error = function(e) NULL)
    if (is.null(pd) || nrow(pd) == 0) {
      next
    }
    pd <- pd[order(pd$line1, pd$col1), ]
    used <- c(used, pd$text[pd$token == "SYMBOL_PACKAGE"])
    # library(pkg), require("pkg"), requireNamespace("pkg"): the first argument
    calls <- which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% c("library", "require", "requireNamespace", "loadNamespace"))
    for (i in calls) {
      call_id <- pd$parent[pd$id == pd$parent[i]]
      first <- pd[pd$parent %in% pd$id[pd$parent == call_id & !pd$terminal] & pd$token %in% c("SYMBOL", "STR_CONST"), ]
      if (nrow(first) > 0) {
        used <- c(used, gsub("^[\"']|[\"']$", "", first$text[1]))
      }
    }
  }
  base <- rownames(utils::installed.packages(priority = "base"))
  d <- desc::description$new("DESCRIPTION")
  missing <- setdiff(unique(used), c(d$get_deps()$package, base, package_name, "R"))
  missing <- missing[grepl("^[A-Za-z][A-Za-z0-9.]*$", missing)]
  if (length(missing) == 0) {
    return(character(0))
  }
  for (pkg in missing) {
    d$set_dep(pkg, "Suggests")
  }
  d$write("DESCRIPTION")
  missing
}
