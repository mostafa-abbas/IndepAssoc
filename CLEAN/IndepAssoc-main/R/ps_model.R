#' Build Propensity Score Model
#'
#' Fits a logistic regression model predicting exposure from covariates,
#' then appends predicted propensity scores to the data.
#'
#' @param data Data frame containing the cohort. Must have at least 4 rows and
#'   at least 2 units in each exposure arm; a non-fatal warning is emitted when
#'   either arm has fewer than 10 units.
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
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' summary(ps$model)$coefficients
#'
#' @export
build_ps_model <- function(data, exposure, covariates, family = "binomial") {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!exposure %in% names(data)) stop(paste("Exposure", exposure, "not found in data."))
  missing_covs <- setdiff(covariates, names(data))
  if (length(missing_covs) > 0) stop(paste("Covariates not found:", paste(missing_covs, collapse = ", ")))

  if (nrow(data) < 4) {
    stop("`data` must contain at least 4 rows to build a propensity score model.")
  }
  exp <- data[[exposure]]
  if (is.factor(exp)) exp <- exp != levels(exp)[1]
  n_control <- sum(exp == 0, na.rm = TRUE)
  n_treated <- sum(exp == 1, na.rm = TRUE)
  if (n_control == 0) {
    stop("No control units found in the data - cannot build a propensity score model.")
  }
  if (n_treated == 0) {
    stop("No treated units found in the data - cannot build a propensity score model.")
  }
  if (n_treated < 2 || n_control < 2) {
    stop("Each exposure arm must contain at least 2 units to build a propensity score model.")
  }
  if (n_control < 10 || n_treated < 10) {
    small_arms <- c()
    if (n_control < 10) {
      small_arms <- c(small_arms, sprintf("control arm has %d observations", n_control))
    }
    if (n_treated < 10) {
      small_arms <- c(small_arms, sprintf("treated arm has %d observations", n_treated))
    }
    warning(paste0("Propensity score model may be unreliable at this sample size: ",
                   paste(small_arms, collapse = " and "),
                   " (minimum recommended: 10 per arm)."),
            call. = FALSE)
  }

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
