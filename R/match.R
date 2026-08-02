#' Match Cohort Using Propensity Scores
#'
#' Performs propensity score matching via `MatchIt`.
#'
#' @param ps_model An `IndepPSModel` object returned by `build_ps_model()`.
#' @param method Matching method passed to `MatchIt::matchit()`. Default `"nearest"`.
#' @param caliper Caliper width in SD of logit(PS). Default `0.2`.
#' @param ratio Number of control matches per treated unit. Default `1`.
#' @param replace Whether to match with replacement. Default `FALSE`.
#' @param distance PS distance metric. Default `"logit"`.
#'
#' @return A list of class `"IndepMatch"` with elements:
#'   \describe{
#'     \item{match_obj}{The `MatchIt` match object.}
#'     \item{data}{Matched data frame.}
#'     \item{ps_model}{The input `IndepPSModel` object.}
#'   }
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps, caliper = 0.2, ratio = 1)
#' head(matched$data)
#'
#' @export
match_cohort <- function(ps_model, method = "nearest", caliper = 0.2,
                         ratio = 1, replace = FALSE, distance = "logit") {
  if (!inherits(ps_model, "IndepPSModel")) stop("`ps_model` must be an IndepPSModel object.")

  data <- ps_model$data
  exposure <- ps_model$exposure

  formula_str <- paste(exposure, "~", paste(ps_model$covariates, collapse = " + "))
  formula <- as.formula(formula_str)

  m <- MatchIt::matchit(
    formula,
    data = data,
    method = method,
    distance = data$.ps,
    caliper = caliper,
    ratio = ratio,
    replace = replace
  )

  matched_data <- MatchIt::match.data(m)

  if ("subclass" %in% names(matched_data) && !"strata" %in% names(matched_data)) {
    matched_data$strata <- matched_data$subclass
  }
  matched_data <- .ensure_match_num(matched_data)

  structure(
    list(match_obj = m, data = matched_data, ps_model = ps_model),
    class = "IndepMatch"
  )
}
