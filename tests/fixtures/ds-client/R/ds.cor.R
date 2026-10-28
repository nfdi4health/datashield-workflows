#' @param x a character string naming a vector.
#' @param y a character string naming a vector.
#' @param datasources a list of DSConnection-class objects.
#' @export
ds.cor <- function(x, y, datasources = NULL) {
  ds.mean(x = x, datasources = datasources)
  NULL
}
