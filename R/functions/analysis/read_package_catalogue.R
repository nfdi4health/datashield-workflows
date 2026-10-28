# Reads the DataSHIELD package catalogue (packages.json of
# packages.datashield.org, built from FederatedMethods/packages) into a
# named list: per package its description, status (production /
# development / retired, or "unknown" if none is given; lower case),
# GitHub and CRAN links. Returns an empty
# list, with a message, if it can't be read: the analysis then just has no
# "possible with another package" notes.
read_package_catalogue <- function(url) {
  raw <- tryCatch(jsonlite::fromJSON(url, simplifyVector = FALSE), error = function(e) {
    message(sprintf("Package catalogue %s could not be read: %s", url, conditionMessage(e)))
    NULL
  })
  if (is.null(raw)) {
    return(list())
  }

  lapply(raw, function(p) {
    input <- p$input
    status <- tolower(trimws(input$status %||% ""))
    if (!nzchar(status)) {
      status <- "unknown"
    }
    list(
      description = input$description %||% "",
      status = status,
      github = sub("/+$", "", input$github_link %||% ""),
      cran = input$cran_link %||% ""
    )
  })
}
