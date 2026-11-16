# The direction of a method's share over the years: a binomial model of
# papers using it (`k`) of the papers read (`n`) per year. "rising" or
# "falling" when the year's effect is clear (p < 0.05), else "steady";
# "–" with fewer than 3 years of data.
method_trend <- function(years, k, n) {
  keep <- n > 0
  if (sum(keep) < 3) return("–")
  fit <- suppressWarnings(stats::glm(cbind(k[keep], n[keep] - k[keep]) ~ years[keep], family = stats::binomial()))
  co <- summary(fit)$coefficients
  if (nrow(co) < 2 || is.na(co[2, 4]) || co[2, 4] >= 0.05) return("steady")
  if (co[2, 1] > 0) "rising" else "falling"
}
