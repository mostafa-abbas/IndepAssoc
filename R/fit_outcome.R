#' Fit an Outcome Model with a Chosen Confounding-Adjustment Method
#'
#' @param data Data frame containing exposure, covariates, and outcome.
#' @param exposure Character; exposure variable name (binary).
#' @param covariates Character vector of covariate names.
#' @param outcome Character; outcome variable name.
#' @param type Outcome type: `"binary"` or `"continuous"`.
#' @param method One or more of `"regression"`, `"matching"`,
#'   `"stratification"`, `"iptw"`, `"aipw"`. If a vector, returns a list
#'   of results, one per method.
#' @param ... Passed to the per-method estimators.
#'
#' @return A named list with `method`, `type`, `estimate`, `conf_low`,
#'   `conf_high`, `p_value`, `n`, and `model`. If `method` has length > 1,
#'   a named list of such results.
#' @export
fit_outcome <- function(data, exposure, covariates, outcome,
                        type = c("binary", "continuous"),
                        method = c("regression", "matching", "stratification", "iptw", "aipw"),
                        ...) {
  type <- match.arg(type)
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
       outcome = outcome, type = type, ...)
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
                          caliper = 0.2, ratio = 1, ...) {
  ps <- build_ps_model(data, exposure, covariates)
  m <- match_cohort(ps, caliper = caliper, ratio = ratio)
  mdata <- .ensure_match_num(m$data)
  models <- suppressMessages(fit_all_models(ps, mdata, outcome, type = type))
  mod <- models$models[[1]]  # "Fully adjusted logistic/linear regression"
  if (type == "binary") {
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    z <- est / se
    p_value <- 2 * stats::pnorm(-abs(z))
    ci <- c(exp(est - stats::qnorm(0.975) * se), exp(est + stats::qnorm(0.975) * se))
    estimate <- exp(est)
  } else {
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    df <- mod$df.residual
    p_value <- 2 * stats::pt(-abs(est / se), df = df)
    ci <- est + stats::qt(c(0.025, 0.975), df = df) * se
    estimate <- est
  }
  .fit_outcome_entry("matching", type, estimate, ci[1], ci[2], p_value, nrow(mdata), mod)
}

.fit_stratification <- function(data, exposure, covariates, outcome, type,
                                n_strata = 5, ...) {
  ps <- build_ps_model(data, exposure, covariates)
  q <- stats::quantile(ps$data$.ps, probs = seq(0, 1, length.out = n_strata + 1), na.rm = TRUE)
  q[1] <- -Inf; q[length(q)] <- Inf
  strata <- cut(ps$data$.ps, breaks = q, include.lowest = TRUE, labels = FALSE)
  d <- ps$data
  d$.stratum <- strata

  if (type == "binary") {
    d$exposure_f <- factor(d[[exposure]], levels = sort(unique(d[[exposure]])))
    d$outcome_f  <- factor(d[[outcome]],  levels = sort(unique(d[[outcome]])))
    tbl <- stats::xtabs(~ d$exposure_f + d$outcome_f + d$.stratum)
    mh <- tryCatch(
      stats::mantelhaen.test(tbl),
      error = function(e) stats::mantelhaen.test(tbl, correct = FALSE)
    )
    .fit_outcome_entry("stratification", type, as.numeric(mh$estimate),
                       mh$conf.int[1], mh$conf.int[2], mh$p.value, nrow(d), NULL)
  } else {
    est_rows <- vapply(unique(d$.stratum), function(s) {
      sub <- d[d$.stratum == s, ]
      m <- stats::lm(stats::as.formula(paste(outcome, "~", exposure)), data = sub)
      se <- summary(m)$coefficients[exposure, "Std. Error"]
      c(est = unname(coef(m)[exposure]), se = se)
    }, numeric(2))
    keep <- is.finite(est_rows["se", ]) & est_rows["se", ] > 0
    diffs <- est_rows[, keep, drop = FALSE]
    if (ncol(diffs) == 0) stop("No stratum produced a valid variance for pooling.")
    w <- 1 / diffs["se", ]^2
    est <- sum(diffs["est", ] * w) / sum(w)
    se_pool <- sqrt(1 / sum(w))
    p_value <- 2 * stats::pnorm(-abs(est / se_pool))
    ci <- c(est - stats::qnorm(0.975) * se_pool, est + stats::qnorm(0.975) * se_pool)
    .fit_outcome_entry("stratification", type, est, ci[1], ci[2], p_value, nrow(d), NULL)
  }
}

.fit_iptw <- function(data, exposure, covariates, outcome, type, ...) {
  d <- data
  p_denom_form <- stats::as.formula(paste(exposure, "~", paste(covariates, collapse = " + ")))
  denom <- stats::predict(stats::glm(p_denom_form, data = d, family = stats::binomial), type = "response")
  denom <- pmin(pmax(denom, 1e-6), 1 - 1e-6)
  num <- mean(d[[exposure]])
  sw <- ifelse(d[[exposure]] == 1, num / denom, (1 - num) / (1 - denom))
  d$.sw <- sw
  design <- survey::svydesign(ids = ~1, data = d, weights = ~.sw)
  pred <- c(exposure, covariates)
  form <- stats::as.formula(paste(outcome, "~", paste(pred, collapse = " + ")))
  if (type == "binary") {
    mod <- survey::svyglm(form, design = design, family = stats::quasibinomial)
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    p_value <- 2 * stats::pnorm(-abs(est / se))
    ci <- c(exp(est - stats::qnorm(0.975) * se), exp(est + stats::qnorm(0.975) * se))
    .fit_outcome_entry("iptw", type, exp(est), ci[1], ci[2], p_value, nrow(d), mod)
  } else {
    mod <- survey::svyglm(form, design = design)
    sc <- summary(mod)$coefficients
    est <- unname(coef(mod)[exposure])
    se <- as.numeric(sc[grep(paste0("^", exposure), rownames(sc))[1], "Std. Error"])
    df <- mod$df.residual
    p_value <- 2 * stats::pt(-abs(est / se), df = df)
    ci <- est + stats::qt(c(0.025, 0.975), df = df) * se
    .fit_outcome_entry("iptw", type, est, ci[1], ci[2], p_value, nrow(d), mod)
  }
}

.fit_aipw <- function(data, exposure, covariates, outcome, type, ...) {
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

  # Augmented influence functions for E[Y(1)] and E[Y(0)]
  if1 <- a / p_x * (d[[outcome]] - mu1) + mu1
  if0 <- (1 - a) / (1 - p_x) * (d[[outcome]] - mu0) + mu0
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
