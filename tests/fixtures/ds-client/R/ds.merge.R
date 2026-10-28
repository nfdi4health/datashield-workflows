#' @param x.name a character string naming the first data frame.
#' @param y.name a character string naming the second data frame.
#' @param by.x.names column names in x to merge by.
#' @param newobj.name the name of the new object created on the server.
#' @param datasources a list of DSConnection-class objects.
#' @export
ds.merge <- function(x.name, y.name, by.x.names, newobj.name = "merge.newobj", datasources = NULL) {
	calltext <- call("mergeDS", x.name, y.name, by.x.names)
	DSI::datashield.assign(datasources, newobj.name, calltext)
}
