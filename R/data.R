#' Simulated Example Cohort
#'
#' A simulated dataset mimicking a retrospective cardiac surgery cohort
#' for demonstrating the `IndepAssoc` pipeline. Contains a binary exposure
#' (e.g., sex), several baseline covariates, a binary outcome, and a
#' continuous outcome.
#'
#' @format A data frame with 500 rows and 7 variables:
#' \describe{
#'   \item{exposure}{Binary exposure (0/1).}
#'   \item{age}{Continuous covariate (years).}
#'   \item{diabetes}{Binary covariate (0/1).}
#'   \item{hypertension}{Binary covariate (0/1).}
#'   \item{bmi}{Continuous covariate (kg/m2).}
#'   \item{outcome_binary}{Binary outcome (0/1).}
#'   \item{outcome_continuous}{Continuous outcome.}
#' }
"example_cohort"
