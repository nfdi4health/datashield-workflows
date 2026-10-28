#' @param idCol the name of the ID column in the data frame.
#' @param data something
#' @param nBreaks number of breaks
#' @param datasources a list of DSConnection-class objects.
#' @export
ds.recode <- function(data, idCol, nBreaks = 10, datasources = NULL, extra = NULL) {
  ds.merge(x.name = data, y.name = data, by.x.names = idCol, newobj.name = "tmp")
}
