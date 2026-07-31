#' Subgroup Analysis
#'
#' Repeats `fit_outcome()` within each level of a subgroup variable.
#'
#' @param match_obj An `IndepMatch` object from `match_cohort()`.
#' @param outcome Character string naming the outcome variable.
#' @param subgroup_var Character string naming the subgroup variable.
#' @param type Outcome type (`"binary"`, `"continuous"`).
#' @param ... Additional arguments passed to `fit_outcome()`.
#'
#' @return A data frame with one row per subgroup level, containing
#'   subgroup name, n, estimate, CI, and p-value.
#'
#' @export
subgroup_analysis <- function(match_obj, outcome, subgroup_var, type = c("binary", "continuous"), ...) {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")

  data <- match_obj$data
  if (!subgroup_var %in% names(data)) stop(paste("Subgroup variable", subgroup_var, "not found."))
  if (!outcome %in% names(data)) stop(paste("Outcome", outcome, "not found."))

  groups <- unique(data[[subgroup_var]])
  results <- lapply(groups, function(g) {
    sub_data <- data[data[[subgroup_var]] == g, ]
    sub_match <- match_obj
    sub_match$data <- sub_data

    tryCatch({
      res <- fit_outcome(sub_match, outcome = outcome, type = type, ...)
      data.frame(
        subgroup = as.character(g),
        n = nrow(sub_data),
        estimate = res$tidy$estimate[1],
        conf.low = res$tidy$conf.low[1],
        conf.high = res$tidy$conf.high[1],
        p.value = res$tidy$p.value[1],
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      data.frame(
        subgroup = as.character(g),
        n = nrow(sub_data),
        estimate = NA_real_,
        conf.low = NA_real_,
        conf.high = NA_real_,
        p.value = NA_real_,
        stringsAsFactors = FALSE
      )
    })
  })

  do.call(rbind, results)
}
