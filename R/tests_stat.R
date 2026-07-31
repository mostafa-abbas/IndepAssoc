#' McNemar Test on Matched Data
#'
#' @param matched_data Matched data frame with `match_num` column.
#' @param outcome Character; binary outcome variable name.
#' @param exposure Character; exposure variable name.
#'
#' @return A data frame with McNemar test results.
#'
#' @export
mcnemar_test <- function(matched_data, outcome, exposure) {
  matched_data <- .ensure_match_num(matched_data)
  if (!outcome %in% names(matched_data)) stop(paste("Outcome", outcome, "not found."))

  matched_data$label <- as.character(matched_data[[outcome]])

  mcnemar_formula <- as.formula(paste("label ~", exposure, "| match_num"))
  test_res <- rstatix::pairwise_mcnemar_test(matched_data, mcnemar_formula)

  treatment_vals <- unique(matched_data[[exposure]])
  n_per_group <- sapply(treatment_vals, function(v) sum(matched_data[[exposure]] == v))
  names(treatment_vals) <- paste0(treatment_vals, "(n=", n_per_group, ")")

  ratio <- sapply(treatment_vals, function(v) {
    sub <- matched_data[matched_data[[exposure]] == v, ]
    n_pos <- sum(sub$label == "1")
    pct <- round(n_pos / nrow(sub) * 100, 1)
    paste0(n_pos, "(", pct, "%)")
  })

  ratio_df <- as.data.frame(t(ratio))
  result <- cbind(ratio_df, test_res)
  result$p.value <- as.numeric(result$p)
  result$label <- outcome
  result <- result[, c(ncol(result), 1:(ncol(result) - 1))]
  stat_pos <- which(names(result) == "statistic")
  result <- result[, c(names(result)[1:stat_pos], "p.value",
                       setdiff(names(result), c(names(result)[1:stat_pos], "p.value")))]
  result
}

#' Paired Wilcoxon Test on Matched Data
#'
#' @param matched_data Matched data frame with `match_num` column.
#' @param outcome Character; continuous outcome variable name.
#' @param exposure Character; exposure variable name.
#'
#' @return A data frame with Wilcoxon test results.
#'
#' @export
paired_wilcoxon_test <- function(matched_data, outcome, exposure) {
  matched_data <- .ensure_match_num(matched_data)
  if (!outcome %in% names(matched_data)) stop(paste("Outcome", outcome, "not found."))

  grp_vals <- unique(matched_data[[exposure]])
  g1 <- matched_data[matched_data[[exposure]] == grp_vals[1], ]
  g2 <- matched_data[matched_data[[exposure]] == grp_vals[2], ]
  common <- intersect(g1$match_num, g2$match_num)
  v1 <- g1[[outcome]][match(common, g1$match_num)]
  v2 <- g2[[outcome]][match(common, g2$match_num)]
  test_res <- wilcox.test(v1, v2, paired = TRUE)

  n_per_group <- sapply(grp_vals, function(v) sum(matched_data[[exposure]] == v))
  summ <- sapply(grp_vals, function(v) {
    sub <- matched_data[matched_data[[exposure]] == v, ]
    q <- quantile(sub[[outcome]])
    paste0(round(q["50%"], 1), "(", round(q["25%"], 1), "-", round(q["75%"], 1), ")")
  })

  summ_df <- data.frame(
    label = outcome,
    statistic = as.numeric(test_res$statistic),
    p.value = as.numeric(test_res$p.value),
    stringsAsFactors = FALSE
  )
  for (i in seq_along(grp_vals)) {
    nm <- paste0(grp_vals[i], "(n=", n_per_group[i], ")")
    summ_df[[nm]] <- summ[i]
  }
  summ_df[, c("label", tail(names(summ_df), length(grp_vals)), "statistic", "p.value"), drop = FALSE]
}
