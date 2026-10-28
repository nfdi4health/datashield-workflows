# The DataSHIELD methods a server package declares (AggregateMethods,
# AssignMethods) in DESCRIPTION or, as newer packages do (dsBase 7),
# in inst/DATASHIELD: a named character vector alias -> function. An entry
# is "fn" or "alias=pkg::fn".
read_description_methods <- function(pkg_dir) {
  entries <- character(0)
  for (f in file.path(pkg_dir, c("DESCRIPTION", "inst/DATASHIELD"))) {
    if (!file.exists(f)) {
      next
    }
    dcf <- read.dcf(f)
    fields <- intersect(c("AggregateMethods", "AssignMethods"), colnames(dcf))
    entries <- c(entries, trimws(unlist(strsplit(paste(dcf[1, fields], collapse = ","), ","))))
  }
  entries <- entries[nzchar(entries) & !is.na(entries) & entries != "NA"]
  alias <- trimws(sub("=.*$", "", entries))
  target <- trimws(sub("^.*::", "", sub("^[^=]*=", "", entries)))
  stats::setNames(target, alias)
}
