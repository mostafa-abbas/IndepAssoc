test_that("match_cohort returns correct structure", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)

  expect_s3_class(m, "IndepMatch")
  expect_true("strata" %in% names(m$data))
  expect_true(nrow(m$data) > 0)
  expect_true(nrow(m$data) <= nrow(d))
  expect_equal(m$ps_model$exposure, "exposure")
})

test_that("match_cohort respects caliper and ratio", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps, caliper = 0.1, ratio = 2)

  expect_s3_class(m, "IndepMatch")
  expect_true(nrow(m$data) > 0)
})
