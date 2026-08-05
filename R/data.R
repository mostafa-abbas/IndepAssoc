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
#'
#' @examples
#' data(example_cohort)
#' str(example_cohort)
"example_cohort"

#' Cleaned RHC Benchmark Cohort
#'
#' The cleaned Right Heart Catheterization (RHC) cohort from the SUPPORT study,
#' as produced by \code{\link{prepare_rhc_data}}. RHC was associated with harm
#' in the original analysis (Connors et al. 1996); the data are bundled so the
#' validation vignette and tests run offline and deterministically.
#'
#' The raw file's quirks are resolved here: the \code{write.csv} row-names
#' column is dropped, the \code{cat2} category "None" (stored as the literal
#' text \code{"NA"}) is restored, remaining literal \code{"NA"} strings become
#' real missing values, the \code{swang1} exposure and \code{dth30}/\code{death}
#' outcomes are recoded 0/1, and \code{los} is derived from the admission and
#' discharge dates. The heavy-missingness columns \code{adld3p} and
#' \code{urin1} are excluded from the covariate vector.
#'
#' @format A list with two elements:
#' \describe{
#'   \item{data}{A data frame with 5735 rows and 63 columns. \code{swang1} is
#'     the binary exposure (1 = RHC); \code{dth30} is 30-day mortality and
#'     \code{los} is length of stay in days.}
#'   \item{covariates}{A character vector of the 50 confounder column names
#'     used by the adjustment methods.}
#' }
#'
#' @examples
#' data(rhc_sample)
#' str(rhc_sample$data)
#' length(rhc_sample$covariates)
"rhc_sample"
