test_that("check_balance returns correct structure", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  bal <- check_balance(m)

  expect_s3_class(bal, "IndepBalance")
  expect_true(is.logical(bal$all_balanced))
  expect_equal(bal$threshold, 0.10)
})
