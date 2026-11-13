# Whether an error from a Claude call is the subscription's usage limit
# (the 5-hour or weekly limit), with the same pattern as the implementer's
# parseLimit() (.github/actions/implementer/outcome.mjs): further calls
# would fail the same way until the limit resets.
is_usage_limit <- function(message) {
  grepl("usage limit|hit your (usage )?limit|limit reached|out of (extra )?usage|weekly limit", message,
    ignore.case = TRUE)
}
