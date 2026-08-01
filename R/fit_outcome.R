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
