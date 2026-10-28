# Which ways of connecting to DataSHIELD the package's tests already use,
# anywhere under tests/testthat/ (not only setup*/helper*: dsBaseClient,
# for example, connects in sourced files and in each test file). Returns
# the names found among DSLite, DSOpal, DSMolgenisArmadillo and
# DSI (a datashield.login() or newDSLoginBuilder() of any driver), empty
# if none.
detect_connection_approaches <- function() {
  dir <- file.path("tests", "testthat")
  if (!dir.exists(dir)) {
    return(character(0))
  }
  files <- list.files(dir, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
  text <- paste(unlist(lapply(files, readLines, warn = FALSE)), collapse = "\n")
  patterns <- c(
    DSLite = "DSLite",
    DSOpal = "DSOpal",
    DSMolgenisArmadillo = "DSMolgenisArmadillo",
    DSI = "datashield\\.login\\s*\\(|newDSLoginBuilder\\s*\\("
  )
  names(patterns)[vapply(patterns, grepl, logical(1), x = text)]
}
