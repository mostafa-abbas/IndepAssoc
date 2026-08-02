#' Check Covariate Balance After Matching
#'
#' Computes absolute standardized mean differences (ASMD) before and after
#' matching using `cobalt::bal.tab()`.
#'
#' @param match_obj An `IndepMatch` object returned by `match_cohort()`.
#' @param threshold Numeric ASMD threshold for acceptable imbalance. Default `0.10`.
#' @param plot Logical; if `TRUE`, returns a love plot via `cobalt::love.plot()`.
#'
#' @return A list of class `"IndepBalance"` with elements:
#'   \describe{
#'     \item{pre}{ASMD table for unmatched data.}
#'     \item{post}{ASMD table for matched data.}
#'     \item{threshold}{The threshold used.}
#'     \item{all_balanced}{Logical; `TRUE` if all ASMDs < threshold after matching.}
#'   }
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' bal <- check_balance(matched, threshold = 0.10)
#' bal$all_balanced
#'
#' @export
check_balance <- function(match_obj, threshold = 0.10, plot = FALSE) {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")

  m <- match_obj$match_obj

  pre_bal <- cobalt::bal.tab(m, un = TRUE, disp.v = FALSE)
  post_bal <- cobalt::bal.tab(m, un = FALSE, disp.v = FALSE)

  post_stats <- as.data.frame(post_bal$Balance)
  asmd_col <- grep("Diff\\.Adj|Diff\\.Un", names(post_stats), value = TRUE)
  if (length(asmd_col) == 0) asmd_col <- grep("Diff", names(post_stats), value = TRUE)
  if (length(asmd_col) == 0) asmd_col <- names(post_stats)

  all_balanced <- if (length(asmd_col) > 0) {
    vals <- as.numeric(unlist(post_stats[, asmd_col, drop = FALSE]))
    max(abs(vals), na.rm = TRUE) < threshold
  } else {
    NA
  }

  result <- structure(
    list(pre = pre_bal, post = post_bal, threshold = threshold, all_balanced = all_balanced),
    class = "IndepBalance"
  )

  if (plot) {
    cobalt::love.plot(m, thresholds = c(m = threshold), abs = TRUE)
  }

  result
}

#' Love Plot: ASMD Before and After Matching
#'
#' Creates a vertical bar chart comparing absolute standardized
#' mean differences (ASMD) for each covariate before and after matching.
#'
#' @param match_obj An `IndepMatch` object from `match_cohort()`.
#' @param threshold Numeric; horizontal threshold line (default `0.10`).
#' @param title Character; plot title.
#' @param unmatched_color Color for unmatched bars (default `"#4472C4"` blue).
#' @param matched_color Color for matched bars (default `"#ED7D31"` orange).
#'
#' @return A `ggplot` object (invisible).
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' plot_love(matched, threshold = 0.10)
#'
#' @export
plot_love <- function(match_obj, threshold = 0.10,
                      title = NULL,
                      unmatched_color = "#4472C4",
                      matched_color = "#ED7D31") {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")

  m <- match_obj$match_obj

  bal <- cobalt::bal.tab(m, un = TRUE, disp.v = FALSE, abs = TRUE, thresholds = c(m = threshold))

  bal_df <- as.data.frame(bal$Balance)
  bal_df$Covariate <- rownames(bal_df)

  un_col <- grep("Diff\\.Un", names(bal_df), value = TRUE)
  ad_col <- grep("Diff\\.Adj", names(bal_df), value = TRUE)
  if (length(un_col) == 0) un_col <- grep("Diff", names(bal_df), value = TRUE)[1]
  if (length(ad_col) == 0) ad_col <- grep("Diff", names(bal_df), value = TRUE)[2]

  unmatched_df <- data.frame(
    Covariate = bal_df$Covariate,
    ASMD = abs(bal_df[[un_col[1]]]),
    Stage = "Unmatched",
    stringsAsFactors = FALSE
  )

  matched_df <- data.frame(
    Covariate = bal_df$Covariate,
    ASMD = abs(bal_df[[ad_col[1]]]),
    Stage = "Matched",
    stringsAsFactors = FALSE
  )

  plot_df <- rbind(unmatched_df, matched_df)
  plot_df$Stage <- factor(plot_df$Stage, levels = c("Unmatched", "Matched"))

  unmatched <- plot_df[plot_df$Stage == "Unmatched", ]
  agg <- tapply(unmatched$ASMD, unmatched$Covariate, max)
  cov_order <- names(agg)[order(-agg)]
  plot_df$Covariate <- factor(plot_df$Covariate, levels = cov_order)

  if (is.null(title)) {
    title <- "Covariate Balance: Unmatched vs Matched Cohorts"
  }

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$Covariate, y = .data$ASMD, fill = .data$Stage)) +
    ggplot2::geom_bar(stat = "identity", position = ggplot2::position_dodge(width = 0.75), width = 0.65) +
    ggplot2::geom_hline(yintercept = threshold, linetype = "dashed", color = "grey40", linewidth = 0.6) +
    ggplot2::scale_fill_manual(values = c("Unmatched" = unmatched_color, "Matched" = matched_color)) +
    ggplot2::labs(
      title = title,
      x = NULL,
      y = "Absolute Standardized Mean Difference",
      fill = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      plot.title = ggplot2::element_text(hjust = 0.5)
    )

  print(p)
  invisible(p)
}
