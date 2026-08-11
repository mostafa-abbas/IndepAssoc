# IndepAssoc 0.6.3 (unreleased)

## Input validation hardening

First pass of the 0.6.3 hardening series (issue #1): malformed range arguments
now fail fast with a clear, actionable error instead of silently succeeding.

- `match_cohort()` now errors when `caliper` is negative. A negative caliper
  such as `caliper = -0.2` previously ran MatchIt with an invalid caliper and
  silently returned a matched cohort.
- `fit_outcome()` with `method = "iptw"` or `method = "aipw"` now errors when
  `trim` bounds are inverted (e.g. `trim = c(0.9, 0.1)`); previously the range
  was silently sorted. `trim` must be ascending `(lower, upper)`.
- `check_positivity()` now errors when `threshold` bounds are inverted (e.g.
  `threshold = c(0.99, 0.01)`); previously the inverted bounds silently
  mis-counted every unit as outside the support window. `threshold` must be
  ascending `(lower, upper)`.
- `build_ps_model()` now fails fast on degenerate cohorts instead of silently
  returning a meaningless model: it errors when the data has fewer than 2
  rows, when either exposure arm is empty, or when either arm contains fewer
  than 2 units. Previously `n = 1`, all-treated, and all-control data all
  "converged" with degenerate propensity scores (all 1, all 0, or {0, 1})
  that produced `NaN`/`Inf` weights downstream.
- `fit_outcome()` now errors on a zero-variance binary outcome for every
  method (regression, matching, stratification, iptw, aipw). Previously an
  all-0 or all-1 outcome silently returned a meaningless OR of 1 (with a
  `0-Inf` confidence interval), an `NA`, or even an impossible negative OR,
  after only a generic `glm.fit: algorithm did not converge` warning. The
  error is raised once at the `fit_outcome()` entry point, so `run_pipeline()`
  and `subgroup_analysis()` inherit it. A related test asserting that
  `run_pipeline()` *completes* on a constant binary response was repurposed
  to assert the new error instead.
- `fit_all_models()` now errors on a zero-variance binary outcome instead of
  returning a warning plus meaningless estimates. Previously an all-0 or
  all-1 outcome was only detected by `lme4` for the mixed-effect model (which
  was skipped with a warning and an `NA` row), while the fully adjusted
  logistic and conditional logit models silently returned a meaningless OR
  of 1 (with a `0-Inf` confidence interval) or `NA`. The error is raised once
  at the `fit_all_models()` entry point with the same message as
  `fit_outcome()`, so the two entry points behave identically. A related test
  asserting that `fit_all_models()` *degrades gracefully* on a constant
  response was repurposed to assert the new error instead.

**Behavior change for `run_pipeline()`:** a constant binary outcome now halts
the pipeline at Step 6 (`fit_all_models()`) with the clear "zero variance"
error, before any results object is returned. A call that previously completed
and returned a results object with garbage rows (OR = 1, `0-Inf` CI, `NA`)
for every binary model now stops with an error. This was already the
`fit_outcome()` behavior at Step 9 since the previous release; the halting
point is now earlier and `fit_all_models()` standalone is consistent.

# IndepAssoc 0.6.2 (2026-08-10)

## Bug fixes

Completes the 0.6.1 auto-detection fix for the package's remaining
public entry points.

- `fit_outcome()` and `subgroup_analysis()` now auto-detect the outcome type
  when `type` is omitted, matching the behavior `run_pipeline()` and
  `fit_all_models()` gained in 0.6.1. A numeric or logical outcome whose
  values are all 0/1 is treated as `"binary"`; any other numeric outcome is
  treated as `"continuous"`. Previously a direct `fit_outcome()` call on a
  continuous outcome such as `los` with `type` omitted still crashed with
  `y values must be 0 <= y <= 1` because it defaulted to a binomial family
  through `match.arg()`. An explicit `type` argument is still respected, and
  binary outcomes are unchanged.

# IndepAssoc 0.6.1 (2026-08-10)

## Bug fixes

A bugfix pass hardening the analysis pipeline for continuous outcomes and
matched Table 1 generation.

- `run_pipeline()` and `fit_all_models()` now auto-detect the outcome type
  when `type` is omitted. A numeric or logical outcome whose values are all
  0/1 is treated as `"binary"`; any other numeric outcome is treated as
  `"continuous"`. Previously a continuous outcome such as `los` crashed with
  `y values must be 0 <= y <= 1` because it defaulted to a binomial family.
  An explicit `type` argument is still respected, and binary outcomes
  (`dth30`, `death`) are unchanged.
- `table_matched()` now pre-screens categorical covariates before running the
  paired McNemar test, so a factor whose rare levels collapse to fewer than 2
  observed levels in one exposure group after matching no longer makes
  `gtsummary::add_p()` report an error. Such variables still appear in the
  matched Table 1 (with counts) but are excluded from `add_p()` testing and
  shown without a p-value instead of halting table generation.

# IndepAssoc 0.6.0

Adds explicit control over which causal estimand the propensity-score methods
target, plus propensity-score and weight diagnostics.

- `fit_outcome()` and `run_pipeline()` gain an `estimand = c("ATE", "ATT")`
  argument. With `"ATT"`, IPTW and AIPW use standardized mortality ratio (SMR)
  weighting and stratification pools by treated-unit count, so all four
  propensity-score-based methods can target the average treatment effect on
  the treated rather than the population average. Matching already targets
  the ATT by construction and ignores this argument. The default (`"ATE"`)
  is unchanged from prior behavior.
- New `check_positivity()` reports propensity-score overlap between exposure
  groups, flags units outside a configurable support window (default
  `[0.01, 0.99]`), and summarizes the resulting IPTW weight distribution.
  `run_pipeline()` now prints this summary on every run and returns it as
  `result$positivity`.
- `fit_outcome()` gains a `trim` argument for the `"iptw"`/`"aipw"` methods,
  truncating extreme weights at specified percentiles. Default (`trim =
  NULL`) is unchanged from prior behavior.
- The RHC validation vignette now includes a worked positivity/weight
  diagnostic on the real cohort, a demonstration of the `estimand` and `trim`
  arguments, and a log-transformed sensitivity check for the right-skewed
  `los` outcome, alongside an expanded discussion of which estimand each of
  the five methods targets.

# IndepAssoc 0.5.0

Initial public release. Implements five confounding-adjustment methods
(regression, matching, stratification, IPTW, AIPW) for testing whether
an exposure is independently associated with an outcome after adjusting
for measured confounders, generalizing the shared analysis pipeline from
two peer-reviewed cardiac-surgery studies (see README).

Validated against the RHC benchmark cohort (Connors et al. 1996) and
NHEFS/lalonde (Hernán & Robins; Dehejia & Wahba). See vignettes for
worked examples.