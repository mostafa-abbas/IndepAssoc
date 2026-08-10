# IndepAssoc (unreleased)

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