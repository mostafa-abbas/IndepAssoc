#' Forest Plot of Method Comparison Results
#'
#' @param comparison A data.frame from `run_pipeline()`'s `$comparison`
#'   element (columns `method`, `estimate`, `conf_low`, `conf_high`, ...).
#' @param log_scale Logical; `TRUE` (default) plots on the log scale with a
#'   reference line at 1 (binary outcomes, estimates are ORs). `FALSE` plots
#'   on the linear scale with a reference line at 0.
#'
#' @return A `ggplot` object (invisible).
#' @export
#' @examples
#' data(example_cohort)
#' res <- run_pipeline(
#'   data = example_cohort,
#'   exposure = "exposure",
#'   covariates = c("age", "diabetes", "hypertension", "bmi"),
#'   outcome = "outcome_binary",
#'   type = "binary",
#'   methods = c("regression", "iptw")
#' )
#' plot_comparison(res$comparison, log_scale = TRUE)
plot_comparison <- function(comparison, log_scale = TRUE) {
  if (!is.data.frame(comparison)) stop("`comparison` must be a data.frame.")
  need <- c("method", "estimate", "conf_low", "conf_high")
  if (!all(need %in% names(comparison))) {
    stop("`comparison` must contain columns: ", paste(need, collapse = ", "))
  }
  comparison$method <- factor(comparison$method, levels = rev(unique(comparison$method)))
  p <- ggplot2::ggplot(comparison, ggplot2::aes(x = .data$method, y = .data$estimate)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = .data$conf_low, ymax = .data$conf_high), width = 0.2)
  if (log_scale) {
    p <- p + ggplot2::geom_hline(yintercept = 1, linetype = "dashed", color = "grey40") +
      ggplot2::scale_y_log10() +
      ggplot2::ylab("Odds Ratio (log scale)")
  } else {
    p <- p + ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
      ggplot2::ylab("Estimate")
  }
  p <- p +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = NULL, title = "Association Estimate by Method") +
    ggplot2::theme_minimal(base_size = 12)
  print(p)
  invisible(p)
}
