test_that("mean works", {
  res <- ds.mean(x = "D$LAB_TSC", type = "combine", datasources = conns)
  expect_true(is.list(res))
})
