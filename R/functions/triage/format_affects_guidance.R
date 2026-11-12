# The prompt's paragraph on which repositories a change affects, when the
# repository has a server package (settings$server, the input `server`);
# empty otherwise.
format_affects_guidance <- function(settings) {
  server <- settings$server %||% ""
  if (!nzchar(server)) {
    return("")
  }
  paste0(
    "This package's server side is `", server, "`. For `bug` and `idea`, set `affects`: `this` if the change ",
    "stays in this repository, `both` if the server package has to change too, `server` if only the server ",
    "package has to change (then the issue belongs there). Judge from the documentation shown: a server ",
    "function (a name ending in `DS`) that has to return or compute something else, disclosure settings, or ",
    "results computed on the server point to the server package. You haven't seen the code: this is a ",
    "proposal the maintainer can correct. For other categories use `this`.\n\n"
  )
}
