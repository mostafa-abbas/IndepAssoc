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
    tbl_cat <- gtsummary::tbl_summary(
      data, by = tidyselect::all_of(exposure), include = tidyselect::all_of(cat_vars),
      statistic = list(gtsummary::all_categorical() ~ "{n} ({p}%)")
    )
    tbl_cat <- gtsummary::add_p(tbl_cat, test = list(gtsummary::all_categorical() ~ "mcnemar.test"), group = "strata")
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
