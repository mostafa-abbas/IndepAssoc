#' Fit an Outcome Model with a Chosen Confounding-Adjustment Method
#'
#' @param data Data frame containing exposure, covariates, and outcome.
#' @param exposure Character; exposure variable name (binary).
#' @param covariates Character vector of covariate names.
#' @param outcome Character; outcome variable name.
#' @param type Outcome type: `"binary"` or `"continuous"`.
#' @param method One or more of `"regression"`, `"matching"`,
#'   `"stratification"`, `"iptw"`, `"aipw"`. If a vector, returns a list
#'   of results, one per method. `"matching"` is propensity-score matching
#'   with conditional-logit (binary) / within-pair (continuous) estimation.
#' @param ... Passed to the per-method estimators. `seed` is accepted by the
#'   matching method for reproducible matching.
#' @param trim Optional length-1 or length-2 probability vector for weight
#'   trimming, applied to the IPTW and AIPW methods only. Weights are truncated
#'   at the specified percentiles of their distribution (Cole & Hernan 2008,
#'   doi:10.1093/aje/kwn085), so `trim = c(0.01, 0.99)` caps extreme weights
#'   that otherwise inflate variance. Default `NULL` (no trimming, current
#'   behavior preserved exactly). Ignored by `"regression"`, `"matching"`, and
#'   `"stratification"`.
#' @param estimand Causal estimand: `"ATE"` (default) or `"ATT"`. With
#'   `"ATT"`, the propensity-score methods target the average treatment effect
#'   on the treated: `"iptw"` and `"aipw"` use standardized mortality ratio
#'   (SMR) weights, and `"stratification"` pools each stratum's within-stratum
#'   effect with weights proportional to the number of treated units in the
#'   stratum (Austin, 2011, doi:10.1080/00273171.2011.568786). `"matching"`
#'   targets the ATT by construction (1:1 matching without replacement) and
#'   ignores this argument — a silent no-op. `"regression"` reports a
#'   conditional effect and also ignores it.
#'
#' @details `"regression"` adjusts for covariates directly in the outcome
#'   model. `"matching"` is propensity-score matching with conditional-logit
#'   (binary) / within-pair (continuous) estimation. `"stratification"`
#'   stratifies on the propensity score. `"iptw"` is a marginal structural
#'   model: the outcome model regresses on the exposure only, weighted by
#'   stabilized inverse probability of treatment weights (or SMR weights when
#'   `estimand = "ATT"`), with robust sandwich standard errors — confounding
#'   is controlled by the weights alone. `"aipw"` is a doubly-robust augmented
#'   estimator (Bang & Robins) that models both the outcome and the propensity
#'   score. For `method = "matching"`, binary outcomes must be coded as numeric
#'   0/1 (the conditional-logit estimator strata on the matched pair).
#'
#' @references Austin PC. An introduction to propensity score methods for
#'   reducing the effects of confounding in observational studies.
#'   *Multivariate Behavioral Research* 2011;46(3):399-424,
#'   doi:10.1080/00273171.2011.568786. Austin 2011 is the source for the IPTW
#'   SMR weights and the treated-count pooling used by `estimand = "ATT"`.
#'   Lunceford JK, Davidian M. Stratification and weighting via the propensity
#'   score in estimation of causal treatment effects. *Statistics in Medicine*
#'   2004;23(19):2937-2960, doi:10.1002/sim.1903. Lunceford & Davidian (2004)
#'   is the source for the augmented influence-function ATE/ATT derivation used
#'   by AIPW.
#'
#' @return A named list with `method`, `type`, `estimate`, `conf_low`,
#'   `conf_high`, `p_value`, `n`, and `model`. If `method` has length > 1,
#'   a named list of such results.
#'
#' @examples
#' data(example_cohort)
#' res <- fit_outcome(example_cohort, "exposure",
#'                    c("age", "diabetes", "hypertension", "bmi"),
#'                    "outcome_binary", type = "binary",
#'                    method = c("regression", "iptw"))
#' res$regression$estimate
#' res$iptw$estimate
#'
#' @export
fit_outcome <- function(data, exposure, covariates, outcome,
                        type = c("binary", "continuous"),
                        method = c("regression", "matching", "stratification", "iptw", "aipw"),
                        estimand = c("ATE", "ATT"),
                        trim = NULL,
                        ...) {
  type <- match.arg(type)
  estimand <- match.arg(estimand)
  allowed <- c("regression", "matching", "stratification", "iptw", "aipw")
  if (!all(method %in% allowed)) {
    stop("Unknown method '", paste(method[!method %in% allowed], collapse = "', '"),
         "'. `method` should be one of: ", paste(allowed, collapse = ", "))
  }
  methods <- method
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!exposure %in% names(data)) stop(paste("Exposure", exposure, "not found in data."))
  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) stop(paste("Covariates not found:", paste(missing_covs, collapse = ", ")))
  if (!outcome %in% names(data)) stop(paste("Outcome", outcome, "not found."))

  funs <- c(
    regression     = ".fit_regression",
    matching       = ".fit_matching",
    stratification = ".fit_stratification",
    iptw           = ".fit_iptw",
    aipw           = ".fit_aipw"
  )
  res <- lapply(methods, function(m) {
    fn <- get(funs[[m]], mode = "function", envir = environment())
    fn(data = data, exposure = exposure, covariates = covariates,
       outcome = outcome, type = type, estimand = estimand, trim = trim, ...)
  })
  names(res) <- methods
  if (length(methods) == 1) res[[1]] else res
}

