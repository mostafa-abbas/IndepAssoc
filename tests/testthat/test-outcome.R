test_that("fit_outcome works for binary outcome", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  res <- fit_outcome(m, "outcome", type = "binary")

  expect_s3_class(res, "IndepOutcome")
  expect_equal(res$type, "binary")
  expect_true("estimate" %in% names(res$tidy))
  expect_true("p.value" %in% names(res$tidy))
})

test_that("fit_outcome errors on missing outcome", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  expect_error(fit_outcome(m, "fake_outcome", type = "binary"), "not found")
})

test_that("fit_outcome requires time_var for survival", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  expect_error(fit_outcome(m, "outcome", type = "time_to_event"), "time_var")
})
