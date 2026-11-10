# The disclosure part of a spec (DataSHIELD ideas, see
# settings$disclosure): the settings that apply, what happens below the
# threshold, what the maintainer has to decide. No lines when all are empty
# or the category gets none. `text` is the field cleaner of
# triage_spec_lines().
triage_disclosure_lines <- function(answer, settings, text) {
  if (!answer$category %in% unlist(settings$disclosure$categories)) {
    return(character(0))
  }
  used <- unlist(answer$disclosure_settings)
  below <- answer$disclosure_below_threshold %||% ""
  decide <- answer$disclosure_decision %||% ""
  lines <- c(
    if (length(used) > 0) sprintf("- Settings: %s", paste(sprintf("`%s`", used), collapse = ", ")),
    if (nzchar(below)) sprintf("- Below the threshold: %s", text(below)),
    if (nzchar(decide)) sprintf("- To decide: %s", text(decide))
  )
  if (length(lines) == 0) {
    return(character(0))
  }
  c("", "**Disclosure (a proposal, from the documentation only):**", lines)
}
