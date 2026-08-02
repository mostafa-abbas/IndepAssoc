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
#'   `"stratification"`, `"iptw"`, `"aipw"`).
#'
#' @return A list of class `"IndepAssoc"` containing all pipeline results.
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
                         methods = c("regression", "matching", "stratification", "iptw", "aipw")) {
  type <- match.arg(type)

  message("Step 1/9: Building propensity score model...")
  ps <- build_ps_model(data, exposure, covariates)

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

  message("Step 9/9: Running requested confounding-adjustment methods...")
  all_fits <- fit_outcome(data = data, exposure = exposure, covariates = covariates,
                          outcome = outcome, type = type, method = methods)
  if (length(methods) == 1) all_fits <- setNames(list(all_fits), methods)
  comparison <- do.call(rbind, lapply(names(all_fits), function(m) {
    r <- all_fits[[m]]
    data.frame(method = r$method, label = outcome, type = r$type,
               estimate = r$estimate, conf_low = r$conf_low, conf_high = r$conf_high,
               p_value = r$p_value, n = r$n, stringsAsFactors = FALSE)
  }))

  message("Pipeline complete.")

  structure(
    list(
      ps_model = ps,
      matched = matched,
      matched_data = matched_data,
      balance = balance,
      balance_pre = balance_pre,
      balance_post = balance_post,
      table_unmatched = tbl_unmatched,
      table_matched = tbl_matched,
      models = all_models,
      comparison = comparison,
      stat_test = stat_test,
      outcome_type = type
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
