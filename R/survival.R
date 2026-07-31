#' Kaplan-Meier Survival Curves and Log-Rank Test
#'
#' Fits KM curves by exposure group and performs a log-rank test.
#'
#' @param match_obj An `IndepMatch` object from `match_cohort()`.
#' @param time Character string naming the time-to-event variable.
#' @param event Character string naming the event indicator variable.
#' @param stratify_by_match Logical; if `TRUE`, stratifies the log-rank test
#'   by matched pair (`strata()`).
#'
#' @return A list of class `"IndepKM"` with elements:
#'   \describe{
#'     \item{km_fit}{The fitted `survfit` object.}
#'     \item{logrank}{The `survdiff` object from the log-rank test.}
#'     \item{p_value}{P-value from the log-rank test.}
#'   }
#'
#' @export
km_logrank <- function(match_obj, time, event, stratify_by_match = TRUE) {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")

  data <- match_obj$data
  exposure <- match_obj$ps_model$exposure

  if (!time %in% names(data)) stop(paste("Time variable", time, "not found."))
  if (!event %in% names(data)) stop(paste("Event variable", event, "not found."))

  form <- as.formula(paste("Surv(", time, ",", event, ") ~", exposure))
  km_fit <- survival::survfit(form, data = data)

  if (stratify_by_match && "strata" %in% names(data)) {
    logrank_form <- as.formula(paste("Surv(", time, ",", event, ") ~", exposure, "+ strata(strata)"))
    logrank <- survival::survdiff(logrank_form, data = data)
  } else {
    logrank <- survival::survdiff(form, data = data)
  }

  p_value <- 1 - pchisq(logrank$chisq, df = length(logrank$n) - 1)

  structure(list(km_fit = km_fit, logrank = logrank, p_value = p_value), class = "IndepKM")
}
