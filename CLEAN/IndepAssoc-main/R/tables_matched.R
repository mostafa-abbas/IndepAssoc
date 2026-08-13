#' Check a categorical covariate is safe for the paired McNemar test
#'
#' Propensity-score matching can drop a rare level from one exposure arm, so the
#' two arms no longer share the same observed level set; `mcnemar.test()` then
#' fails with "'x' and 'y' must have the same number of levels". A covariate is
#' only safe to pass to `add_p()` when both exposure groups observe the same set
#' of at least 2 non-missing levels.
#' @param x Categorical covariate values in the matched data.
#' @param exposure Binary exposure vector aligned with `x`.
#' @return `TRUE` if the covariate is safe for the paired McNemar test.
#' @keywords internal
#' @noRd
.paired_levels_safe <- function(x, exposure) {
  ok <- !is.na(x)
  spl <- split(x[ok], exposure[ok])
  if (length(spl) < 2) return(FALSE)
  sets <- lapply(spl, function(z) sort(unique(as.character(z))))
  identical(sets[[1]], sets[[2]]) && length(sets[[1]]) >= 2
}

#' Matched Descriptive Table
#'
#' Produces a summary table for matched data using paired tests:
#' McNemar (categorical) or Wilcoxon signed-rank (continuous).
#'
#' @param match_obj An `IndepMatch` object returned by `match_cohort()`.
#' @param covariates Character vector of covariate names.
#'
#' @return A `gtsummary` table object.
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' table_matched(matched, c("age", "diabetes", "hypertension", "bmi"))
#'
#' @export
table_matched <- function(match_obj, covariates) {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")

  data <- match_obj$data
  exposure <- match_obj$ps_model$exposure
  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) {
    stop(paste("Covariates not found:", paste(missing_covs, collapse = ", ")))
  }
  vars <- covariates

  if (length(vars) == 0) stop("No valid covariates found in matched data.")
  if (!"strata" %in% names(data)) {
    stop("Matched data must contain a 'strata' column for paired tests.")
  }

  is_cat <- vapply(data[vars], function(x) {
    is.factor(x) || is.character(x) || length(unique(x[!is.na(x)])) <= 5
  }, logical(1))
  cat_vars <- vars[is_cat]
  cont_vars <- vars[!is_cat]

  tables <- list()

  if (length(cat_vars) > 0) {
    cat_vars_test <- cat_vars[vapply(cat_vars, function(v) {
      .paired_levels_safe(data[[v]], data[[exposure]])
    }, logical(1))]

    tbl_cat <- gtsummary::tbl_summary(
      data, by = tidyselect::all_of(exposure), include = tidyselect::all_of(cat_vars),
      statistic = list(gtsummary::all_categorical() ~ "{n} ({p}%)")
    )
    if (length(cat_vars_test) > 0) {
      tbl_cat <- gtsummary::add_p(tbl_cat, test = list(gtsummary::all_categorical() ~ "mcnemar.test"),
                                  group = "strata", include = tidyselect::all_of(cat_vars_test))
    }
    tables[["cat"]] <- tbl_cat
  }

  if (length(cont_vars) > 0) {
    tbl_cont <- gtsummary::tbl_summary(
      data, by = tidyselect::all_of(exposure), include = tidyselect::all_of(cont_vars),
      statistic = list(gtsummary::all_continuous() ~ "{median} ({p25}, {p75})"),
      digits = gtsummary::all_continuous() ~ 1
    )
    tbl_cont <- gtsummary::add_p(tbl_cont, test = list(gtsummary::all_continuous() ~ "paired.wilcox.test"), group = "strata")
    tables[["cont"]] <- tbl_cont
  }

  if (length(tables) == 1) {
    return(tables[[1]])
  }

  gtsummary::tbl_merge(tables, quiet = TRUE)
}
