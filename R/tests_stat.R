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
  if (!"match_num" %in% names(matched_data)) {
    if ("strata" %in% names(matched_data)) {
      matched_data$match_num <- as.numeric(matched_data$strata)
    } else {
      stop("matched_data must contain 'match_num' or 'strata'.")
    }
  }
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
  result$label <- outcome
  result <- result[, c(ncol(result), 1:(ncol(result) - 1))]
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
  if (!"match_num" %in% names(matched_data)) {
    if ("strata" %in% names(matched_data)) {
      matched_data$match_num <- as.numeric(matched_data$strata)
    } else {
      stop("matched_data must contain 'match_num' or 'strata'.")
    }
  }
  if (!outcome %in% names(matched_data)) stop(paste("Outcome", outcome, "not found."))

  matched_data$label <- matched_data[[outcome]]

  wilcox_formula <- as.formula(paste("label ~", exposure))
  test_res <- wilcox.test(wilcox_formula, data = matched_data)

  treatment_vals <- unique(matched_data[[exposure]])
  n_per_group <- sapply(treatment_vals, function(v) sum(matched_data[[exposure]] == v))
  names(treatment_vals) <- paste0(treatment_vals, "(n=", n_per_group, ")")

  summ <- sapply(treatment_vals, function(v) {
    sub <- matched_data[matched_data[[exposure]] == v, ]
    q <- quantile(sub$label)
    paste0(round(q["50%"], 1), "(", round(q["25%"], 1), "-", round(q["75%"], 1), ")")
  })

  summ["p.value"] <- test_res$p.value
  summ <- c(label = outcome, summ)
  as.data.frame(t(summ), stringsAsFactors = FALSE)
}
