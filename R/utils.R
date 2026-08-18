# NOTE: `coxph` is intentionally imported even though never called directly.
# `survival::clogit()` rewrites its call into `coxph()` (`coxcall[[1]] <- as.name("coxph")`)
# and evaluates it in the caller's frame, so `coxph` must be resolvable from this
# package's namespace. Do not remove this import as "stale".

#' IndepAssoc package-level imports
#'
#' @importFrom stats aggregate as.formula confint coef glm lm model.frame predict quantile setNames wilcox.test
#' @importFrom utils write.csv
#' @importFrom survival clogit coxph
#' @importFrom rlang .data
#' @importFrom sandwich vcovHC
#' @keywords internal
#' @noRd
NULL

#' Check for missing values in specified columns
#'
#' Stops with a clear, actionable error if any of the specified columns
#' contain `NA` values.  The message names every column with missingness
#' and instructs the user to handle the NAs before calling the pipeline.
#'
#' @param data Data frame to inspect.
#' @param columns Character vector of column names to check.
#' @param caller Name of the calling function for the error message.
#' @keywords internal
#' @noRd
.check_missing_data <- function(data, columns, caller = deparse(sys.call(sys.frame(0))[[1]])) {
  cols_present <- intersect(columns, names(data))
  cols_absent  <- setdiff(columns, names(data))
  if (length(cols_absent) > 0) {
    stop(sprintf(
      "%s: columns not found in `data`: %s",
      caller, paste(cols_absent, collapse = ", ")
    ))
  }
  na_counts <- vapply(cols_present, function(col) sum(is.na(data[[col]])), integer(1))
  cols_with_na <- cols_present[na_counts > 0]
  if (length(cols_with_na) > 0) {
    details <- vapply(cols_with_na, function(col) {
      sprintf("  `%s`: %d missing value(s) out of %d rows (%.1f%%)",
              col, na_counts[col], nrow(data),
              100 * na_counts[col] / nrow(data))
    }, character(1))
    stop(sprintf(
      "%s: missing values detected in the following columns:\n%s\nPlease remove or impute missing values before calling %s().",
      caller, paste(details, collapse = "\n"), caller
    ))
  }
}

#' Ensure a numeric 'match_num' column exists
#' @keywords internal
#' @noRd
.ensure_match_num <- function(data) {
  if ("match_num" %in% names(data)) return(data)
  if ("strata" %in% names(data)) {
    data$match_num <- as.numeric(data$strata)
    return(data)
  }
  stop("Matched data must contain 'match_num' or 'strata' column.")
}

#' Detect whether an outcome vector is binary (0/1 coded) or continuous.
#'
#' Numeric and logical vectors whose non-missing values are all 0/1 (or
#' TRUE/FALSE) are classified as `"binary"`; any other numeric vector is
#' classified as `"continuous"`. Non-numeric vectors (factor/character) cannot
#' be auto-detected and return `NULL`, leaving the caller's existing default
#' (`"binary"`) in force so historical behavior is preserved.
#' @param y Outcome vector.
#' @return `"binary"`, `"continuous"`, or `NULL`.
#' @keywords internal
#' @noRd
detect_outcome_type <- function(y) {
  if (!is.numeric(y) && !is.logical(y)) return(NULL)
  vals <- unique(y[!is.na(y)])
  if (length(vals) == 0) return(NULL)
  if (all(vals %in% c(0, 1))) "binary" else "continuous"
}

#' Export pipeline results to CSV files
#'
#' Saves all pipeline outputs to CSV files in the specified directory.
#'
#' @param result An `IndepAssoc` object from `run_pipeline()`.
#' @param output_dir Directory to write CSV files to.
#'
#' @return Invisibly returns the output directory path.
#' @export
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
#' out_dir <- tempfile("indepassoc_export_")
#' export_results(res, output_dir = out_dir)
#' list.files(out_dir)
#' unlink(out_dir, recursive = TRUE)
export_results <- function(result, output_dir = "output") {
  if (!inherits(result, "IndepAssoc")) stop("`result` must be an IndepAssoc object.")
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  write.csv(result$balance_pre, file.path(output_dir, "balance_check_all.csv"))
  write.csv(result$balance_post, file.path(output_dir, "balance_check_matched.csv"))
  write.csv(result$models$summary_w, file.path(output_dir, paste0(result$outcome_type, "_regression_summary.csv")))
  write.csv(result$stat_test, file.path(output_dir, paste0("stat_test_", result$outcome_type, "_matched.csv")))
  write.csv(result$comparison, file.path(output_dir, "comparison.csv"), row.names = FALSE)

  message("Results exported to: ", output_dir)
  invisible(output_dir)
}
