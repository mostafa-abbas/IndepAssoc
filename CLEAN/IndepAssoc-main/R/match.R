# `match_cohort()` rejects `replace = TRUE` up front (see the guard inside the
# function): `MatchIt::match.data()` does not return a match-pair identifier for
# matching with replacement, which every downstream paired function requires.
# Use `find_matching_data_summary()` for replacement matching instead — it
# supports `replace`/`ratio > 1` on its own terms.

#' Match Cohort Using Propensity Scores
#'
#' Performs propensity score matching via `MatchIt`.
#'
#' @param ps_model An `IndepPSModel` object returned by `build_ps_model()`.
#' @param method Matching method passed to `MatchIt::matchit()`. Default `"nearest"`.
#' @param caliper Caliper width in SD of logit(PS). Default `0.2`.
#' @param ratio Number of control matches per treated unit. Default `1`.
#' @param replace Whether to match with replacement. Only `FALSE` is supported;
#'   `TRUE` errors immediately (see Details). Default `FALSE`.
#' @param distance PS distance metric. Default `"logit"`.
#' @param seed Integer passed to `set.seed()` before matching; required for
#'   reproducible matching when tie-breaking or MatchIt internals consume
#'   randomness. Default `NULL` (no seeding).
#'
#' @details
#' `replace = TRUE` is not supported: matching with replacement produces no
#' match-pair identifier from `MatchIt::match.data()`, which the paired
#' downstream functions (balance tables, paired tests, and the conditional-logit
#' matching estimator) all require. Pass `replace = FALSE` (the default), or use
#' `find_matching_data_summary()` when replacement matching is needed.
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
                         ratio = 1, replace = FALSE, distance = "logit",
                         seed = NULL) {
  if (!inherits(ps_model, "IndepPSModel")) stop("`ps_model` must be an IndepPSModel object.")

  if (isTRUE(any(caliper < 0))) {
    stop(sprintf("`caliper` must be non-negative, not %g.", min(caliper, na.rm = TRUE)))
  }

  if (isTRUE(replace)) {
    stop(
      "match_cohort() does not support replace = TRUE: ",
      "MatchIt::match.data() does not return a match-pair identifier for ",
      "matching with replacement, which every downstream paired function ",
      "(balance tables, paired tests, conditional-logit matching estimator) ",
      "requires. Use find_matching_data_summary() if you need matching with ",
      "replacement, or file a request to extend match_cohort() to support it ",
      "end-to-end."
    )
  }

  data <- ps_model$data
  exposure <- ps_model$exposure

  formula_str <- paste(exposure, "~", paste(ps_model$covariates, collapse = " + "))
  formula <- as.formula(formula_str)

  if (!is.null(seed)) set.seed(seed)

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

#' Summarize Balance Before and After Propensity Score Matching
#'
#' Fits a propensity score model with `MatchIt::matchit()` and returns the
#' standardized balance summary tables for the full (unmatched) and matched
#' samples, mirroring the structure produced by the standalone PSM analysis
#' scripts (`match_summ$all`, `match_summ$matched`).
#'
#' @param data Data frame containing the cohort.
#' @param exposure Character; binary exposure variable name.
#' @param covariates Character vector of covariate names.
#' @param caliper Caliper width passed to `MatchIt::matchit()`. Default `0.20`.
#' @param ... Additional arguments passed to `MatchIt::matchit()`
#'   (e.g. `method`, `ratio`, `replace`). `ratio > 1` (multiple control units
#'   per treated unit) is supported.
#'
#' @details
#' For `ratio > 1`, `Data_matched` retains one row per treated/control pair:
#' each treated unit appears once for every one of its matched controls, and
#' every row carries the `match_num` of its pair. `Data_all` keeps one row per
#' unit, so a treated unit matched to several controls carries the `match_num`
#' of its first pair there. When `replace = TRUE`, a control unit reused across
#' multiple pairs appears once per reuse in `Data_matched`, but can carry only
#' a single `match_num` in `Data_all` (the first pair that matched it wins).
#'
#' @return A list with:
#'   \describe{
#'     \item{match_summ}{List with `all` and `matched` data frames from
#'       `summary(matchit(...), standardize = TRUE)`; covariate names are the
#'       row names and each table carries a `Std. Mean Diff.` column.}
#'     \item{Data_all}{The input data frame with a `match_num` column added
#'       (all `NA` for units outside the matched sample).}
#'     \item{Data_matched}{The matched subset with a `match_num` column.}
#'   }
#'
#' @examples
#' data(example_cohort)
#' res <- find_matching_data_summary(
#'   example_cohort,
#'   "exposure",
#'   c("age", "diabetes", "hypertension", "bmi")
#' )
#' head(res$match_summ$all)
#'
#' @export
find_matching_data_summary <- function(data, exposure, covariates,
                                       caliper = 0.20, ...) {
  formula <- stats::as.formula(
    paste(exposure, "~", paste(covariates, collapse = " + "))
  )
  m <- MatchIt::matchit(formula, data = data, caliper = caliper, ...)
  s <- base::summary(m, standardize = TRUE)

  match_summ_all <- as.data.frame(s$sum.all)
  match_summ_matched <- as.data.frame(s$sum.matched)

  b <- as.data.frame(m$match.matrix)
  slot_cols <- names(b)
  b$treated_unit <- rownames(b)
  long <- stats::reshape(
    b, direction = "long",
    varying = slot_cols,
    v.names = "matched_unit",
    timevar = "slot",
    idvar = "treated_unit"
  )
  long$matched_unit <- as.character(long$matched_unit)
  long$treated_unit <- as.character(long$treated_unit)
  pairs <- long[!is.na(long$matched_unit),
                c("treated_unit", "matched_unit"), drop = FALSE]
  pairs$match_num <- seq_len(nrow(pairs))

  treated_rows <- data[pairs$treated_unit, , drop = FALSE]
  treated_rows$match_num <- pairs$match_num
  control_rows <- data[pairs$matched_unit, , drop = FALSE]
  control_rows$match_num <- pairs$match_num
  m_data <- rbind(treated_rows, control_rows)
  m_data <- m_data[order(m_data$match_num), ]
  rownames(m_data) <- NULL

  data$match_num <- NA
  treated_first <- pairs[!duplicated(pairs$treated_unit), ]
  control_first <- pairs[!duplicated(pairs$matched_unit), ]
  data[treated_first$treated_unit, "match_num"] <- treated_first$match_num
  data[control_first$matched_unit, "match_num"] <- control_first$match_num

  list(
    match_summ = list(all = match_summ_all, matched = match_summ_matched),
    Data_all = data,
    Data_matched = m_data
  )
}
