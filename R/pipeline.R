#' Run the IndepAssoc Analysis Pipeline
#'
#' Orchestrates the full pipeline: PS model, matching, balance check,
#' descriptive tables, outcome models (3 types), and statistical tests.
#'
#' @param data Data frame containing the cohort.
#' @param exposure Character string naming the binary exposure variable.
#' @param covariates Character vector of covariate names.
#' @param outcome Character string naming the outcome variable.
#' @param type Outcome type: `"binary"` or `"continuous"`.
#' @param caliper Caliper for matching (default `0.2`).
#' @param ratio Match ratio (default `1`).
#' @param balance_threshold ASMD threshold (default `0.10`).
#' @param methods Character vector of confounding-adjustment methods to run
#'   via `fit_outcome()` (default all five: `"regression"`, `"matching"`,
#'   `"stratification"`, `"iptw"`, `"aipw"`). `"matching"` is propensity-score
#'   matching with conditional-logit (binary) / within-pair (continuous)
#'   estimation; because matching draws on the data, results are reproducible
#'   only when a fixed seed is set before the call. `"iptw"` is a marginal
#'   structural model (outcome regressed on the exposure only, weighted by
#'   stabilized inverse probability weights) and `"aipw"` is a doubly-robust
#'   augmented estimator.
#' @param seed Integer passed to `set.seed()` at the top of the pipeline. A
#'   fixed seed makes the whole run — including the step-2 matching and the
#'   step-9 `"matching"` method — reproducible from a single value. Default
#'   `NULL` (no seeding).
#' @param estimand Causal estimand passed to `fit_outcome()`: `"ATE"` (default;
#'   current behavior) or `"ATT"`. With `"ATT"`, `"iptw"` and `"aipw"` use
#'   standardized mortality ratio (SMR) weights and `"stratification"` weights
#'   each stratum's effect by the number of treated units, so the
#'   propensity-score methods target the average treatment effect on the
#'   treated (Austin 2011, doi:10.1080/00273171.2011.568786). `"matching"`
#'   always targets the ATT by construction and ignores this argument.
#'
#' @details Whenever `"matching"` is among the requested `methods`, a fixed
#'   `seed` is required for reproducible results. Pass the same `seed` value to
#'   `run_pipeline()` rather than setting a seed mid-pipeline, so the step-2
#'   matching and the step-9 `"matching"` method both draw on it.
#'
#' The ASMD balance chart is returned as `result$balance_plot` for you to print
#' or save; `print()` does not render it.
#'
#' @return A list of class `"IndepAssoc"` containing all pipeline results,
#'   including `balance_plot` — the `ggplot` chart of absolute standardized mean
#'   differences (ASMD) for unadjusted vs. matched cohorts, produced by
#'   `plot_asmd_balance()` at the `balance_threshold` used — and `positivity`,
#'   the `IndepPositivity` object from `check_positivity()` (propensity-score
#'   overlap and IPTW weight diagnostics for the requested `estimand`).
#'
#' @examples
#' data(example_cohort)
#' res <- run_pipeline(
#'   data = example_cohort,
#'   exposure = "exposure",
#'   covariates = c("age", "diabetes", "hypertension", "bmi"),
#'   outcome = "outcome_binary",
#'   type = "binary",
#'   methods = c("regression", "matching")
#' )
#' res$comparison
#'
#' @export
run_pipeline <- function(data, exposure, covariates, outcome,
                         type = c("binary", "continuous"),
                         caliper = 0.2, ratio = 1, balance_threshold = 0.10,
                         methods = c("regression", "matching", "stratification", "iptw", "aipw"),
                         seed = NULL,
                         estimand = c("ATE", "ATT")) {
  type <- match.arg(type)
  estimand <- match.arg(estimand)

  if (!is.null(seed)) set.seed(seed)

  message("Step 1/9: Building propensity score model...")
  ps <- build_ps_model(data, exposure, covariates)
  positivity <- check_positivity(ps, estimand = estimand)
  pg <- positivity$ps_by_group
  message(sprintf(
    "  Positivity: PS window [%.3f, %.3f]; control [%.3f, %.3f], treated [%.3f, %.3f]; %d outside window -> %s",
    positivity$threshold[1], positivity$threshold[2],
    pg$min[pg$group == 0], pg$max[pg$group == 0],
    pg$min[pg$group == 1], pg$max[pg$group == 1],
    positivity$ps_violations$n_total,
    if (positivity$violation) "VIOLATED" else "OK"
  ))

  message("Step 2/9: Matching cohorts...")
  matched <- match_cohort(ps, caliper = caliper, ratio = ratio)

  message("Step 3/9: Checking balance...")
  balance <- check_balance(matched, threshold = balance_threshold)

  message("Step 4/9: Generating unmatched descriptive table...")
  tbl_unmatched <- table_unmatched(data, exposure, covariates)

  message("Step 5/9: Generating matched descriptive table...")
  tbl_matched <- table_matched(matched, covariates)

  message("Step 6/9: Fitting all outcome models (3 types)...")
  matched_data <- .ensure_match_num(matched$data)
  all_models <- fit_all_models(ps, matched_data, outcome, type = type)

  message("Step 7/9: Running paired statistical tests...")
  if (type == "binary") {
    stat_test <- mcnemar_test(matched_data, outcome, exposure)
  } else {
    stat_test <- paired_wilcoxon_test(matched_data, outcome, exposure)
  }

  message("Step 8/9: Generating balance table...")
  balance_pre <- as.data.frame(balance$pre$Balance)
  balance_post <- as.data.frame(balance$post$Balance)
  balance_plot <- plot_asmd_balance(
    list(balance_pre = balance_pre, balance_post = balance_post),
    threshold = balance_threshold
  )

  message("Step 9/9: Running requested confounding-adjustment methods...")
  all_fits <- fit_outcome(data = data, exposure = exposure, covariates = covariates,
                          outcome = outcome, type = type, method = methods,
                          estimand = estimand)
  if (length(methods) == 1) all_fits <- setNames(list(all_fits), methods)
  comparison <- do.call(rbind, lapply(names(all_fits), function(m) {
    r <- all_fits[[m]]
    data.frame(method = r$method, label = outcome, type = r$type,
               estimate = r$estimate, conf_low = r$conf_low, conf_high = r$conf_high,
               p_value = r$p_value, n = r$n, stringsAsFactors = FALSE)
  }))

  if (any(c("iptw", "aipw") %in% methods)) {
    w <- positivity$weights
    message(sprintf(
      "  IPTW weights (%s): min %.2f, median %.2f, max %.2f, max/min ratio %.1f",
      w$estimand, w$min, w$median, w$max, w$max_min_ratio
    ))
  }

  message("Pipeline complete.")

  structure(
    list(
      ps_model = ps,
      matched = matched,
      matched_data = matched_data,
      balance = balance,
      balance_pre = balance_pre,
      balance_post = balance_post,
      balance_plot = balance_plot,
      table_unmatched = tbl_unmatched,
      table_matched = tbl_matched,
      models = all_models,
      comparison = comparison,
      stat_test = stat_test,
      outcome_type = type,
      positivity = positivity
    ),
    class = "IndepAssoc"
  )
}

