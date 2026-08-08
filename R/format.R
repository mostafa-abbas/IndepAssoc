.method_display_labels <- c(
  regression = "Regression",
  matching = "Matching",
  stratification = "Stratification",
  iptw = "IPTW",
  aipw = "AIPW"
)

.display_method <- function(method) {
  out <- unname(.method_display_labels[method])
  unknown <- is.na(out)
  if (any(unknown)) {
    out[unknown] <- paste0(toupper(substr(method[unknown], 1, 1)),
                           substring(method[unknown], 2))
  }
  out
}

#' Format a comparison table for publication
#'
#' Converts a raw `comparison` data frame from `run_pipeline()`/`fit_outcome()`
#' (full floating-point precision) into a publication-ready table: `estimate`,
#' `conf_low`, and `conf_high` are rounded to `digits` decimals, the confidence
#' interval is rendered as a single `"low\u2013high"` string (en dash), small
#' p-values are collapsed to `"<0.001"` (or the equivalent threshold for
#' `p_digits`), and the estimate column is labeled by outcome type — `"OR"` for
#' `type == "binary"`, `"Mean Diff"` for `type == "continuous"`.
#'
#' @param comparison A data.frame from `run_pipeline()`'s `$comparison` element
#'   (columns `method`, `type`, `estimate`, `conf_low`, `conf_high`, `p_value`,
#'   and optionally `n`).
#' @param digits Number of decimal places for `estimate`, `conf_low`, and
#'   `conf_high` (default 2).
#' @param p_digits Number of decimal places for `p_value` (default 3); values
#'   below `10^-p_digits` are rendered as `"<0.001"` (etc.).
#'
#' @return A data.frame with columns `Method`, the outcome-appropriate estimate
#'   label (`OR` or `Mean Diff`), `95% CI`, `p-value`, and `n`.
#'
#' @details This is a display-layer helper: it intentionally does **not** alter
#'   the underlying data. `export_results()` writes CSV files at full numeric
#'   precision for downstream reanalysis; publication-style rounding belongs at
#'   the display layer only (printed tables, vignettes), never baked into
#'   exported data.
#'
#' @export
#' @examples
#' data(example_cohort)
#' res <- run_pipeline(
#'   data = example_cohort,
#'   exposure = "exposure",
#'   covariates = c("age", "diabetes", "hypertension", "bmi"),
#'   outcome = "outcome_binary",
#'   type = "binary",
#'   methods = c("regression", "matching", "stratification", "iptw", "aipw")
#' )
#' format_comparison(res$comparison)
format_comparison <- function(comparison, digits = 2, p_digits = 3) {
  if (!is.data.frame(comparison)) stop("`comparison` must be a data.frame.")
  need <- c("method", "type", "estimate", "conf_low", "conf_high", "p_value")
  missing <- setdiff(need, names(comparison))
  if (length(missing) > 0) {
    stop("`comparison` must contain columns: ", paste(need, collapse = ", "))
  }
  if (!is.numeric(digits) || length(digits) != 1 || is.na(digits) || digits < 0) {
    stop("`digits` must be a single non-negative number.")
  }
  if (!is.numeric(p_digits) || length(p_digits) != 1 || is.na(p_digits) || p_digits < 0) {
    stop("`p_digits` must be a single non-negative number.")
  }

  type_label <- vapply(comparison$type, function(t) {
    switch(tolower(t),
      binary = "OR",
      continuous = "Mean Diff",
      stop("Unknown `type` value: ", t, " (expected \"binary\" or \"continuous\").")
    )
  }, character(1))

  fmt_est <- paste0("%.", digits, "f")
  ci <- paste0(sprintf(fmt_est, comparison$conf_low), "\u2013",
               sprintf(fmt_est, comparison$conf_high))

  threshold <- 10^(-p_digits)
  p_out <- ifelse(
    comparison$p_value < threshold,
    paste0("<", sprintf(paste0("%.", p_digits, "f"), threshold)),
    sprintf(paste0("%.", p_digits, "f"), comparison$p_value)
  )

  out <- data.frame(
    Method    = .display_method(comparison$method),
    Estimate  = round(comparison$estimate, digits),
    "95% CI"  = ci,
    "p-value" = p_out,
    n         = if ("n" %in% names(comparison)) comparison$n else NULL,
    check.names = FALSE
  )
  names(out)[2] <- type_label[1]
  out
}

#' Format a combined multi-outcome comparison table for publication
#'
#' @param combined_comparison A data.frame with an `Outcome` column plus the raw
#'   comparison columns (see `format_comparison()`): multiple outcomes'
#'   comparison rows stacked together, each tagged with its outcome label.
#' @inheritParams format_comparison
#'
#' @return A data.frame with columns `Outcome`, `Method`, `Estimate`, `95% CI`,
#'   `p-value`, and `n`. Because the rows may mix binary and continuous
#'   outcomes, the estimate column keeps the generic name `Estimate` — read it
#'   together with the `Outcome` column (an OR for binary outcomes, a mean
#'   difference in the outcome's units for continuous ones).
#' @export
#' @examples
#' data(example_cohort)
#' res <- run_pipeline(
#'   data = example_cohort,
#'   exposure = "exposure",
#'   covariates = c("age", "diabetes", "hypertension", "bmi"),
#'   outcome = "outcome_binary",
#'   type = "binary",
#'   methods = c("regression", "matching", "stratification", "iptw", "aipw")
#' )
#' combined <- rbind(
#'   cbind(Outcome = "30-day mortality", res$comparison),
#'   cbind(Outcome = "Hospital length of stay (days)", res$comparison)
#' )
#' format_combined(combined)
format_combined <- function(combined_comparison, digits = 2, p_digits = 3) {
  if (!is.data.frame(combined_comparison)) {
    stop("`combined_comparison` must be a data.frame.")
  }
  if (!"Outcome" %in% names(combined_comparison)) {
    stop("`combined_comparison` must contain an `Outcome` column.")
  }
  chunks <- lapply(unique(combined_comparison$Outcome), function(oc) {
    idx <- which(combined_comparison$Outcome == oc)
    chunk <- combined_comparison[idx, , drop = FALSE]
    fmt <- format_comparison(chunk, digits = digits, p_digits = p_digits)
    data.frame(
      Outcome   = chunk$Outcome,
      Method    = fmt$Method,
      Estimate  = fmt[[2]],
      "95% CI"  = fmt[["95% CI"]],
      "p-value" = fmt[["p-value"]],
      n         = fmt$n,
      check.names = FALSE
    )
  })
  do.call(rbind, chunks)
}
