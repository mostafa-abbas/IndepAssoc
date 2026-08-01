test_that("plot_comparison returns a ggplot", {
  d <- simulate_test_cohort()
  res <- run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                      type = "binary", methods = c("regression", "iptw", "aipw"))
  p <- plot_comparison(res$comparison)
  expect_s3_class(p, "ggplot")
})
