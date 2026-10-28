#' @title Mean
#' @param x a character string naming a numeric vector on the server.
#' @param type a character string: "split" or "combine".
#' @param checks logical, run checks.
#' @param datasources a list of DSConnection-class objects.
#' @examples
#' \dontrun{
#' ds.mean(x = "D$age", type = "split")
#' }
#' @export
ds.mean <- function(x = NULL, type = "split", checks = FALSE, datasources = NULL) {
  if (is.null(x)) stop("Please provide the name of the input vector: x", call. = FALSE)
  cally <- call("meanDS", as.symbol(x))
  out <- DSI::datashield.aggregate(datasources, cally)
  out
}
