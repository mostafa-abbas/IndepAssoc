# Tests for the `estimand` parameter (Phase 19): ATE (default, unchanged) vs ATT
# via SMR weights for IPTW/AIPW and treated-count-weighted pooling for
# stratification. Formula source: Austin (2011), Multivariate Behavioral
# Research 46(3):399-424, doi:10.1080/00273171.2011.568786.

test_that("estimand = \"ATE\" and the omitted default are numerically identical (backward compatibility)", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  for (m in c("iptw", "aipw", "stratification")) {
    default <- fit_outcome(d, "exposure", covs, "outcome",
                           type = "binary", method = m)
    ate <- fit_outcome(d, "exposure", covs, "outcome",
                       type = "binary", method = m, estimand = "ATE")
    expect_equal(ate$estimate, default$estimate, tolerance = 1e-12, info = paste(m, "binary estimate"))
    expect_equal(ate$conf_low, default$conf_low, tolerance = 1e-12, info = paste(m, "binary conf_low"))
    expect_equal(ate$conf_high, default$conf_high, tolerance = 1e-12, info = paste(m, "binary conf_high"))
    expect_equal(ate$p_value, default$p_value, tolerance = 1e-12, info = paste(m, "binary p_value"))
  }

  set.seed(1)
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))
  for (m in c("iptw", "aipw", "stratification")) {
    default <- fit_outcome(d, "exposure", covs, "outcome_cont",
                           type = "continuous", method = m)
    ate <- fit_outcome(d, "exposure", covs, "outcome_cont",
                       type = "continuous", method = m, estimand = "ATE")
    expect_equal(ate$estimate, default$estimate, tolerance = 1e-12, info = paste(m, "continuous estimate"))
    expect_equal(ate$conf_low, default$conf_low, tolerance = 1e-12, info = paste(m, "continuous conf_low"))
    expect_equal(ate$conf_high, default$conf_high, tolerance = 1e-12, info = paste(m, "continuous conf_high"))
    expect_equal(ate$p_value, default$p_value, tolerance = 1e-12, info = paste(m, "continuous p_value"))
  }
})

test_that("iptw estimand = \"ATT\" uses SMR weights W = A + (1-A)*ps/(1-ps)", {
  # Binary covariate => closed-form propensity score equal to the exposure
  # proportion within each group, so the expected weights are computable by hand.
  set.seed(1)
  n <- 200
  x <- rep(c(0, 1), each = n / 2)
  a <- rbinom(n, 1, rep(c(0.25, 0.75), each = n / 2))
  y <- rnorm(n, 50 + 2 * a + 0.5 * x)
  d <- data.frame(exposure = a, x = x, y = y)

  res <- fit_outcome(d, "exposure", "x", "y", type = "continuous",
                     method = "iptw", estimand = "ATT")

  ps <- ifelse(x == 0, mean(a[x == 0]), mean(a[x == 1]))
  expected_w <- ifelse(a == 1, 1, ps / (1 - ps))
  # Tolerance accommodates glm IRLS convergence noise against the closed-form
  # group proportions; the formula itself is verified exactly.
  expect_equal(res$model$weights, expected_w, tolerance = 1e-9)
})

test_that("iptw/aipw with estimand = \"ATT\" track the treated population (matching and true ATT)", {
  set.seed(42)
  n <- 3000
  x <- rnorm(n)
  e <- plogis(0.3 * x)          # moderate selection: treated concentrate at higher x
  a <- rbinom(n, 1, e)
  # Effect modification by x: the effect grows where treated units concentrate,
  # so the true ATT differs from the true ATE.
  y0 <- 0.3 * x + rnorm(n, 0, 1)
  y1 <- y0 + 0.5 + 2.0 * x + rnorm(n, 0, 1)
  y <- ifelse(a == 1, y1, y0)
  d <- data.frame(exposure = a, x = x, y = y)

  true_att <- 0.5 + 2.0 * mean(x[a == 1])   # E[0.5 + 2x | A = 1]
  true_ate <- 0.5                            # E[0.5 + 2x] = 0.5

  # A wide caliper keeps (nearly) every treated unit, so matching's estimand is
  # the full treated population -- the same population the SMR weights target.
  matching <- suppressWarnings(fit_outcome(d, "exposure", "x", "y", type = "continuous",
                                           method = "matching", seed = 1, caliper = 5))
  iptw_att <- fit_outcome(d, "exposure", "x", "y", type = "continuous",
                          method = "iptw", estimand = "ATT")
  aipw_att <- fit_outcome(d, "exposure", "x", "y", type = "continuous",
                          method = "aipw", estimand = "ATT")
  iptw_ate <- fit_outcome(d, "exposure", "x", "y", type = "continuous", method = "iptw")
  aipw_ate <- fit_outcome(d, "exposure", "x", "y", type = "continuous", method = "aipw")

  # Ground truth: ATT mode hits the treated population, ATE mode the full sample.
  expect_lt(abs(iptw_att$estimate - true_att), 0.2)
  expect_lt(abs(aipw_att$estimate - true_att), 0.2)
  expect_lt(abs(iptw_ate$estimate - true_ate), 0.2)
  expect_lt(abs(aipw_ate$estimate - true_ate), 0.2)
  expect_lt(abs(matching$estimate - true_att), 0.2)

  # Concept: the ATT-weighted methods agree with matching (both treated-focused)
  # much more closely than the ATE estimates do.
  expect_lt(abs(iptw_att$estimate - matching$estimate),
            abs(iptw_ate$estimate - matching$estimate))
  expect_lt(abs(aipw_att$estimate - matching$estimate),
            abs(aipw_ate$estimate - matching$estimate))
})

