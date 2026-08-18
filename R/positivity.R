#' Check Propensity-Score Positivity and IPTW Weight Diagnostics
#'
#' Inspects the propensity-score distribution for the positivity (overlap)
#' assumption and reports the distribution of the inverse-probability weights
#' that `fit_outcome()`'s IPTW method uses. Extreme propensity scores (near 0
#' or 1) or extreme weights are the practical symptom of positivity problems
#' and can produce unstable, high-variance IPTW/AIPW estimates even when
#' covariate balance looks fine on average.
#'
#' @param ps An `IndepPSModel` object returned by `build_ps_model()`.
#' @param threshold Length-2 numeric vector giving the propensity-score support
#'   window. Scores below the first value or above the second are flagged as
#'   positivity violations. Default `c(0.01, 0.99)`.
#' @param estimand Causal estimand whose IPTW weight distribution is reported:
#'   `"ATE"` (default) reports the stabilized inverse-probability weights
#'   `A/ps + (1-A)/(1-ps)`; `"ATT"` reports the standardized mortality ratio
#'   weights `A + (1-A)*ps/(1-ps)`. Both match the weights `fit_outcome()`
#'   actually uses.
#'
#' @return A list of class `"IndepPositivity"` with elements:
#'   \describe{
#'     \item{threshold}{The support window used.}
#'     \item{ps_by_group}{Data frame of propensity-score quantiles by exposure
#'       group, with columns `group`, `n`, `min`, `q25`, `median`, `q75`,
#'       `max`.}
#'     \item{ps_violations}{List with `n_below`, `n_above`, and `n_total` —
#'       counts of units whose propensity score falls outside `threshold`.}
#'     \item{violation}{Logical; `TRUE` if any propensity score falls outside
#'       `threshold`.}
#'     \item{weights}{List describing the IPTW weight distribution for the
#'       requested `estimand`: `estimand`, `n`, `min`, `median`, `max`, and
#'       `max_min_ratio` (largest divided by smallest weight, an
#'       extreme-weight summary).}
#'   }
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' check_positivity(ps)
#'
#' @export
check_positivity <- function(ps, threshold = c(0.01, 0.99),
                             estimand = c("ATE", "ATT")) {
  if (!inherits(ps, "IndepPSModel")) {
    stop("`ps` must be an IndepPSModel object from build_ps_model().")
  }
  if (length(threshold) != 2) {
    stop("`threshold` must be a length-2 numeric vector.")
  }
  if (threshold[1] > threshold[2]) {
    stop(sprintf("`threshold` bounds must be ascending (lower, upper), got %g, %g.",
                 threshold[1], threshold[2]))
  }
  estimand <- match.arg(estimand)

  a <- ps$data[[ps$exposure]]
  if (is.factor(a)) a <- a != levels(a)[1]
  a <- as.numeric(a)
  p <- ps$data$.ps

  group_stats <- do.call(rbind, lapply(c(0, 1), function(g) {
    pg <- p[a == g]
    q <- stats::quantile(pg, probs = c(0, 0.25, 0.5, 0.75, 1), names = FALSE)
    data.frame(group = g, n = length(pg), min = q[1], q25 = q[2],
               median = q[3], q75 = q[4], max = q[5])
  }))
  row.names(group_stats) <- NULL

  n_below <- sum(p < threshold[1], na.rm = TRUE)
  n_above <- sum(p > threshold[2], na.rm = TRUE)

  if (estimand == "ATT") {
    sw <- ifelse(a == 1, 1, p / (1 - p))
  } else {
    num <- mean(a)
    sw <- ifelse(a == 1, num / p, (1 - num) / (1 - p))
  }
  weights <- list(
    estimand = estimand,
    n = length(sw),
    min = min(sw),
    median = stats::median(sw),
    max = max(sw),
    max_min_ratio = max(sw) / min(sw)
  )

  structure(
    list(
      threshold = threshold,
      ps_by_group = group_stats,
      ps_violations = list(
        n_below = n_below,
        n_above = n_above,
        n_total = n_below + n_above
      ),
      violation = (n_below + n_above) > 0,
      weights = weights
    ),
    class = "IndepPositivity"
  )
}

#' Print an IndepPositivity summary
#'
#' @param x An `IndepPositivity` object from `check_positivity()`.
#' @param ... Additional arguments (ignored).
#'
#' @export
print.IndepPositivity <- function(x, ...) {
  g <- x$ps_by_group
  cat("Propensity-score positivity check\n")
  cat("================================\n")
  cat("Support window:", paste(x$threshold, collapse = " to "), "\n")
  for (i in seq_len(nrow(g))) {
    r <- g[i, ]
    cat(sprintf("  exposure %s (n=%d): PS [%.3f, %.3f], median %.3f\n",
                r$group, r$n, r$min, r$max, r$median))
  }
  cat("Positivity:", if (x$violation) "VIOLATED" else "OK",
      sprintf("(%d outside window)\n", x$ps_violations$n_total))
  w <- x$weights
  cat(sprintf("IPTW weights (%s): min %.2f, median %.2f, max %.2f, max/min ratio %.1f\n",
              w$estimand, w$min, w$median, w$max, w$max_min_ratio))

  if (x$violation) {
    cat("\nNote: Some propensity scores fall outside the support window.\n",
        "  IPTW/AIPW estimates for units near the boundary may be unstable.\n",
        "  Consider trimming extreme weights or restricting the sample.\n")
  } else if (w$max_min_ratio > 20) {
    cat("\nNote: The IPTW weight distribution is wide (max/min ratio > 20).\n",
        "  Large weights can inflate variance; consider weight trimming\n",
        "  via the `trim` argument in fit_outcome().\n")
  }
  invisible(x)
}
