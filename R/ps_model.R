#' Build Propensity Score Model
#'
#' Fits a logistic regression model predicting exposure from covariates,
#' then appends predicted propensity scores to the data.
#'
#' @param data Data frame containing the cohort.
#' @param exposure Character string naming the binary exposure variable.
#' @param covariates Character vector of covariate names to adjust for.
#' @param family GLM family; default `"binomial"` for logistic regression.
#'
#' @return A list of class `"IndepPSModel"` with elements:
#'   \describe{
#'     \item{model}{The fitted `glm` object.}
#'     \item{data}{Data frame with an added `.ps` column (propensity scores).}
#'     \item{exposure}{Name of the exposure variable.}
#'     \item{covariates}{Character vector of covariates used.}
#'   }
#'
#' @export
build_ps_model <- function(data, exposure, covariates, family = "binomial") {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!exposure %in% names(data)) stop(paste("Exposure", exposure, "not found in data."))
  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) stop(paste("Covariates not found:", paste(missing_covs, collapse = ", ")))

  formula_str <- paste(exposure, "~", paste(covariates, collapse = " + "))
  formula <- as.formula(formula_str)

  model <- glm(formula, data = data, family = family)

  data_out <- data
  data_out$.ps <- predict(model, type = "response")

  structure(
    list(model = model, data = data_out, exposure = exposure, covariates = covariates),
    class = "IndepPSModel"
  )
}
