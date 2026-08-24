## test_issues_1_2.R
##
## Regression-check script for two open IndepAssoc issues:
##   #1  subgroup_analysis() emits ~175 near-identical warnings when
##       splitting by a continuous covariate (age) with many degenerate
##       (zero-variance-outcome) subgroups.
##   #2  fit_outcome(..., type = "continuous") silently returns
##       estimate = 0, CI = [0, 0] on a zero-variance continuous outcome,
##       instead of erroring, for method = regression / iptw / aipw.
##
## HOW TO RUN
##   Put this file at the root of your local IndepAssoc checkout (the
##   folder containing DESCRIPTION) and run:
##       Rscript test_issues_1_2.R
##   or source() it from an R session with that folder as the working
##   directory.
##
## NOTE ON ASSUMPTIONS
## I could not browse github.com/mostafa-abbas/IndepAssoc/R directly
## (GitHub's robots.txt blocks automated fetches of that path), so the
## calls below are built strictly from the signatures given in the two
## issue writeups and the README example (match_cohort(..., seed = N),
## subgroup_analysis(m, "outcome", "age"), fit_outcome(..., type =
## "continuous")). The "Detected signatures" block below will print NOT
## FOUND or a mismatched arg list immediately if something differs in
## your actual source -- fix the corresponding call further down rather
## than trusting the results if that happens.

suppressPackageStartupMessages({
  if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
})

devtools::load_all(".", quiet = TRUE)

## ---------------------------------------------------------------------
## 0. Sanity-check that the functions we need exist with the shape we
##    expect, before relying on them below.
## ---------------------------------------------------------------------
cat("======================================================\n")
cat("Detected function signatures (verify before trusting results)\n")
cat("======================================================\n")
for (fn in c("simulate_test_cohort", "match_cohort", "subgroup_analysis", "fit_outcome")) {
  if (exists(fn, mode = "function")) {
    cat(fn, ":", paste(deparse(args(get(fn))), collapse = " "), "\n")
  } else {
    cat(fn, ": NOT FOUND\n")
  }
}
cat("\n")

## simulate_test_cohort() is referenced in the issue text but may only
## live in the test suite rather than being exported. Try to find it.
if (!exists("simulate_test_cohort", mode = "function")) {
  helper_files <- list.files("tests/testthat", pattern = "^helper.*\\.R$", full.names = TRUE)
  for (f in helper_files) sys.source(f, envir = globalenv())
}
if (!exists("simulate_test_cohort", mode = "function")) {
  stop(
    "Could not find simulate_test_cohort(). It may be defined under a ",
    "different helper filename in tests/testthat/, or you'll need to swap ",
    "in your own cohort with a continuous 'age' covariate and binary ",
    "'outcome' column (e.g. based on example_cohort)."
  )
}

## ---------------------------------------------------------------------
## ISSUE #1: warning volume from subgroup_analysis() on a continuous
##           subgroup variable (age, ~200 unique values -> ~175 singleton
##           zero-variance subgroups).
## ---------------------------------------------------------------------
cat("======================================================\n")
cat("ISSUE #1: subgroup_analysis() warning volume on 'age'\n")
cat("======================================================\n")

set.seed(1)
cohort <- simulate_test_cohort()

m <- match_cohort(
  data       = cohort,
  exposure   = "exposure",
  covariates = setdiff(names(cohort), c("exposure", "outcome")),
  seed       = 1
)

warn_count    <- 0L
warn_messages <- character(0)

res1 <- withCallingHandlers(
  subgroup_analysis(m, "outcome", "age"),
  warning = function(w) {
    if (grepl("failed to fit", conditionMessage(w), fixed = TRUE)) {
      warn_count    <<- warn_count + 1L
      warn_messages <<- c(warn_messages, conditionMessage(w))
    }
    invokeRestart("muffleWarning")
  }
)

cat(sprintf("Number of 'failed to fit' warnings emitted: %d\n", warn_count))
if (warn_count > 0) cat("First warning text:\n  ", warn_messages[1], "\n")
if (!is.null(res1$estimate)) {
  cat(sprintf("Number of NA rows returned: %d\n", sum(is.na(res1$estimate))))
}

cat("\nVerdict: ")
if (warn_count > 1) {
  cat(sprintf(
    "ISSUE #1 STILL REPRODUCES (%d separate warnings). Keep the issue open\n",
    warn_count
  ))
  cat("unless/until the warnings are collapsed into one summary warning.\n")
} else if (warn_count == 1) {
  cat("ISSUE #1 LOOKS FIXED -- only a single (collapsed) warning was seen.\n")
} else {
  cat("No 'failed to fit' warnings were emitted at all -- double check that\n")
  cat("this simulated cohort still produces degenerate age subgroups.\n")
}

## ---------------------------------------------------------------------
## ISSUE #2: fit_outcome(..., type = "continuous") on a zero-variance
##           outcome should error clearly instead of silently returning
##           estimate = 0, CI = [0, 0].
## ---------------------------------------------------------------------
cat("\n\n======================================================\n")
cat("ISSUE #2: fit_outcome(type = 'continuous') on zero-variance outcome\n")
cat("======================================================\n")

cohort_const <- cohort
cohort_const$outcome <- 5  # constant -> zero variance

m_const <- match_cohort(
  data       = cohort_const,
  exposure   = "exposure",
  covariates = setdiff(names(cohort_const), c("exposure", "outcome")),
  seed       = 1
)

check_method <- function(method) {
  cat(sprintf("\n-- method = '%s' --\n", method))
  result <- tryCatch(
    {
      out <- fit_outcome(m_const, "outcome", type = "continuous", method = method)
      list(status = "silent_success", value = out)
    },
    error   = function(e) list(status = "error",   value = conditionMessage(e)),
    warning = function(w) list(status = "warning", value = conditionMessage(w))
  )
  if (result$status == "silent_success") {
    cat("  SILENT SUCCESS (bug still present). Result:\n")
    print(result$value)
  } else if (result$status == "error") {
    cat("  ERRORED (looks fixed). Message:\n  ", result$value, "\n")
  } else {
    cat("  WARNED instead of erroring (partial fix?). Message:\n  ", result$value, "\n")
  }
  result
}

r_regression <- check_method("regression")
r_iptw       <- check_method("iptw")
r_aipw       <- check_method("aipw")

all_still_silent <- all(vapply(
  list(r_regression, r_iptw, r_aipw),
  function(r) r$status == "silent_success",
  logical(1)
))

## ---------------------------------------------------------------------
## SUMMARY
## ---------------------------------------------------------------------
cat("\n\n======================================================\n")
cat("SUMMARY\n")
cat("======================================================\n")
cat(sprintf(
  "Issue #1 (warning volume on subgroup_analysis):  %s\n",
  if (warn_count > 1) "STILL OPEN (many separate warnings)" else "LOOKS RESOLVED"
))
cat(sprintf(
  "Issue #2 (silent zero-variance continuous fit):  %s\n",
  if (all_still_silent) "STILL OPEN (silent success on all 3 methods)" else "LOOKS RESOLVED / PARTIALLY FIXED"
))
cat("\nOnly close an issue on GitHub once its verdict above reads LOOKS\n")
cat("RESOLVED -- 'STILL OPEN' or a signature mismatch means keep it open\n")
cat("and investigate further.\n")