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

test_that("fit_all_models rejects a zero-variance binary outcome", {
  covs <- c("age", "diabetes", "hypertension")
  for (val in c(0, 1)) {
    d <- simulate_test_cohort()
    d$y <- rep(val, nrow(d))
    ps <- build_ps_model(d, "exposure", covs)
    m <- suppressWarnings(match_cohort(ps))
    expect_error(
      fit_all_models(ps, m$data, "y", type = "binary"),
      "zero variance",
      info = paste("value =", val)
    )
  }
})

test_that("fit_all_models degrades gracefully on a constant-response subset, not hard-errors (Phase 2 RHC scenario)", {
  # Original Phase 2 failure mode (see IndepAssoc_rhc_fixes_plan.md): the full
  # cohort's outcome has real variance, but the matched subset fit by the
  # mixed-effects model is constant, so lme4::glmer() throws "Response is
  # constant". The entry-level zero-variance check must NOT fire here (it only
  # validates the top-level outcome vector); the mixed model must degrade to an
  # NA row with a warning while the rest of the call continues.
  d <- simulate_test_cohort(seed = 42)
  covs <- c("age", "diabetes", "hypertension")
  ps <- build_ps_model(d, "exposure", covs)
  expect_gt(length(unique(d$outcome)), 1) # precondition: full outcome varies

  set.seed(1)
  matched_const <- data.frame(
    exposure = rep(c(1, 0), 10),
    age = rnorm(20), diabetes = rbinom(20, 1, 0.3),
    hypertension = rbinom(20, 1, 0.5),
    outcome = 0L,
    match_num = rep(1:10, each = 2)
  )
  expect_equal(length(unique(matched_const$outcome)), 1) # precondition: subset constant

  fam <- NULL
  expect_warning(
    withCallingHandlers(
      fam <- fit_all_models(ps, matched_const, "outcome", type = "binary"),
      warning = function(w) {
        if (!grepl("failed to fit", conditionMessage(w), fixed = TRUE)) {
          invokeRestart("muffleWarning")
        }
      }
    ),
    "failed to fit"
  )
  expect_s3_class(fam, "IndepOutcomeModels")
  expect_equal(nrow(fam$summary_w), 3)
  expect_null(fam$models[["Mixed effect logistic"]])
  expect_true(is.na(fam$summary_w$OR[3]))
  expect_true(is.na(fam$summary_w$p[3]))
  expect_false(is.null(fam$models[["Fully adjusted logistic"]]))
  expect_false(is.null(fam$models[["Conditional logit"]]))
  expect_true(is.finite(fam$summary_w$OR[1]))
})

test_that("fit_all_models zero-variance error names the outcome, count, and value", {
  d <- simulate_test_cohort()
  d$y <- rep(1, nrow(d))
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  err <- tryCatch(
    fit_all_models(ps, m$data, "y", type = "binary"),
    error = function(e) e
  )
  expect_s3_class(err, "simpleError")
  expect_match(conditionMessage(err), "Binary outcome `y` has zero variance")
  expect_match(conditionMessage(err), sprintf("all %d values are 1", nrow(d)))
  expect_match(conditionMessage(err), "cannot estimate a treatment effect")
})

