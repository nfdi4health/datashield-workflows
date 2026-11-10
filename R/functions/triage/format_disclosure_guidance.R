# The prompt's disclosure paragraph for a DataSHIELD repository
# (settings$disclosure_options set), empty otherwise.
format_disclosure_guidance <- function(settings) {
  options <- unlist(settings$disclosure_options)
  if (length(options) == 0) {
    return("")
  }
  categories <- paste(sprintf("`%s`", unlist(settings$disclosure$categories)), collapse = " and ")
  paste0(
    "This is a DataSHIELD package: analysts never see individual data, and what a server function returns ",
    "leaves the study. For ", categories, ", if the change touches what a server function returns or creates ",
    "on the server, fill `disclosure_settings` with the disclosure settings that protect it, chosen from this ",
    "list, `disclosure_below_threshold` with what should happen when a study is below the threshold (usually an ",
    "error that says why without revealing the count), and `disclosure_decision` with what the maintainer has ",
    "to decide if no setting fits or the issue leaves it open. If the issue or a comment proposes a setting, ",
    "take it. You haven't seen the code, so this is a proposal the implementer checks. For bugs and other ",
    "categories, and for changes that return nothing new, leave these fields empty.\n\nDisclosure settings: ",
    paste(sprintf("`%s`", options), collapse = ", "), "\n\n"
  )
}
