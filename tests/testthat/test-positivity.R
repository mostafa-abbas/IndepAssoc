# Tests for Phase 20: check_positivity() and the IPTW/AIPW `trim` parameter.

test_that("check_positivity flags a known positivity violation", {
  # Two deterministic exposure groups with fitted PS 0.003 and 0.997, both
  # outside the default [0.01, 0.99] support window. For a single binary
  # covariate the saturated logistic fit reproduces the empirical group
  # proportions exactly, so the extremes are guaranteed, not stochastic.
  x <- c(rep(0, 1000), rep(1, 1000))
  a <- c(rep(0, 997), rep(1, 3), rep(0, 3), rep(1, 997))
  set.seed(1)
  y <- rnorm(2000)
  d <- data.frame(exposure = a, x = x, y = y)

  ps <- build_ps_model(d, "exposure", "x")
  res <- check_positivity(ps)

  expect_s3_class(res, "IndepPositivity")
  expect_true(res$violation)
  expect_gt(res$ps_violations$n_below, 0)
  expect_gt(res$ps_violations$n_above, 0)
  expect_equal(res$ps_violations$n_below + res$ps_violations$n_above,
               res$ps_violations$n_total)
  expect_equal(nrow(res$ps_by_group), 2)
  expect_true(all(c("min", "q25", "median", "q75", "max") %in% names(res$ps_by_group)))
})

test_that("check_positivity does not flag well-overlapped propensity scores", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  p <- ps$data$.ps
  expect_true(all(p > 0.05 & p < 0.95))

  res <- check_positivity(ps)
  expect_false(res$violation)
  expect_equal(res$ps_violations$n_below, 0)
  expect_equal(res$ps_violations$n_above, 0)
})

test_that("check_positivity reports the IPTW weight distribution", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  res <- check_positivity(ps, estimand = "ATE")
  w <- res$weights
  expect_equal(w$estimand, "ATE")
  expect_equal(w$n, nrow(d))
  expect_true(w$max_min_ratio >= 1)
  expect_true(all(is.finite(c(w$min, w$median, w$max))))
  expect_true(w$min <= w$median && w$median <= w$max)

  res_att <- check_positivity(ps, estimand = "ATT")
  expect_equal(res_att$weights$estimand, "ATT")
})

test_that("iptw trim=NULL is backward compatible and trim truncates weights exactly", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  default <- fit_outcome(d, "exposure", covs, "outcome_continuous",
                         type = "continuous", method = "iptw")
  null_trim <- fit_outcome(d, "exposure", covs, "outcome_continuous",
                           type = "continuous", method = "iptw", trim = NULL)
  expect_equal(null_trim$estimate, default$estimate, tolerance = 1e-12)
  expect_equal(null_trim$conf_low, default$conf_low, tolerance = 1e-12)
  expect_equal(null_trim$conf_high, default$conf_high, tolerance = 1e-12)
  expect_equal(null_trim$p_value, default$p_value, tolerance = 1e-12)

  # Recompute the untrimmed stabilized weights exactly as .fit_iptw does,
  # then apply the same percentile truncation by hand.
  ps <- build_ps_model(d, "exposure", covs)
  p <- pmin(pmax(ps$data$.ps, 1e-6), 1 - 1e-6)
  a <- d$exposure
  num <- mean(a)
  sw <- ifelse(a == 1, num / p, (1 - num) / (1 - p))
  q <- stats::quantile(sw, probs = c(0.05, 0.95), names = FALSE)
  expected <- pmin(pmax(sw, q[1]), q[2])

  res <- fit_outcome(d, "exposure", covs, "outcome_continuous",
                     type = "continuous", method = "iptw", trim = c(0.05, 0.95))
  expect_equal(res$model$weights, expected, tolerance = 1e-12)
  expect_gt(sum(res$model$weights < default$model$weights), 0)
})

test_that("aipw trim=NULL is backward compatible and trimming changes extreme weights", {
  # Inject treated units at very low propensity scores so the a/p weight is
  # extreme; a tight trim must pull the estimate back toward the bulk.
  set.seed(2)
  n <- 400
  x <- rnorm(n)
  a <- rbinom(n, 1, plogis(-0.5 + 0.8 * x))
  y <- rnorm(n, 30 + 1.5 * a + 0.3 * x)
  inject <- which(a == 1)[1:5]
  x[inject] <- -5
  d <- data.frame(exposure = a, x = x, y = y)

  default <- fit_outcome(d, "exposure", "x", "y", type = "continuous", method = "aipw")
  null_trim <- fit_outcome(d, "exposure", "x", "y", type = "continuous",
                           method = "aipw", trim = NULL)
  expect_equal(null_trim$estimate, default$estimate, tolerance = 1e-12)
  expect_equal(null_trim$conf_low, default$conf_low, tolerance = 1e-12)
  expect_equal(null_trim$conf_high, default$conf_high, tolerance = 1e-12)

  tight <- fit_outcome(d, "exposure", "x", "y", type = "continuous",
                       method = "aipw", trim = c(0.49, 0.51))
  expect_true(all(is.finite(c(tight$estimate, tight$conf_low, tight$conf_high, tight$p_value))))
  expect_false(isTRUE(all.equal(tight$estimate, default$estimate, tolerance = 1e-8)))
})

test_that("trim is validated", {
  d <- simulate_test_cohort()
  expect_error(fit_outcome(d, "exposure", "age", "outcome_continuous", type = "continuous",
                           method = "iptw", trim = c(0.1, 0.5, 0.9)), "trim")
  expect_error(fit_outcome(d, "exposure", "age", "outcome_continuous", type = "continuous",
                           method = "iptw", trim = c(-0.1, 0.9)), "trim")
  expect_error(fit_outcome(d, "exposure", "age", "outcome_continuous", type = "continuous",
                           method = "iptw", trim = 1.5), "trim")
})

test_that("check_positivity runs on rhc_sample real data", {
  data(rhc_sample)
  ps <- build_ps_model(rhc_sample$data, "swang1", rhc_sample$covariates)
  res <- check_positivity(ps)
  expect_s3_class(res, "IndepPositivity")
  expect_type(res$violation, "logical")
  expect_equal(res$weights$n, nrow(rhc_sample$data))
  expect_true(is.finite(res$weights$max_min_ratio))
  expect_true(res$weights$max_min_ratio >= 1)

  fit <- fit_outcome(rhc_sample$data, "swang1", rhc_sample$covariates, "dth30",
                     type = "binary", method = "iptw", trim = c(0.01, 0.99))
  expect_true(is.finite(fit$estimate))
})

test_that("run_pipeline emits the positivity/weight summary and returns it", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  expect_message(
    res <- suppressWarnings(run_pipeline(d, "exposure", covs, "outcome", type = "binary",
                          methods = c("iptw", "aipw"), seed = 1)),
    "Positivity", ignore.case = TRUE
  )
  expect_s3_class(res$positivity, "IndepPositivity")
  expect_type(res$positivity$violation, "logical")
})
