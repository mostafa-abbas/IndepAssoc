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

test_that("build_ps_model errors when the data has fewer than 4 rows", {
  expect_error(build_ps_model(data.frame(exposure = 1, x = 0.5), "exposure", "x"),
               "`data` must contain at least 4 rows")
  expect_error(build_ps_model(data.frame(exposure = 0, x = 0.5), "exposure", "x"),
               "`data` must contain at least 4 rows")
  expect_error(build_ps_model(data.frame(exposure = c(0, 0, 1), x = c(0.2, 0.4, 0.6)),
               "exposure", "x"),
               "`data` must contain at least 4 rows")
})

test_that("build_ps_model errors when there are no control units", {
  d <- data.frame(exposure = c(1, 1, 1, 1), x = c(0.2, 0.4, 0.6, 0.8))
  expect_error(build_ps_model(d, "exposure", "x"),
               "No control units found in the data")
})

test_that("build_ps_model errors when there are no treated units", {
  d <- data.frame(exposure = c(0, 0, 0, 0), x = c(0.2, 0.4, 0.6, 0.8))
  expect_error(build_ps_model(d, "exposure", "x"),
               "No treated units found in the data")
})

test_that("build_ps_model errors when either exposure arm has fewer than 2 units", {
  d1 <- data.frame(exposure = c(0, 0, 0, 1), x = c(0.2, 0.4, 0.6, 0.8))
  expect_error(build_ps_model(d1, "exposure", "x"),
               "Each exposure arm must contain at least 2 units")
  d2 <- data.frame(exposure = c(rep(0, 9), 1), x = seq(0, 1, length.out = 10))
  expect_error(build_ps_model(d2, "exposure", "x"),
               "Each exposure arm must contain at least 2 units")
})

test_that("build_ps_model warns but proceeds when an exposure arm has fewer than 10 units", {
  d <- data.frame(exposure = c(0, 0, 1, 1), x = c(0.1, 0.8, 0.2, 0.7))
  expect_warning(
    ps <- build_ps_model(d, "exposure", "x"),
    "may be unreliable at this sample size"
  )
  expect_s3_class(ps, "IndepPSModel")
})

test_that("build_ps_model warns naming the small arm", {
  d <- data.frame(exposure = c(rep(0, 9), rep(1, 11)),
                  x = c(seq(0, 0.8, length.out = 9), seq(0.2, 1, length.out = 11)))
  expect_warning(
    ps <- build_ps_model(d, "exposure", "x"),
    "control arm has 9 observations"
  )
  expect_s3_class(ps, "IndepPSModel")
})

test_that("build_ps_model backward compatibility: both arms >= 10 do not warn", {
  d <- data.frame(exposure = c(rep(0, 10), rep(1, 10)),
                  x = c(seq(0, 0.9, length.out = 10), seq(0.1, 1, length.out = 10)))
  expect_no_warning(ps <- build_ps_model(d, "exposure", "x"))
  expect_s3_class(ps, "IndepPSModel")
})

test_that("build_ps_model backward compatibility: a healthy cohort is unaffected", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  expect_no_warning(ps <- build_ps_model(d, "exposure", covs))
  expect_s3_class(ps, "IndepPSModel")

  manual <- stats::glm(exposure ~ age + diabetes + hypertension, data = d,
                       family = "binomial")
  expect_equal(coef(ps$model), coef(manual))
  expect_equal(ps$data$.ps, unname(stats::predict(manual, type = "response")))
})
