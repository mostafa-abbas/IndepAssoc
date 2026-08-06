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

test_that("fit_outcome matching uses the matched cohort, not the full data", {
  d <- simulate_test_cohort()
  reg <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "regression")
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "matching"))
  expect_equal(res$method, "matching")
  expect_true(res$estimate > 0)
  expect_true(is.finite(res$p_value))
  expect_true(res$n < nrow(d))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
  expect_false(isTRUE(all.equal(res$estimate, reg$estimate)))
  # matching is now a conditional-logit analysis: model is clogit, and
  # res$n counts matched observations (pairs * 2). clogit (a coxph) stores
  # no model frame; the pair count comes from xlevels of the strata term.
  expect_s3_class(res$model, "clogit")
  expect_equal(res$n, length(res$model$xlevels[["strata(match_num)"]]) * 2)
})

test_that("fit_outcome matching (binary) is numerically identical to fit_all_models conditional logit", {
  d <- simulate_test_cohort()
  # Same seed before both calls: build_ps_model() consumes no RNG, so both
  # paths match the identical cohort and must agree exactly.
  set.seed(1)
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "matching"))
  set.seed(1)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  fam <- fit_all_models(ps, m$data, "outcome", type = "binary")
  # summary_w$OR is rounded to 2 dp; compare the unrounded clogit coefficient
  or_clogit <- unname(exp(stats::coef(fam$models[["Conditional logit"]])[["exposure"]]))
  expect_equal(res$estimate, or_clogit, tolerance = 1e-8)
})

test_that("fit_outcome matching (continuous) uses a within-pair estimator", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  set.seed(1)
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "matching"))
  set.seed(1)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  pair_fit <- stats::lm(outcome_cont ~ exposure + factor(match_num), data = m$data)
  expect_equal(res$estimate, unname(stats::coef(pair_fit)["exposure"]), tolerance = 1e-8)
  expect_s3_class(res$model, "lm")
  expect_true("match_num" %in% all.vars(stats::formula(res$model)))
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
  expect_s3_class(res$model, "glm")
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
  reg <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "regression")
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                     type = "continuous", method = "matching"))
  expect_equal(res$method, "matching")
  expect_true(is.finite(res$estimate))
  expect_true(res$conf_low < res$estimate && res$estimate < res$conf_high)
  expect_false(isTRUE(all.equal(res$estimate, reg$estimate)))
  expect_equal(stats::nobs(res$model), res$n)
  expect_true(stats::nobs(res$model) < nrow(d))
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

test_that("fit_outcome iptw is a marginal structural model (outcome ~ exposure only)", {
  d <- simulate_test_cohort()
  res <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "iptw")
  expect_setequal(all.vars(formula(res$model)), c("exposure", "outcome"))
  expect_false(any(c("age", "diabetes", "hypertension") %in% all.vars(formula(res$model))))

  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  res_cont <- fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome_cont",
                          type = "continuous", method = "iptw")
  expect_setequal(all.vars(formula(res_cont$model)), c("exposure", "outcome_cont"))
  expect_false(any(c("age", "diabetes", "hypertension") %in% all.vars(formula(res_cont$model))))
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

test_that("fit_outcome returns one result per method", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary",
                     method = c("regression", "matching", "stratification", "iptw", "aipw")))
  expect_type(res, "list")
  expect_named(res, c("regression", "matching", "stratification", "iptw", "aipw"))
  for (m in names(res)) {
    expect_equal(res[[m]]$method, m, info = m)
    expect_true(is.finite(res[[m]]$estimate), info = m)
  }
})

test_that("fit_outcome matching applies a seed (RNG state check)", {
  d <- simulate_test_cohort()
  runif(1)
  set.seed(42)
  expected <- .Random.seed
  set.seed(999)
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "matching", seed = 42))
  expect_identical(.Random.seed, expected)
  expect_equal(res$method, "matching")
})

test_that("fit_outcome matching re-matches already-matched data without a distance collision", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_true(all(c("distance", "weights", "subclass") %in% names(m$data)))
  res <- suppressWarnings(fit_outcome(m$data, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "matching"))
  expect_equal(res$method, "matching")
  expect_true(is.finite(res$estimate))
  expect_true(all(is.finite(c(res$conf_low, res$conf_high, res$p_value))))
})

test_that("fit_outcome matching with seed = NULL does not seed", {
  d <- simulate_test_cohort()
  runif(1)
  set.seed(999)
  pre <- .Random.seed
  res <- suppressWarnings(fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                     type = "binary", method = "matching", seed = NULL))
  expect_identical(.Random.seed, pre)
  expect_equal(res$method, "matching")
})