#' Print an IndepAssoc pipeline result
#'
#' @param x An `IndepAssoc` object from `run_pipeline()`.
#' @param ... Additional arguments (ignored).
#'
#' @examples
#' data(example_cohort)
#' res <- run_pipeline(
#'   data = example_cohort,
#'   exposure = "exposure",
#'   covariates = c("age", "diabetes", "hypertension", "bmi"),
#'   outcome = "outcome_binary",
#'   type = "binary",
#'   methods = "regression"
#' )
#' print(res)
#'
#' @export
print.IndepAssoc <- function(x, ...) {
  cat("IndepAssoc Pipeline Result\n")
  cat("==========================\n\n")
  cat("Exposure:", x$ps_model$exposure, "\n")
  cat("Covariates:", paste(x$ps_model$covariates, collapse = ", "), "\n")
  cat("Outcome type:", x$outcome_type, "\n")
  cat("Matched observations:", nrow(x$matched_data), "\n")
  cat("Balance check:", if (x$balance$all_balanced) "PASSED" else "FAILED", "\n\n")
  cat("Model Summary:\n")
  print(x$models$summary_w)
  invisible(x)
}

#' Summary of an IndepAssoc pipeline result
#'
#' @param object An `IndepAssoc` object from `run_pipeline()`.
#' @param ... Additional arguments passed to `print.IndepAssoc()`.
#'
#' @examples
#' data(example_cohort)
#' res <- run_pipeline(
#'   data = example_cohort,
#'   exposure = "exposure",
#'   covariates = c("age", "diabetes", "hypertension", "bmi"),
#'   outcome = "outcome_continuous",
#'   type = "continuous",
#'   methods = "regression"
#' )
#' summary(res)
#'
#' @export
summary.IndepAssoc <- function(object, ...) {
  print.IndepAssoc(object, ...)
}
