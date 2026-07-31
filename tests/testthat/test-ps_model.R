test_that("build_ps_model returns correct structure", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))

  expect_s3_class(ps, "IndepPSModel")
  expect_true(".ps" %in% names(ps$data))
  expect_true(all(ps$data$.ps >= 0 & ps$data$.ps <= 1))
  expect_equal(nrow(ps$data), nrow(d))
  expect_equal(ps$exposure, "exposure")
  expect_equal(length(ps$covariates), 3)
})

test_that("build_ps_model errors on missing exposure", {
  d <- simulate_test_cohort()
  expect_error(build_ps_model(d, "missing_var", c("age")), "not found")
})

test_that("build_ps_model errors on missing covariates", {
  d <- simulate_test_cohort()
  expect_error(build_ps_model(d, "exposure", c("age", "fake_var")), "not found")
})
