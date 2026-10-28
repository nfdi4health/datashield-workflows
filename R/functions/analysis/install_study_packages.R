# Installs the usable server packages (usable_server_packages()) and
# their client packages at the same version (install_ds_package()).
# Returns list(servers, clients, tested_with, notes): the installed
# package names, a line like "dsBaseClient 6.3.5 (server: dsBase 6.3.5)"
# for script headers and the report, and notes on what differed or failed.
# The CRAN packages among them are installed together first
# (preinstall_from_cran()); install_ds_package() then finds them in place.
install_study_packages <- function(usable, catalogue, client_suffix, texts) {
  clients_wanted <- vapply(usable$package, client_package_name, character(1), catalogue = catalogue, suffix = client_suffix)
  wanted <- c(setNames(usable$version, usable$package), setNames(usable$version, clients_wanted)[!is.na(clients_wanted)])
  preinstall_from_cran(wanted, catalogue)

  servers <- character(0); clients <- character(0); tested <- character(0); notes <- character(0)
  for (i in seq_len(nrow(usable))) {
    p <- usable$package[i]; v <- usable$version[i]
    server <- install_ds_package(p, v, catalogue, texts)
    notes <- c(notes, server$note)
    if (is.na(server$installed)) {
      next
    }
    servers <- c(servers, p)
    client_name <- client_package_name(p, catalogue, client_suffix)
    if (is.na(client_name)) {
      next
    }
    client <- install_ds_package(client_name, v, catalogue, texts)
    notes <- c(notes, client$note)
    if (is.na(client$installed)) {
      next
    }
    clients <- c(clients, client_name)
    tested <- c(tested, sprintf("%s %s (server: %s %s)", client_name, client$installed, p, server$installed))
  }
  list(servers = servers, clients = clients, tested_with = paste(tested, collapse = ", "), notes = notes)
}