.fit_outcome_entry <- function(method, type, estimate, conf_low, conf_high,
                               p_value, n, model) {
  list(
    method    = method,
    type      = type,
    estimate  = estimate,
    conf_low  = conf_low,
    conf_high = conf_high,
    p_value   = p_value,
    n         = n,
    model     = model
  )
}

.fit_matching <- function(data, exposure, covariates, outcome, type,
                          caliper = 0.2, ratio = 1, seed = NULL, ...) {
  drop_cols <- intersect(c("distance", "weights", "subclass"), names(data))
  if (length(drop_cols) > 0) {
    data <- data[, setdiff(names(data), drop_cols), drop = FALSE]
  }
  ps <- build_ps_model(data, exposure, covariates)
  m <- match_cohort(ps, caliper = caliper, ratio = ratio, seed = seed)
  mdata <- .ensure_match_num(m$data)
  if (type == "binary") {
    # Conditional logistic regression stratified by matched pair — the
    # estimator the source papers used. Conditioning on the pair controls for
    # any confounder constant within a pair. Shared with fit_all_models()'s
    # "Conditional logit" model via .fit_conditional_logit().
    mod <- .fit_conditional_logit(mdata, exposure, outcome)
    summ <- model_summ(mod, treatment_feature = exposure, type = "binary")
    estimate <- as.numeric(summ$OR[1])
    ci <- c(as.numeric(summ$lower[1]), as.numeric(summ$upper[1]))
    p_value <- as.numeric(summ$`Pr(>|z|)`[1])
    .fit_outcome_entry("matching", type, estimate, ci[1], ci[2], p_value, nrow(mdata), mod)
  } else {
    # Within-pair fixed-effects linear model on the matched cohort (match_num
    # as a stratifying term). Equivalent to the within estimator used by
    # fit_all_models()'s "Conditional linear regression" (plm, model="within"),
    # but on the original outcome scale. Covariates are omitted because pair
    # fixed effects absorb pair-constant confounding and matching balances the
    # covariates within pairs.
    form <- stats::as.formula(paste(outcome, "~", exposure, "+ factor(match_num)"))
    mod <- stats::lm(form, data = mdata)
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    df <- mod$df.residual
    p_value <- 2 * stats::pt(-abs(est / se), df = df)
    ci <- est + stats::qt(c(0.025, 0.975), df = df) * se
    .fit_outcome_entry("matching", type, est, ci[1], ci[2], p_value, nrow(mdata), mod)
  }
}

