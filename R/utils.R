#' IndepAssoc package-level imports
#'
#' @importFrom stats aggregate as.formula confint glm lm predict quantile wilcox.test
#' @importFrom utils write.csv
#' @importFrom survival clogit coxph
#' @keywords internal
#' @noRd
NULL

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

#' Export pipeline results to CSV files
#'
#' Saves all pipeline outputs to CSV files in the specified directory.
#'
#' @param result An `IndepAssoc` object from `run_pipeline()`.
#' @param output_dir Directory to write CSV files to.
#'
#' @return Invisibly returns the output directory path.
#' @export
export_results <- function(result, output_dir = "output") {
  if (!inherits(result, "IndepAssoc")) stop("`result` must be an IndepAssoc object.")
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  write.csv(result$balance_pre, file.path(output_dir, "balance_check_all.csv"))
  write.csv(result$balance_post, file.path(output_dir, "balance_check_matched.csv"))
  write.csv(result$models$summary_w, file.path(output_dir, paste0(result$outcome_type, "_regression_summary.csv")))
  write.csv(result$stat_test, file.path(output_dir, paste0("stat_test_", result$outcome_type, "_matched.csv")))

  message("Results exported to: ", output_dir)
  invisible(output_dir)
}
