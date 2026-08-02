#' Subgroup Analysis
#'
#' Repeats `fit_outcome()` within each level of a subgroup variable.
#'
#' @param match_obj An `IndepMatch` object from `match_cohort()`.
#' @param outcome Character string naming the outcome variable.
#' @param subgroup_var Character string naming the subgroup variable.
#' @param type Outcome type (`"binary"`, `"continuous"`).
#' @param method Confounding-adjustment method, passed to `fit_outcome()`
#'   (default `"regression"`).
#' @param ... Additional arguments passed to `fit_outcome()`.
#'
#' @return A data frame with one row per subgroup level, containing
#'   subgroup name, n, estimate, CI, and p-value.
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' subgroup_analysis(matched, "outcome_binary", "diabetes", type = "binary")
#'
#' @export
subgroup_analysis <- function(match_obj, outcome, subgroup_var, type = c("binary", "continuous"), method = "regression", ...) {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")
  if (length(method) != 1L) {
    stop("`method` must be a single method name; got length ", length(method),
         ". To compare methods, use `fit_outcome()` or `run_pipeline()`.")
  }

  data <- match_obj$data
  if (!subgroup_var %in% names(data)) stop(paste("Subgroup variable", subgroup_var, "not found."))
  if (!outcome %in% names(data)) stop(paste("Outcome", outcome, "not found."))
  type <- match.arg(type)

  if (!subgroup_var %in% match_obj$ps_model$covariates) {
    warning("Subgroup variable '", subgroup_var,
            "' was not part of the covariates used for matching; ",
            "paired tests within subgroups may not be valid.")
  }

  groups <- unique(data[[subgroup_var]])
  results <- lapply(groups, function(g) {
    sub_data <- data[data[[subgroup_var]] == g, ]

    tryCatch({
      res <- fit_outcome(data = sub_data,
                         exposure = match_obj$ps_model$exposure,
                         covariates = match_obj$ps_model$covariates,
                         outcome = outcome, type = type,
                         method = method, ...)
      data.frame(
        subgroup = as.character(g),
        n = nrow(sub_data),
        estimate = res$estimate,
        conf_low = res$conf_low,
        conf_high = res$conf_high,
        p_value = res$p_value,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      data.frame(
        subgroup = as.character(g),
        n = nrow(sub_data),
        estimate = NA_real_,
        conf_low = NA_real_,
        conf_high = NA_real_,
        p_value = NA_real_,
        stringsAsFactors = FALSE
      )
    })
  })

  do.call(rbind, results)
}