.fit_stratification <- function(data, exposure, covariates, outcome, type,
                                n_strata = 5, estimand = c("ATE", "ATT"), ...) {
  estimand <- match.arg(estimand)
  ps <- build_ps_model(data, exposure, covariates)
  q <- stats::quantile(ps$data$.ps, probs = seq(0, 1, length.out = n_strata + 1), na.rm = TRUE)
  q[1] <- -Inf; q[length(q)] <- Inf
  strata <- cut(ps$data$.ps, breaks = q, include.lowest = TRUE, labels = FALSE)
  d <- ps$data
  d$.stratum <- strata

  if (type == "binary") {
    if (estimand == "ATT") {
      # Pool stratum-specific odds ratios with weights proportional to the
      # number of treated units per stratum -- the treated-population analogue
      # of the full-sample CMH pooling below (Austin 2011, citing Imbens 2004).
      # Zero-cell strata get the standard 0.5 continuity correction.
      lo <- se_lo <- rep(NA_real_, n_strata)
      n1 <- rep(0, n_strata)
      for (s in seq_len(n_strata)) {
        sub <- d[d$.stratum == s, ]
        n1[s] <- sum(sub[[exposure]])
        tab <- table(sub[[exposure]], sub[[outcome]])
        if (!all(dim(tab) == c(2, 2))) next
        if (any(tab == 0)) tab <- tab + 0.5
        a <- tab[2, 2]; b <- tab[2, 1]; cc <- tab[1, 2]; dd <- tab[1, 1]
        lo[s] <- log((a * dd) / (b * cc))
        se_lo[s] <- sqrt(1 / a + 1 / b + 1 / cc + 1 / dd)
      }
      keep <- is.finite(lo) & is.finite(se_lo) & n1 > 0
      if (!any(keep)) stop("No stratum produced a valid odds ratio for ATT pooling.")
      w <- n1[keep]
      est <- sum(lo[keep] * w) / sum(w)
      se_pool <- sqrt(sum(w^2 * se_lo[keep]^2)) / sum(w)
      p_value <- 2 * stats::pnorm(-abs(est / se_pool))
      ci <- c(est - stats::qnorm(0.975) * se_pool, est + stats::qnorm(0.975) * se_pool)
      .fit_outcome_entry("stratification", type, exp(est), exp(ci[1]), exp(ci[2]),
                         p_value, nrow(d), NULL)
    } else {
      d$exposure_f <- factor(d[[exposure]], levels = sort(unique(d[[exposure]])))
      d$outcome_f  <- factor(d[[outcome]],  levels = sort(unique(d[[outcome]])))
      tbl <- stats::xtabs(~ d$exposure_f + d$outcome_f + d$.stratum)
      mh <- tryCatch(
        stats::mantelhaen.test(tbl),
        error = function(e) stats::mantelhaen.test(tbl, correct = FALSE)
      )
      .fit_outcome_entry("stratification", type, as.numeric(mh$estimate),
                         mh$conf.int[1], mh$conf.int[2], mh$p.value, nrow(d), NULL)
    }
  } else {
    est_rows <- vapply(unique(d$.stratum), function(s) {
      sub <- d[d$.stratum == s, ]
      m <- stats::lm(stats::as.formula(paste(outcome, "~", exposure)), data = sub)
      se <- summary(m)$coefficients[exposure, "Std. Error"]
      c(est = unname(coef(m)[exposure]), se = se, n1 = sum(sub[[exposure]]))
    }, numeric(3))
    keep <- is.finite(est_rows["se", ]) & est_rows["se", ] > 0
    diffs <- est_rows[, keep, drop = FALSE]
    if (ncol(diffs) == 0) stop("No stratum produced a valid variance for pooling.")
    if (estimand == "ATT") {
      # Weight each stratum's within-stratum effect by the number of treated
      # units in it, so the pooled estimate tracks the treated population
      # (Austin 2011, citing Imbens 2004).
      w <- diffs["n1", ]
      est <- sum(diffs["est", ] * w) / sum(w)
      se_pool <- sqrt(sum(w^2 * diffs["se", ]^2)) / sum(w)
    } else {
      w <- 1 / diffs["se", ]^2
      est <- sum(diffs["est", ] * w) / sum(w)
      se_pool <- sqrt(1 / sum(w))
    }
    p_value <- 2 * stats::pnorm(-abs(est / se_pool))
    ci <- c(est - stats::qnorm(0.975) * se_pool, est + stats::qnorm(0.975) * se_pool)
    .fit_outcome_entry("stratification", type, est, ci[1], ci[2], p_value, nrow(d), NULL)
  }
}

#' Normalize a `trim` specification to a length-2 probability vector.
#' @keywords internal
#' @noRd
.trim_probs <- function(trim) {
  if (length(trim) == 1) trim <- sort(c(trim, 1 - trim))
  if (length(trim) != 2) {
    stop("`trim` must be a length-1 or length-2 vector of probabilities.")
  }
  if (any(trim < 0) || any(trim > 1)) {
    stop("`trim` values must lie in [0, 1].")
  }
  sort(trim)
}

#' Truncate positive weights at percentile quantiles (Cole & Hernan 2008).
#' @keywords internal
#' @noRd
.trim_weights <- function(w, trim) {
  probs <- .trim_probs(trim)
  pos <- w > 0
  if (!any(pos)) return(w)
  q <- stats::quantile(w[pos], probs = probs, names = FALSE)
  w[pos] <- pmin(pmax(w[pos], q[1]), q[2])
  w
}

