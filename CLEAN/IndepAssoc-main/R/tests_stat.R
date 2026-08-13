#' McNemar Test on Matched Data
#'
#' Tests for association between a binary `exposure` and a binary `outcome`
#' within matched strata, using the Cochran-Mantel-Haenszel test
#' (`stats::mantelhaen.test()`) over the per-stratum 2x2 tables. For 1:1
#' matching this is equivalent to McNemar's test; it generalizes naturally to
#' many:1 (ratio > 1) matching, where each stratum may hold several control
#' units.
#'
#' @param matched_data Matched data frame with `match_num` column.
#' @param outcome Character; binary outcome variable name, coded 0/1.
#' @param exposure Character; binary exposure variable name.
#'
#' @details Strata (pairs) with no observed outcome on any member cannot
#'   contribute to the test and are dropped; the number dropped is reported via
#'   a `message()`. Rows with a missing outcome within otherwise-usable strata
#'   are excluded from that stratum's table and also counted in the message.
#'   If the resulting table is degenerate (e.g. a constant outcome), the test
#'   degrades to an `NA` row with a warning rather than halting the pipeline.
#'
#' @return A data frame with McNemar test results.
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' mcnemar_test(matched$data, "outcome_binary", "exposure")
#'
#' @export
mcnemar_test <- function(matched_data, outcome, exposure) {
  matched_data <- .ensure_match_num(matched_data)
  if (!outcome %in% names(matched_data)) stop(paste("Outcome", outcome, "not found."))
  if (!exposure %in% names(matched_data)) stop(paste("Exposure", exposure, "not found."))

  y <- suppressWarnings(as.numeric(as.character(matched_data[[outcome]])))
  if (any(!is.na(matched_data[[outcome]]) & is.na(y)) ||
      any(!is.na(y) & !(y %in% c(0, 1)))) {
    stop("Outcome '", outcome, "' must be binary coded as 0/1 for the McNemar test.")
  }

  grp_vals <- unique(matched_data[[exposure]])
  if (length(grp_vals) != 2) {
    stop("McNemar test requires a binary exposure; found ", length(grp_vals),
         " levels.")
  }

  strat_ids <- sort(unique(matched_data$match_num))
  tabs <- array(0L, dim = c(2, 2, length(strat_ids)),
                dimnames = list(outcome = c("0", "1"),
                                exposure = as.character(grp_vals),
                                stratum = as.character(strat_ids)))
  usable <- logical(length(strat_ids))
  n_missing_rows <- 0L
  for (i in seq_along(strat_ids)) {
    sub <- matched_data[matched_data$match_num == strat_ids[i], ]
    ysub <- y[matched_data$match_num == strat_ids[i]]
    obs <- !is.na(ysub)
    n_missing_rows <- n_missing_rows + sum(!obs)
    if (any(obs)) {
      tabs[, , i] <- table(factor(ysub[obs], levels = 0:1),
                           factor(sub[[exposure]][obs], levels = grp_vals))
      usable[i] <- TRUE
    }
  }
  tabs <- tabs[, , usable, drop = FALSE]
  n_dropped_pairs <- sum(!usable)
  if (n_dropped_pairs > 0 || n_missing_rows > 0) {
    message("McNemar test: dropped ", n_dropped_pairs,
            " incomplete pair(s) (stratum with no observed outcome) and ",
            "excluded ", n_missing_rows, " row(s) with a missing outcome on '",
            outcome, "' from the test.")
  }

  test_res <- tryCatch(
    {
      if (dim(tabs)[3] < 2) {
        stop("fewer than 2 usable strata")
      }
      mh <- stats::mantelhaen.test(tabs)
      if (is.na(mh$p.value) || !is.finite(mh$statistic)) {
        stop("non-finite Mantel-Haenszel statistic (degenerate outcome)")
      }
      data.frame(statistic = as.numeric(mh$statistic),
                 p = as.numeric(mh$p.value),
                 stringsAsFactors = FALSE)
    },
    error = function(e) {
      warning("McNemar test failed to fit: ", conditionMessage(e), call. = FALSE)
      data.frame(statistic = NA_real_, p = NA_real_, stringsAsFactors = FALSE)
    }
  )

  n_per_group <- sapply(grp_vals, function(v) sum(matched_data[[exposure]] == v))
  names(grp_vals) <- paste0(grp_vals, "(n=", n_per_group, ")")

  ratio <- sapply(grp_vals, function(v) {
    sub <- matched_data[matched_data[[exposure]] == v, ]
    ysub <- y[matched_data[[exposure]] == v]
    n_pos <- sum(ysub == 1, na.rm = TRUE)
    n_obs <- sum(!is.na(ysub))
    pct <- round(n_pos / n_obs * 100, 1)
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
#' Paired signed-rank test comparing a continuous `outcome` between the two
#' levels of `exposure` within matched strata. For 1:1 matching each stratum
#' contributes its treated and control value directly; for many:1 (ratio > 1)
#' matching the outcome is first averaged over the multiple controls within
#' each stratum, so every matched row contributes to the test.
#'
#' @param matched_data Matched data frame with `match_num` column.
#' @param outcome Character; continuous outcome variable name.
#' @param exposure Character; binary exposure variable name.
#'
#' @details Strata (pairs) missing an observed outcome on either side of the
#'   pair cannot contribute to the paired comparison and are dropped; the
#'   number dropped is reported via a `message()`. Descriptive quantiles are
#'   computed with `na.rm = TRUE`.
#'
#' @return A data frame with Wilcoxon test results.
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' paired_wilcoxon_test(matched$data, "outcome_continuous", "exposure")
#'
#' @export
paired_wilcoxon_test <- function(matched_data, outcome, exposure) {
  matched_data <- .ensure_match_num(matched_data)
  if (!outcome %in% names(matched_data)) stop(paste("Outcome", outcome, "not found."))
  if (!exposure %in% names(matched_data)) stop(paste("Exposure", exposure, "not found."))

  grp_vals <- unique(matched_data[[exposure]])
  if (length(grp_vals) != 2) {
    stop("Paired Wilcoxon test requires a binary exposure; found ",
         length(grp_vals), " levels.")
  }

  strat_ids <- sort(unique(matched_data$match_num))
  v1 <- v2 <- rep(NA_real_, length(strat_ids))
  ok <- rep(FALSE, length(strat_ids))
  for (i in seq_along(strat_ids)) {
    sub <- matched_data[matched_data$match_num == strat_ids[i], ]
    g1 <- sub[[outcome]][sub[[exposure]] == grp_vals[1]]
    g2 <- sub[[outcome]][sub[[exposure]] == grp_vals[2]]
    ok1 <- length(g1) > 0 && any(!is.na(g1))
    ok2 <- length(g2) > 0 && any(!is.na(g2))
    ok[i] <- ok1 && ok2
    if (ok1) v1[i] <- mean(g1, na.rm = TRUE)
    if (ok2) v2[i] <- mean(g2, na.rm = TRUE)
  }

  n_incomplete <- sum(!ok)
  if (n_incomplete > 0) {
    message("Dropped ", n_incomplete, " incomplete pair(s) (stratum missing an ",
            "observed outcome on one or both sides of the pair) from the ",
            "paired comparison of '", outcome, "'.")
  }

  v1 <- v1[ok]
  v2 <- v2[ok]
  if (length(v1) < 2) {
    stop("Not enough complete pairs (", length(v1), ") to run the paired ",
         "Wilcoxon test on '", outcome, "'.")
  }
  test_res <- wilcox.test(v1, v2, paired = TRUE)

  n_per_group <- sapply(grp_vals, function(v) sum(matched_data[[exposure]] == v))
  summ <- sapply(grp_vals, function(v) {
    sub <- matched_data[matched_data[[exposure]] == v, ]
    q <- quantile(sub[[outcome]], na.rm = TRUE)
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
  summ_df[, c("label", utils::tail(names(summ_df), length(grp_vals)), "statistic", "p.value"), drop = FALSE]
}