test_that("method = \"matching\" with estimand = \"ATT\" is a silent no-op identical to default", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  default <- suppressWarnings(fit_outcome(d, "exposure", covs, "outcome",
                                          type = "binary", method = "matching", seed = 1))
  att <- suppressWarnings(fit_outcome(d, "exposure", covs, "outcome",
                                      type = "binary", method = "matching", seed = 1,
                                      estimand = "ATT"))
  expect_equal(att$estimate, default$estimate, tolerance = 1e-12)
  expect_equal(att$conf_low, default$conf_low, tolerance = 1e-12)
  expect_equal(att$conf_high, default$conf_high, tolerance = 1e-12)
  expect_equal(att$p_value, default$p_value, tolerance = 1e-12)
  expect_equal(att$n, default$n)
})

test_that("stratification estimand = \"ATT\" weights strata by treated count", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  set.seed(1)
  d$outcome_cont <- 50 + 2 * d$exposure + rnorm(nrow(d))

  res <- fit_outcome(d, "exposure", covs, "outcome_cont", type = "continuous",
                     method = "stratification", estimand = "ATT")

  # Hand replicate: quantile strata on the PS, within-stratum exposure
  # coefficients, pooled with weights equal to the treated count per stratum.
  ps <- build_ps_model(d, "exposure", covs)
  q <- stats::quantile(ps$data$.ps, probs = seq(0, 1, length.out = 6), na.rm = TRUE)
  q[1] <- -Inf; q[length(q)] <- Inf
  d$.stratum <- cut(ps$data$.ps, breaks = q, include.lowest = TRUE, labels = FALSE)
  d$.stratum <- as.numeric(d$.stratum)
  est <- se <- n1 <- numeric(length(unique(d$.stratum)))
  for (s in unique(d$.stratum)) {
    sub <- d[d$.stratum == s, ]
    m <- stats::lm(outcome_cont ~ exposure, data = sub)
    est[s] <- unname(stats::coef(m)["exposure"])
    se[s] <- summary(m)$coefficients["exposure", "Std. Error"]
    n1[s] <- sum(sub$exposure)
  }
  keep <- is.finite(se) & se > 0
  pooled <- sum(est[keep] * n1[keep]) / sum(n1[keep])
  expect_equal(res$estimate, pooled, tolerance = 1e-10)
})

test_that("estimand is validated and run_pipeline threads it through", {
  d <- simulate_test_cohort()
  covs <- c("age", "diabetes", "hypertension")
  expect_error(fit_outcome(d, "exposure", covs, "outcome", type = "binary",
                           method = "iptw", estimand = "nope"), "should be one of")

  res_att <- suppressWarnings(run_pipeline(d, "exposure", covs, "outcome", type = "binary",
                          methods = c("iptw", "aipw"), estimand = "ATT"))
  res_default <- suppressWarnings(run_pipeline(d, "exposure", covs, "outcome", type = "binary",
                              methods = c("iptw", "aipw")))
  iptw_att <- res_att$comparison[res_att$comparison$method == "iptw", ]
  iptw_default <- res_default$comparison[res_default$comparison$method == "iptw", ]
  expect_false(isTRUE(all.equal(iptw_att$estimate, iptw_default$estimate)))
  expect_equal(iptw_att$method, "iptw")
})
