#' Unmatched Descriptive Table
#'
#' Produces a summary table of covariates by exposure group using
#' chi-square (categorical) or Wilcoxon rank-sum (continuous) tests.
#'
#' @param data Data frame (unmatched).
#' @param exposure Character string naming the exposure variable.
#' @param covariates Character vector of covariate names.
#'
#' @return A `gtsummary` table object.
#'
#' @export
table_unmatched <- function(data, exposure, covariates) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")

  vars <- intersect(covariates, names(data))
  if (length(vars) == 0) stop("No valid covariates found in data.")

  tbl <- gtsummary::tbl_summary(
    data,
    by = exposure,
    include = vars,
    statistic = list(
      gtsummary::all_categorical() ~ "{n} ({p}%)",
      gtsummary::all_continuous() ~ "{median} ({p25}, {p75})"
    ),
    digits = gtsummary::all_continuous() ~ 1
  )

  tbl <- gtsummary::add_p(
    tbl,
    test = list(
      gtsummary::all_categorical() ~ "chisq.test",
      gtsummary::all_continuous() ~ "wilcox.test"
    )
  )

  tbl
}
