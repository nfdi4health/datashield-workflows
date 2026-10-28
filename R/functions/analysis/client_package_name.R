# The client package paired with a server package, by the DataSHIELD naming
# convention (dsBase -> dsBaseClient; `suffix` from the settings). NA if
# the catalogue is known and has no such package: then the server package
# has no client to install.
client_package_name <- function(server_package, catalogue, suffix) {
  client <- paste0(server_package, suffix)
  if (length(catalogue) > 0 && !client %in% names(catalogue)) {
    return(NA_character_)
  }
  client
}
