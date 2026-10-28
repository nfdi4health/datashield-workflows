# Builds the canonical multi-study DataSHIELD login example code from
# datashield-example-env.yml, for use in the @examples field.
build_demo_login_snippet <- function(package_name, group, server) {
  appends <- vapply(group$studies, function(s) {
    sprintf(
      paste(
        "builder$append(server = \"%s\",",
        "               url = \"%s\",",
        "               user = \"%s\", password = \"%s\",",
        "               table = \"%s\", driver = \"%s\")",
        sep = "\n"
      ),
      s$server_label, server$url, server$user, server$password, s$table, server$driver
    )
  }, character(1))

  paste(
    "require('DSI')",
    "require('DSOpal')",
    sprintf("require('%s')", package_name),
    "",
    "builder <- DSI::newDSLoginBuilder()",
    paste(appends, collapse = "\n"),
    "logindata <- builder$build()",
    "connections <- DSI::datashield.login(logins = logindata, assign = TRUE, symbol = \"D\")",
    "",
    "# ... call the function being documented here ...",
    "",
    "datashield.logout(connections)",
    sep = "\n"
  )
}
