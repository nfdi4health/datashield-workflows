# The spec's "Affects" line with its hidden marker, which the implementer
# reads (queue.mjs, affectedRepositories()): only with a server package
# (settings$server) and for the spec categories. Wording from
# settings$affects.
triage_affects_lines <- function(answer, settings) {
  server <- settings$server %||% ""
  if (!nzchar(server) || !answer$category %in% unlist(settings$spec_categories)) {
    return(character(0))
  }
  value <- answer$affects %||% "this"
  if (!value %in% c("this", "both", "server")) value <- "this"
  c("", sprintf("**Affects:** %s", fill_template(settings$affects[[value]], list(SERVER = server))),
    sprintf("<!-- bot-triage-affects: %s -->", value))
}
