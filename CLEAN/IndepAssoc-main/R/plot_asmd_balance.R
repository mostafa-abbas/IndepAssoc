# Normalize a matching result object into unadjusted/matched ASMD tables.
#
# Accepts find_matching_data_summary() output (match_summ$all/$matched),
# run_pipeline() output (balance_pre/balance_post), or a check_balance()
# IndepBalance object (pre/post). Returns a list with 'unadjusted' and
# 'matched' data frames, each with 'Variable' (from row names) and 'ASMD'
# (numeric, absolute).
.asmd_tables <- function(matching_res) {
  if (!is.list(matching_res)) {
    stop("Invalid matching result object provided.")
  }

  all_df <- NULL
  matched_df <- NULL

  if (is.list(matching_res$match_summ)) {
    all_df <- matching_res$match_summ$all
    matched_df <- matching_res$match_summ$matched
  } else if (!is.null(matching_res$balance_pre) &&
             !is.null(matching_res$balance_post)) {
    all_df <- matching_res$balance_pre
    matched_df <- matching_res$balance_post
  } else if (!is.null(matching_res$pre) && !is.null(matching_res$post)) {
    all_df <- matching_res$pre$Balance
    matched_df <- matching_res$post$Balance
  }

  if (is.null(all_df) || is.null(matched_df)) {
    stop("Invalid matching result object provided.")
  }

  list(
    unadjusted = .asmd_table(all_df, stage = "unadjusted"),
    matched = .asmd_table(matched_df, stage = "matched")
  )
}

.asmd_table <- function(df, stage) {
  df_df <- as.data.frame(df)
  col <- .asmd_column(df_df, stage)
  data.frame(
    Variable = rownames(df_df),
    ASMD = abs(as.numeric(df_df[[col]])),
    stringsAsFactors = FALSE
  )
}

.asmd_column <- function(df, stage) {
  if ("ASMD" %in% names(df)) return("ASMD")
  if ("Std. Mean Diff." %in% names(df)) return("Std. Mean Diff.")
  if (stage == "unadjusted" && "Diff.Un" %in% names(df)) return("Diff.Un")
  if (stage == "matched" && "Diff.Adj" %in% names(df)) return("Diff.Adj")
  num_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  if (length(num_cols) > 0) return(num_cols[1])
  stop("Invalid matching result object provided.")
}

#' Plot ASMD Balance Across Unmatched and Matched Cohorts
#'
#' Creates a grouped bar chart comparing the absolute standardized mean
#' difference (ASMD) for each covariate before and after matching.
#'
#' @param matching_res A matching result object: the output of
#'   `find_matching_data_summary()`, a `run_pipeline()` result, or an
#'   `IndepBalance` object from `check_balance()`.
#' @param threshold Numeric; balance threshold line (default `0.10`).
#' @param title Character string for the plot title.
#' @param top_n Integer; optional. When set, show only the `top_n` covariates
#'   (or levels of multi-level categorical covariates) with the largest
#'   unadjusted (pre-matching) ASMD, still showing both the unadjusted and
#'   matched bars for each. A caption stating how many of the total are shown
#'   is added. Default `NULL`: show every covariate — current behavior,
#'   unchanged.
#'
#' @return A `ggplot` object.
#'
#' @examples
#' data(example_cohort)
#' res <- find_matching_data_summary(
#'   example_cohort,
#'   "exposure",
#'   c("age", "diabetes", "hypertension", "bmi")
#' )
#' plot_asmd_balance(res)
#' plot_asmd_balance(res, top_n = 10)
#'
#' @export
plot_asmd_balance <- function(matching_res,
                              threshold = 0.10,
                              title = "Absolute Standardized Mean Difference (ASMD) Before and After Matching",
                              top_n = NULL) {
  if (!is.null(top_n)) {
    if (!is.numeric(top_n) || length(top_n) != 1 || is.na(top_n) || top_n < 1) {
      stop("`top_n` must be NULL or a single positive number.")
    }
    top_n <- as.integer(top_n)
  }

  tables <- .asmd_tables(matching_res)

  df_long <- rbind(
    data.frame(tables$unadjusted, Cohort = "Unadjusted", stringsAsFactors = FALSE),
    data.frame(tables$matched, Cohort = "Matched", stringsAsFactors = FALSE)
  )
  df_long <- df_long[
    !df_long$Variable %in% c("distance", "propensity scores", "(Intercept)"),
    , drop = FALSE
  ]

  bad_vars <- setdiff(
    df_long$Variable[is.na(df_long$ASMD)],
    df_long$Variable[!is.na(df_long$ASMD)]
  )
  df_long <- df_long[!df_long$Variable %in% bad_vars, , drop = FALSE]

  if (nrow(df_long) == 0) {
    warning("No valid covariate rows found to plot.")
    df_long <- data.frame(
      Variable = factor(),
      ASMD = numeric(),
      Cohort = factor(character(), levels = c("Unadjusted", "Matched"))
    )
  }

  var_order <- unique(df_long$Variable[df_long$Cohort == "Unadjusted"])
  df_long$Variable <- factor(df_long$Variable, levels = var_order)
  df_long$Cohort <- factor(df_long$Cohort, levels = c("Unadjusted", "Matched"))

  caption <- NULL
  if (!is.null(top_n) && nrow(df_long) > 0 && top_n < length(var_order)) {
    n_total <- length(var_order)
    unadj_asmd <- stats::setNames(
      df_long$ASMD[df_long$Cohort == "Unadjusted"],
      df_long$Variable[df_long$Cohort == "Unadjusted"]
    )
    keep <- names(sort(unadj_asmd, decreasing = TRUE))[seq_len(top_n)]
    df_long <- df_long[df_long$Variable %in% keep, , drop = FALSE]
    df_long$Variable <- factor(df_long$Variable,
                               levels = var_order[var_order %in% keep])
    caption <- sprintf(
      "Showing %d of %d covariates with the largest unadjusted ASMD",
      top_n, n_total
    )
  }

  labs_args <- list(x = NULL, y = "ASMD", title = title)
  if (!is.null(caption)) labs_args$caption <- caption

  ggplot2::ggplot(df_long, ggplot2::aes(x = .data$Variable, y = .data$ASMD, fill = .data$Cohort)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.7) +
    ggplot2::geom_hline(yintercept = threshold, linetype = "dashed", color = "black", linewidth = 0.6) +
    ggplot2::scale_fill_manual(values = c("Unadjusted" = "#005A9C", "Matched" = "#E66101")) +
    ggplot2::scale_y_continuous(
      limits = c(0, max(df_long$ASMD, threshold + 0.10, na.rm = TRUE) * 1.05),
      expand = c(0, 0)
    ) +
    do.call(ggplot2::labs, labs_args) +
    ggplot2::theme_classic(base_size = 11) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1, color = "black"),
      axis.title.y = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(color = "black", face = "bold", size = 11, hjust = 0.5),
      legend.position = "bottom",
      legend.title = ggplot2::element_blank()
    )
}
