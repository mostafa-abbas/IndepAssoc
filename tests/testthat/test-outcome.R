test_that("fit_all_models has no mislabeled doubly robust model", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  bin <- fit_all_models(ps, m$data, "outcome", type = "binary")
  cont <- fit_all_models(ps, m$data, "outcome", type = "continuous")
  expect_false(any(grepl("Doubly robust", names(bin$models))))
  expect_false(any(grepl("Doubly robust", names(cont$models))))
  expect_equal(length(bin$models), 3)
  expect_equal(length(cont$models), 3)
})

test_that("model_summ anchors the treatment feature to the left", {
  set.seed(3)
  d <- data.frame(
    outcome = rbinom(200, 1, 0.4),
    treatment = rbinom(200, 1, 0.5),
    prev_treatment = rnorm(200),
    age = rnorm(200)
  )
  fit <- glm(outcome ~ treatment + prev_treatment + age, data = d, family = "binomial")
  summ <- model_summ(fit, "treatment", type = "binary")
  expect_equal(rownames(summ), "treatment")
})

test_that("model_summ captures all levels of a factor exposure", {
  set.seed(4)
  d <- data.frame(
    outcome = rbinom(300, 1, 0.4),
    treatment = factor(sample(c("none", "low", "high"), 300, replace = TRUE),
                       levels = c("none", "low", "high")),
    age = rnorm(300)
  )
  fit <- glm(outcome ~ treatment + age, data = d, family = "binomial")
  summ <- model_summ(fit, "treatment", type = "binary")
  expect_setequal(rownames(summ), c("treatmentlow", "treatmenthigh"))
  expect_equal(nrow(summ), 2)
})

test_that("model_summ picks the exact exposure row, not a prefix-colliding covariate", {
  set.seed(5)
  d <- data.frame(
    outcome = rbinom(200, 1, 0.4),
    age_group = rnorm(200),
    age = rnorm(200)
  )
  fit <- glm(outcome ~ age_group + age, data = d, family = "binomial")
  summ <- model_summ(fit, "age", type = "binary")
  expect_equal(rownames(summ), "age")
  expect_equal(unname(summ$OR[1]), unname(exp(coef(fit)["age"])), tolerance = 1e-8)
})

test_that("model_summ errors clearly when the treatment is not in the model", {
  set.seed(6)
  d <- data.frame(
    outcome = rbinom(100, 1, 0.4),
    exposure = rbinom(100, 1, 0.5)
  )
  fit <- glm(outcome ~ exposure, data = d, family = "binomial")
  expect_error(model_summ(fit, "not_in_model", type = "binary"),
               "No coefficient row found")
})

test_that("model_summ handles a two-level factor exposure", {
  set.seed(7)
  d <- data.frame(
    outcome = rbinom(200, 1, 0.4),
    grp = factor(sample(c("A", "B"), 200, replace = TRUE)),
    age = rnorm(200)
  )
  fit <- glm(outcome ~ grp + age, data = d, family = "binomial")
  summ <- model_summ(fit, "grp", type = "binary")
  expect_equal(rownames(summ), "grpB")
})

.wald_bound <- function(mod, term = "exposure") {
  sc <- summary(mod)$coefficients
  est_col <- grep("Estimate", colnames(sc), value = TRUE)
  if (length(est_col) == 0) est_col <- grep("^coef", colnames(sc), value = TRUE)
  se_col <- grep("Std. Error", colnames(sc), value = TRUE)
  if (length(se_col) == 0) se_col <- grep("^se", colnames(sc), value = TRUE)
  row_idx <- grep(paste0("^", term), rownames(sc))[1]
  est <- unname(sc[row_idx, est_col[1]])
  se <- as.numeric(sc[row_idx, se_col[1]])
  c(lower = est - qnorm(0.975) * se, upper = est + qnorm(0.975) * se)
}

