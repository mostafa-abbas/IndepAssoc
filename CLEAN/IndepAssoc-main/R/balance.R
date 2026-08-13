#' Check Covariate Balance After Matching
#'
#' Computes absolute standardized mean differences (ASMD) before and after
#' matching using `cobalt::bal.tab()`.
#'
#' @param match_obj An `IndepMatch` object returned by `match_cohort()`.
#' @param threshold Numeric ASMD threshold for acceptable imbalance. Default `0.10`.
#' @param plot Logical; if `TRUE`, returns a love plot via `cobalt::love.plot()`.
#'
#' @return A list of class `"IndepBalance"` with elements:
#'   \describe{
#'     \item{pre}{ASMD table for unmatched data.}
#'     \item{post}{ASMD table for matched data.}
#'     \item{threshold}{The threshold used.}
#'     \item{all_balanced}{Logical; `TRUE` if all ASMDs < threshold after matching.}
#'   }
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' bal <- check_balance(matched, threshold = 0.10)
#' bal$all_balanced
#'
#' @export
check_balance <- function(match_obj, threshold = 0.10, plot = FALSE) {
  if (!inherits(match_obj, "IndepMatch")) stop("`match_obj` must be an IndepMatch object.")

  m <- match_obj$match_obj

  pre_bal <- cobalt::bal.tab(m, un = TRUE, disp.v = FALSE)
  post_bal <- cobalt::bal.tab(m, un = FALSE, disp.v = FALSE)

  post_stats <- as.data.frame(post_bal$Balance)
  asmd_col <- grep("Diff\\.Adj|Diff\\.Un", names(post_stats), value = TRUE)
  if (length(asmd_col) == 0) asmd_col <- grep("Diff", names(post_stats), value = TRUE)
  if (length(asmd_col) == 0) asmd_col <- names(post_stats)

  all_balanced <- if (length(asmd_col) > 0) {
    vals <- as.numeric(unlist(post_stats[, asmd_col, drop = FALSE]))
    max(abs(vals), na.rm = TRUE) < threshold
  } else {
    NA
  }

  result <- structure(
    list(pre = pre_bal, post = post_bal, threshold = threshold, all_balanced = all_balanced),
    class = "IndepBalance"
  )

  if (plot) {
    cobalt::love.plot(m, thresholds = c(m = threshold), abs = TRUE)
  }

  result
}
