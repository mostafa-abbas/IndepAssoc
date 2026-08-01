test_that("fit_outcome dispatches to regression for binary outcome", {
  d <- simulate_test_cohort()
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "regression")
  expect_type(res, "list")
  expect_equal(res$method, "regression")
  expect_equal(res$type, "binary")
  expect_true(res$estimate > 0)
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
  expect_true(is.finite(res$p_value))
  expect_s3_class(res$model, "glm")
  expect_equal(res$n, nrow(d))
})

test_that("fit_outcome dispatches to regression for continuous outcome", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "regression")
  expect_equal(res$method, "regression")
  expect_s3_class(res$model, "lm")
  expect_true(res$estimate != 0)
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})

test_that("fit_outcome errors on unknown method", {
  d <- simulate_test_cohort()
  expect_error(fit_outcome(d, "exposure", "age", "outcome", type = "binary", method = "nope"),
               "method")
})

test_that("fit_outcome validates inputs", {
  d <- simulate_test_cohort()
  expect_error(fit_outcome(d, "missing_exposure", "age", "outcome", type = "binary"),
               "not found")
  expect_error(fit_outcome(d, "exposure", c("age", "nope"), "outcome", type = "binary"),
               "not found")
  expect_error(fit_outcome(d, "exposure", "age", "missing_outcome", type = "binary"),
               "not found")
})

test_that("fit_outcome matching method returns a real estimate", {
  d <- simulate_test_cohort()
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "matching")
  expect_equal(res$method, "matching")
  expect_true(res$estimate > 0)
  expect_true(is.finite(res$p_value))
  expect_true(res$n < nrow(d))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})

test_that("fit_outcome stratification method pools strata", {
  d <- simulate_test_cohort()
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "stratification")
  expect_equal(res$method, "stratification")
  expect_true(res$estimate > 0)
  expect_true(is.finite(res$p_value))
  expect_null(res$model)
  expect_equal(res$n, nrow(d))
})

test_that("fit_outcome iptw method returns a real estimate", {
  d <- simulate_test_cohort()
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "iptw")
  expect_equal(res$method, "iptw")
  expect_true(res$estimate > 0)
  expect_true(is.finite(res$p_value))
  expect_s3_class(res$model, "svyglm")
  expect_equal(res$n, nrow(d))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})

test_that("fit_outcome iptw works for continuous outcome", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "iptw")
  expect_equal(res$method, "iptw")
  expect_true(is.finite(res$estimate))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})

test_that("fit_outcome aipw method returns a real estimate", {
  d <- simulate_test_cohort()
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "aipw")
  expect_equal(res$method, "aipw")
  expect_true(res$estimate > 0)
  expect_true(is.finite(res$p_value))
  expect_s3_class(res$model, "glm")
  expect_equal(res$n, nrow(d))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})

test_that("aipw recovers a known binary treatment effect", {
  set.seed(42)
  n <- 2000
  x <- rnorm(n)
  a <- rbinom(n, 1, plogis(0.5 * x))
  y <- rbinom(n, 1, plogis(-1 + 0.8 * a + 0.5 * x))
  d <- data.frame(a = a, x = x, y = y)
  res <- fit_outcome(d, "a", "x", "y", type = "binary", method = "aipw")
  expect_true(abs(log(res$estimate) - 0.8) < 0.25)
})

test_that("fit_outcome matching works for continuous outcome", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "matching")
  expect_equal(res$method, "matching")
  expect_true(is.finite(res$estimate))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})

test_that("fit_outcome stratification works for continuous outcome", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "stratification")
  expect_equal(res$method, "stratification")
  expect_true(is.finite(res$estimate))
  expect_null(res$model)
})

test_that("fit_outcome aipw works for continuous outcome", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "aipw")
  expect_equal(res$method, "aipw")
  expect_true(is.finite(res$estimate))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
})