test_that("model_summ applies an explicit Wald interval for every model class", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  bin <- fit_all_models(ps, m$data, "outcome", type = "binary")
  cont <- fit_all_models(ps, m$data, "outcome", type = "continuous")

  for (nm in names(bin$models)) {
    summ <- model_summ(bin$models[[nm]], "exposure", type = "binary")
    w <- exp(.wald_bound(bin$models[[nm]]))
    expect_equal(unname(summ$lower[1]), unname(w["lower"]), tolerance = 1e-6, info = nm)
    expect_equal(unname(summ$upper[1]), unname(w["upper"]), tolerance = 1e-6, info = nm)
  }
  for (nm in names(cont$models)) {
    summ <- model_summ(cont$models[[nm]], "exposure", type = "continuous")
    w <- .wald_bound(cont$models[[nm]])
    expect_equal(unname(summ$lower[1]), unname(w["lower"]), tolerance = 1e-6, info = nm)
    expect_equal(unname(summ$upper[1]), unname(w["upper"]), tolerance = 1e-6, info = nm)
  }
})

test_that("fit_all_models returns IndepOutcomeModels for binary outcome", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  res <- fit_all_models(ps, m$data, "outcome", type = "binary")
  expect_s3_class(res, "IndepOutcomeModels")
  expect_equal(res$type, "binary")
  expect_true("OR" %in% names(res$summary_w))
  expect_true("p" %in% names(res$summary_w))
})

test_that("fit_all_models errors on missing outcome", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_error(fit_all_models(ps, m$data, "fake_outcome", type = "binary"), "not found")
})

test_that("fit_all_models has no dead parameters", {
  expect_false("covariates" %in% names(formals(fit_all_models)))
  expect_false("normalize_continuous" %in% names(formals(fit_all_models)))
})

test_that("fit_all_models conditional logit is built by the shared helper", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  cond <- fit_all_models(ps, m$data, "outcome", type = "binary")$models[["Conditional logit"]]
  expected <- IndepAssoc:::.fit_conditional_logit(m$data, "exposure", "outcome")
  expect_equal(cond$coefficients, expected$coefficients)
  expect_equal(cond$loglik, expected$loglik)
})

test_that("fit_all_models degrades gracefully when the mixed-effect response is constant", {
  d <- simulate_test_cohort()
  d$outcome <- 0L
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_warning(
    withCallingHandlers(
      fam <- fit_all_models(ps, m$data, "outcome", type = "binary"),
      warning = function(w) {
        if (!grepl("failed to fit", conditionMessage(w), fixed = TRUE)) {
          invokeRestart("muffleWarning")
        }
      }
    ),
    "failed to fit"
  )
  expect_null(fam$models[["Mixed effect logistic"]])
  expect_false(is.null(fam$models[["Fully adjusted logistic"]]))
  expect_false(is.null(fam$models[["Conditional logit"]]))
  me_row <- fam$summary_w[fam$summary_w$Model == "Mixed effect logistic", ]
  expect_true(is.na(me_row$OR))
  expect_true(is.na(me_row$p))
  expect_equal(nrow(fam$summary_w), 3)
  expect_false(any(is.na(fam$summary_w[fam$summary_w$Model == "Fully adjusted logistic", "OR"])))
})

test_that("fit_all_models degrades gracefully when the continuous response is constant", {
  d <- simulate_test_cohort()
  d$outcome_cont <- 5
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  saw_failed <- FALSE
  expect_warning(
    withCallingHandlers(
      fam <- fit_all_models(ps, m$data, "outcome_cont", type = "continuous"),
      warning = function(w) {
        is_failed <- grepl("failed to fit", conditionMessage(w), fixed = TRUE)
        if (!is_failed || saw_failed) invokeRestart("muffleWarning")
        if (is_failed) saw_failed <<- TRUE
      }
    ),
    "failed to fit"
  )
  expect_false(is.null(fam$models[["Fully adjusted linear regression"]]))
  cond_row <- fam$summary_w[fam$summary_w$Model == "Conditional linear regression", ]
  me_row <- fam$summary_w[fam$summary_w$Model == "Mixed effect linear regression", ]
  expect_true(is.na(cond_row$SC))
  expect_true(is.na(cond_row$p))
  expect_true(is.na(me_row$SC))
  expect_true(is.na(me_row$p))
  expect_equal(nrow(fam$summary_w), 3)
  expect_false(any(is.na(fam$summary_w[fam$summary_w$Model == "Fully adjusted linear regression", "SC"])))
})
