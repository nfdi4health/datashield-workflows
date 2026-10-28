# The datashield-type input: "none" (not a DataSHIELD package; also when
# empty), "client", "server" or "utility". Returns it; stops the run on
# anything else, so a typo fails loudly instead of silently dropping the
# role guidance.
check_datashield_type <- function(ds_type) {
  if (!nzchar(ds_type)) {
    ds_type <- "none"
  }
  allowed <- c("none", "client", "server", "utility")
  if (!ds_type %in% allowed) {
    stop(sprintf("datashield-type is '%s' — it must be one of: %s.", ds_type, paste(allowed, collapse = ", ")), call. = FALSE)
  }
  ds_type
}