.fit_iptw <- function(data, exposure, covariates, outcome, type,
                      estimand = c("ATE", "ATT"), trim = NULL, ...) {
  estimand <- match.arg(estimand)
  d <- data
  p_denom_form <- stats::as.formula(paste(exposure, "~", paste(covariates, collapse = " + ")))
  denom <- stats::predict(stats::glm(p_denom_form, data = d, family = stats::binomial), type = "response")
  denom <- pmin(pmax(denom, 1e-6), 1 - 1e-6)
  if (estimand == "ATT") {
    # SMR weights (Austin 2011): treated units weight 1, control units weight
    # the odds of treatment, reweighting the controls to the treated
    # distribution.
    sw <- ifelse(d[[exposure]] == 1, 1, denom / (1 - denom))
  } else {
    num <- mean(d[[exposure]])
    sw <- ifelse(d[[exposure]] == 1, num / denom, (1 - num) / (1 - denom))
  }
  if (!is.null(trim)) sw <- .trim_weights(sw, trim)
  d$.sw <- sw
  form <- stats::as.formula(paste(outcome, "~", exposure))
  if (type == "binary") {
    mod <- stats::glm(form, data = d, family = stats::quasibinomial, weights = d$.sw)
    est <- unname(coef(mod)[exposure])
    se <- sqrt(sandwich::vcovHC(mod, type = "HC0")[exposure, exposure])
    p_value <- 2 * stats::pnorm(-abs(est / se))
    ci <- c(exp(est - stats::qnorm(0.975) * se), exp(est + stats::qnorm(0.975) * se))
    .fit_outcome_entry("iptw", type, exp(est), ci[1], ci[2], p_value, nrow(d), mod)
  } else {
    mod <- stats::lm(form, data = d, weights = d$.sw)
    est <- unname(coef(mod)[exposure])
    se <- sqrt(sandwich::vcovHC(mod, type = "HC0")[exposure, exposure])
    df <- mod$df.residual
    p_value <- 2 * stats::pt(-abs(est / se), df = df)
    ci <- est + stats::qt(c(0.025, 0.975), df = df) * se
    .fit_outcome_entry("iptw", type, est, ci[1], ci[2], p_value, nrow(d), mod)
  }
}

