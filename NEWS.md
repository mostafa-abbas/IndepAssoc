# IndepAssoc 0.6.5 (2026-08-17)

## Bug fixes

- `run_pipeline()` and `fit_outcome()` now validate the exposure, all
  specified covariates, and the outcome for missing values before any method
  runs, via a shared `.check_missing_data()` check. The error names the
  affected column(s) and the exact count and percentage of missing values,
  and the check applies identically whether `run_pipeline()` or
  `fit_outcome()` is called directly.
  Previously, missing values in the exposure or a covariate caused an
  unreadable internal `$<-.data.frame` length-mismatch error during
  propensity-score fitting. More seriously, missing outcome values were not
  checked at all: `iptw`, `matching`, `stratification`, and `regression`
  each completed using their underlying model's own default row handling,
  while `aipw` silently returned `NA` for its estimate with no error or
  warning, producing a comparison table with an unexplained blank AIPW row
  next to four populated ones.

# IndepAssoc 0.6.4 (2026-08-11)

## Bug fixes

Restores support for two-level factor exposures (e.g.
`factor(exposure, labels = c("control", "treated"))`), which 0.6.3's
arm-count validation had broken.

- `build_ps_model()` and `check_positivity()` now normalize a factor exposure
  the same way the model fitting already does: the first factor level is the
  reference (control) arm and the second is the treated arm. Previously the
  arm-count check compared the raw column to `0`/`1`, so a factor whose levels
  were not literally `"0"`/`"1"` — a completely ordinary way to code a binary
  exposure in R — reported `No control units found in the data` even when both
  arms were present, and `check_positivity()` returned `NA` weights. (#4)
- Arm coding now follows factor level order explicitly and is covered by
  tests: level 1 is always control and level 2 is always treated, regardless
  of the labels. This pins down the semantics that previously relied on the
  user coding the control arm first and silently flipped treated/control when
  they did not. (#5)
- 0.6.3's degenerate-data validation is unchanged: an exposure with a
  genuinely empty or single-unit arm still errors.

# IndepAssoc 0.6.3 (2026-08-11)

## Input validation hardening

Malformed argument values and degenerate input now fail fast with a clear,
actionable error instead of silently succeeding or surfacing only a generic
downstream warning.

- `match_cohort()` errors when `caliper` is negative. A negative caliper such
  as `caliper = -0.2` previously ran MatchIt with an invalid caliper and
  silently returned a matched cohort.
- `fit_outcome()` with `method = "iptw"` or `method = "aipw"` errors when
  `trim` bounds are inverted (e.g. `trim = c(0.9, 0.1)`); previously the
  range was silently sorted. `trim` must be ascending `(lower, upper)`.
- `check_positivity()` errors when `threshold` bounds are inverted (e.g.
  `threshold = c(0.99, 0.01)`); previously the inverted bounds silently
  mis-counted every unit as outside the support window. `threshold` must be
  ascending `(lower, upper)`.
- `build_ps_model()` errors when the data has fewer than 4 rows, when either
  exposure arm is empty, or when either arm contains fewer than 2 units, and
  warns when either arm has fewer than 10 units. Previously `n = 1`,
  all-treated, and all-control data all "converged" with degenerate
  propensity scores (all 1, all 0, or {0, 1}) that produced `NaN`/`Inf`
  weights downstream, with no indication that the sample was too small.
- `fit_outcome()` and `fit_all_models()` error on a zero-variance binary
  outcome. Previously an all-0 or all-1 outcome silently returned a
  meaningless OR of 1 (with a `0-Inf` confidence interval), an `NA`, or even
  an impossible negative OR, after only a generic `glm.fit: algorithm did
  not converge` warning — or, for the mixed-effect model, a skipped fit with
  a warning. The error is raised once at each entry point (on the top-level
  outcome vector) with the same message, so `run_pipeline()` and
  `subgroup_analysis()` inherit it and the two entry points behave
  identically. A constant outcome within a matched subset or subgroup, where
  the full cohort's outcome varies, still degrades gracefully: the affected
  model returns an `NA` with a warning and the others are unaffected.

**Behavior change for `run_pipeline()`:** a constant binary outcome now halts
the pipeline at Step 6 (`fit_all_models()`) with the clear "zero variance"
error instead of returning a results object with garbage rows (OR = 1,
`0-Inf` CI, `NA`) for every binary model.

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