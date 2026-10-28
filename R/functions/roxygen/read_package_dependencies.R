# Package names in the calling repo's DESCRIPTION Depends and Imports
# (without version requirements), or character(0) if it can't be read.
read_package_dependencies <- function() {
  fields <- tryCatch(read.dcf("DESCRIPTION", fields = c("Depends", "Imports"))[1, ], error = function(e) NULL)
  fields <- fields[!is.na(fields)]
  if (length(fields) == 0) {
    return(character(0))
  }
  deps <- trimws(sub("\\(.*$", "", unlist(strsplit(fields, ","))))
  setdiff(deps[nzchar(deps)], "R")
}
