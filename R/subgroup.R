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
#' @details `subgroup_var` is intended to be a categorical variable with a
#'   small number of levels and adequate per-subgroup sample size; continuous
#'   variables should be binned first (e.g. `cut(age, breaks = 4)`). Subgroups
#'   whose model fails to fit (e.g. a degenerate outcome within the subgroup)
#'   return an NA row rather than halting the analysis; when several subgroups
#'   fail, the individual failure messages are consolidated into a single
#'   summary warning naming each affected subgroup (details truncated beyond
#'   the first few).
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
  if (missing(type)) {
    type <- detect_outcome_type(data[[outcome]])
    if (is.null(type)) type <- "binary"
  }
  type <- match.arg(type)

  covariates <- match_obj$ps_model$covariates
  if (subgroup_var %in% covariates) {
    covariates <- setdiff(covariates, subgroup_var)
    message("Subgroup variable '", subgroup_var,
            "' removed from the covariate set for subgroup models because ",
            "it is constant within each subgroup.")
  } else {
    warning("Subgroup variable '", subgroup_var,
            "' was not part of the covariates used for matching; ",
            "paired tests within subgroups may not be valid.")
  }

  groups <- unique(data[[subgroup_var]])
  failures <- list()
  results <- lapply(groups, function(g) {
    sub_data <- data[data[[subgroup_var]] == g, ]

    tryCatch({
      res <- fit_outcome(data = sub_data,
                         exposure = match_obj$ps_model$exposure,
                         covariates = covariates,
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
      failures[[length(failures) + 1L]] <<- list(
        subgroup = as.character(g),
        msg = conditionMessage(e)
      )
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

  if (length(failures) > 0) {
    n_fail <- length(failures)
    detail_n <- min(3L, n_fail)
    details <- vapply(seq_len(detail_n), function(i) {
      sprintf("Subgroup '%s' failed to fit: %s.",
              failures[[i]]$subgroup, sub("\\.$", "", failures[[i]]$msg))
    }, character(1))
    more <- if (n_fail > detail_n) sprintf(" (and %d more)", n_fail - detail_n) else ""
    warning(sprintf("%d of %d subgroups failed to fit and returned NA rows. %s%s",
                    n_fail, length(groups), paste(details, collapse = " "), more),
            call. = FALSE)
  }

  do.call(rbind, results)
}
