#' Clamp values to a range
#'
#' Limits every element of `x` to the range from `lo` to `hi`.
#'
#' @param x A numeric vector.
#' @param lo Lower bound.
#' @param hi Upper bound.
#' @return `x` with values below `lo` set to `lo` and above `hi` set to `hi`.
#' @export
clamp <- function(x, lo = 0, hi = 1) {
  pmin(pmax(x, lo), hi)
}
