test_that("lalonde matching and iptw land in a sanity band around the experimental ATT", {
  set.seed(1)
  d <- MatchIt::lalonde
  res <- run_pipeline(
    data = d,
    exposure = "treat",
    covariates = c("age", "educ", "race", "married", "nodegree", "re74", "re75"),
    outcome = "re78",
    type = "continuous",
    methods = c("matching", "iptw")
  )
  comp <- res$comparison
  expect_equal(nrow(comp), 2)
  expect_equal(comp$method, c("matching", "iptw"))
  expect_true(all(comp$estimate > 0 & comp$estimate < 3000))
  benchmark <- 1794
  match_dist <- abs(comp$estimate[comp$method == "matching"] - benchmark)
  iptw_dist <- abs(comp$estimate[comp$method == "iptw"] - benchmark)
  expect_lt(match_dist, iptw_dist)
})