.fit_aipw <- function(data, exposure, covariates, outcome, type,
                      estimand = c("ATE", "ATT"), trim = NULL, ...) {
  estimand <- match.arg(estimand)
  d <- data
  a <- d[[exposure]]

  mu_form <- stats::as.formula(paste(outcome, "~", paste(c(exposure, covariates), collapse = " + ")))
  if (type == "binary") {
    mu_mod <- stats::glm(mu_form, data = d, family = stats::binomial)
  } else {
    mu_mod <- stats::lm(mu_form, data = d)
  }

  ps_form <- stats::as.formula(paste(exposure, "~", paste(covariates, collapse = " + ")))
  ps_mod <- stats::glm(ps_form, data = d, family = stats::binomial)
  p_x <- pmin(pmax(stats::predict(ps_mod, type = "response"), 1e-6), 1 - 1e-6)

  d0 <- d; d0[[exposure]] <- 0
  d1 <- d; d1[[exposure]] <- 1
  if (type == "binary") {
    mu0 <- stats::predict(mu_mod, newdata = d0, type = "response")
    mu1 <- stats::predict(mu_mod, newdata = d1, type = "response")
  } else {
    mu0 <- stats::predict(mu_mod, newdata = d0)
    mu1 <- stats::predict(mu_mod, newdata = d1)
  }

  # Inverse-probability weight vectors per arm, matching the estimator's
  # estimand: stabilized ATE weights or SMR ATT weights. Zero entries mark
  # units not in the arm.
  if (estimand == "ATT") {
    w1 <- a
    w0 <- (1 - a) * p_x / (1 - p_x)
  } else {
    w1 <- a / p_x
    w0 <- (1 - a) / (1 - p_x)
  }
  if (!is.null(trim)) {
    w1 <- .trim_weights(w1, trim)
    w0 <- .trim_weights(w0, trim)
  }

  if (estimand == "ATT") {
    # SMR-weighted augmented estimator (Austin 2011): the treated arm keeps
    # weight 1 and the control arm is reweighted by the odds of treatment,
    # both normalized by the estimated treatment fraction, so the pair targets
    # E[Y(a) | A = 1].
    if1 <- w1 * (d[[outcome]] - mu1) + p_x * mu1
    if0 <- w0 * (d[[outcome]] - mu0) + p_x * mu0
    est1 <- mean(if1) / mean(p_x)
    est0 <- mean(if0) / mean(p_x)
    # Delta-method influence functions that account for the random denominator.
    denom <- mean(p_x)
    if1_if <- (if1 - mean(if1)) / denom - est1 * (p_x - denom) / denom
    if0_if <- (if0 - mean(if0)) / denom - est0 * (p_x - denom) / denom
    if (type == "binary") {
      # Marginal OR from augmented risks; delta-method SE on the log-OR scale
      or <- (est1 / (1 - est1)) / (est0 / (1 - est0))
      if_logor <- if1_if / (est1 * (1 - est1)) - if0_if / (est0 * (1 - est0))
      se <- sqrt(sum((if_logor - mean(if_logor))^2) / (nrow(d) - 1) / nrow(d))
      p_value <- 2 * stats::pnorm(-abs(log(or) / se))
      ci <- c(exp(log(or) - stats::qnorm(0.975) * se), exp(log(or) + stats::qnorm(0.975) * se))
      return(.fit_outcome_entry("aipw", type, or, ci[1], ci[2], p_value, nrow(d), mu_mod))
    } else {
      theta <- est1 - est0
      if_diff <- if1_if - if0_if
      se <- sqrt(sum((if_diff - mean(if_diff))^2) / (nrow(d) - 1) / nrow(d))
      df <- nrow(d) - length(covariates) - 1
      p_value <- 2 * stats::pt(-abs(theta / se), df = df)
      ci <- theta + stats::qt(c(0.025, 0.975), df = df) * se
      return(.fit_outcome_entry("aipw", type, theta, ci[1], ci[2], p_value, nrow(d), mu_mod))
    }
  }

  # Augmented influence functions for E[Y(1)] and E[Y(0)]
  if1 <- w1 * (d[[outcome]] - mu1) + mu1
  if0 <- w0 * (d[[outcome]] - mu0) + mu0
  est1 <- mean(if1)
  est0 <- mean(if0)

  if (type == "binary") {
    # Marginal OR from augmented risks; delta-method SE on the log-OR scale
    or <- (est1 / (1 - est1)) / (est0 / (1 - est0))
    if_logor <- if1 / (est1 * (1 - est1)) - if0 / (est0 * (1 - est0))
    se <- sqrt(sum((if_logor - mean(if_logor))^2) / (nrow(d) - 1) / nrow(d))
    p_value <- 2 * stats::pnorm(-abs(log(or) / se))
    ci <- c(exp(log(or) - stats::qnorm(0.975) * se), exp(log(or) + stats::qnorm(0.975) * se))
    .fit_outcome_entry("aipw", type, or, ci[1], ci[2], p_value, nrow(d), mu_mod)
  } else {
    theta <- est1 - est0
    if_diff <- if1 - if0
    se <- sqrt(sum((if_diff - mean(if_diff))^2) / (nrow(d) - 1) / nrow(d))
    df <- nrow(d) - length(covariates) - 1
    p_value <- 2 * stats::pt(-abs(theta / se), df = df)
    ci <- theta + stats::qt(c(0.025, 0.975), df = df) * se
    .fit_outcome_entry("aipw", type, theta, ci[1], ci[2], p_value, nrow(d), mu_mod)
  }
}

.fit_regression <- function(data, exposure, covariates, outcome, type, ...) {
  pred <- c(exposure, covariates)
  form <- stats::as.formula(paste(outcome, "~", paste(pred, collapse = " + ")))
  if (type == "binary") {
    mod <- stats::glm(form, data = data, family = stats::binomial)
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    z <- est / se
    p_value <- 2 * stats::pnorm(-abs(z))
    ci <- c(exp(est - stats::qnorm(0.975) * se), exp(est + stats::qnorm(0.975) * se))
    .fit_outcome_entry("regression", type, exp(est), ci[1], ci[2], p_value, nrow(data), mod)
  } else {
    mod <- stats::lm(form, data = data)
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    df <- mod$df.residual
    p_value <- 2 * stats::pt(-abs(est / se), df = df)
    ci <- est + stats::qt(c(0.025, 0.975), df = df) * se
    .fit_outcome_entry("regression", type, est, ci[1], ci[2], p_value, nrow(data), mod)
  }
}