test_that("fit_all_models backward compatibility: a normal-variance binary outcome is unaffected", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  fam <- fit_all_models(ps, m$data, "outcome", type = "binary")
  expect_s3_class(fam, "IndepOutcomeModels")
  expect_equal(nrow(fam$summary_w), 3)
  expect_true(all(is.finite(fam$summary_w$OR)))
  expect_equal(fam$summary_w$Model,
               c("Fully adjusted logistic", "Conditional logit", "Mixed effect logistic"))
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

test_that("fit_outcome rejects a zero-variance continuous outcome across all methods", {
  # Continuous analogue of the binary zero-variance guard: a constant
  # outcome gives no information for effect estimation, so every method
  # must raise the clear error instead of silently returning ~0.
  d <- simulate_test_cohort()
  d$y_const <- rep(7.25, nrow(d))
  covs <- c("age", "diabetes", "hypertension")
  for (meth in c("regression", "matching", "stratification", "iptw", "aipw")) {
    expect_error(
      fit_outcome(d, "exposure", covs, "y_const",
                  type = "continuous", method = meth, seed = 42),
      "zero variance",
      info = meth
    )
  }
})

test_that("fit_outcome continuous zero-variance error names outcome, count, and value", {
  d <- simulate_test_cohort()
  d$y_const <- 7.25
  err <- tryCatch(
    fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"),
                "y_const", type = "continuous", method = "iptw"),
    error = function(e) e
  )
  expect_s3_class(err, "simpleError")
  expect_match(conditionMessage(err),
               "Continuous outcome `y_const` has zero variance")
  expect_match(conditionMessage(err),
               sprintf("all %d values are 7.25", nrow(d)))
  expect_match(conditionMessage(err), "cannot estimate a treatment effect")
})

test_that("fit_outcome rejects a constant non-0/1 outcome when type is omitted (auto-detected continuous)", {
  d <- simulate_test_cohort()
  d$y_const <- 5
  expect_error(
    fit_outcome(d, "exposure", c("age", "diabetes", "hypertension"),
                "y_const", method = "iptw"),
    "zero variance"
  )
})

test_that("fit_outcome weighted methods accept a factor exposure on matched data", {
  # 0.6.4 allows factor-coded exposures, but match_cohort()'s returned data
  # keeps the factor column, and the weight arithmetic in iptw/aipw must
  # handle it instead of crashing on factor math. Results must equal the
  # numerically-coded equivalent run (same seed -> same matches).
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  df <- d
  df$exposure <- factor(df$exposure, labels = c("control", "treated"))
  m_f <- suppressWarnings(match_cohort(build_ps_model(df, "exposure", covs), seed = 42))
  m_n <- suppressWarnings(match_cohort(build_ps_model(d, "exposure", covs), seed = 42))
  expect_true(is.factor(m_f$data$exposure))

  for (meth in c("iptw", "aipw")) {
    rf <- fit_outcome(m_f$data, "exposure", covs, "outcome",
                      type = "binary", method = meth)
    rn <- fit_outcome(m_n$data, "exposure", covs, "outcome",
                      type = "binary", method = meth)
    expect_equal(rf$estimate, rn$estimate, tolerance = 1e-8, info = meth)
    expect_equal(rf$p_value, rn$p_value, tolerance = 1e-8, info = meth)
    expect_equal(rf$conf_low, rn$conf_low, tolerance = 1e-8, info = meth)
  }

  rc_f <- fit_outcome(m_f$data, "exposure", covs, "outcome_continuous",
                      type = "continuous", method = "iptw")
  rc_n <- fit_outcome(m_n$data, "exposure", covs, "outcome_continuous",
                      type = "continuous", method = "iptw")
  expect_equal(rc_f$estimate, rc_n$estimate, tolerance = 1e-8)

  # stratification pools per-stratum effects arithmetically -> same requirement
  rs_f <- fit_outcome(m_f$data, "exposure", covs, "outcome_continuous",
                      type = "continuous", method = "stratification")
  rs_n <- fit_outcome(m_n$data, "exposure", covs, "outcome_continuous",
                      type = "continuous", method = "stratification")
  expect_equal(rs_f$estimate, rs_n$estimate, tolerance = 1e-8)

  ra_f <- fit_outcome(m_f$data, "exposure", covs, "outcome",
                      type = "binary", estimand = "ATT", method = "stratification")
  ra_n <- fit_outcome(m_n$data, "exposure", covs, "outcome",
                      type = "binary", estimand = "ATT", method = "stratification")
  expect_equal(ra_f$estimate, ra_n$estimate, tolerance = 1e-8)
})
