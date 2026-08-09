# Format a comparison table for publication

Converts a raw `comparison` data frame from
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)/[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
(full floating-point precision) into a publication-ready table:
`estimate`, `conf_low`, and `conf_high` are rounded to `digits`
decimals, the confidence interval is rendered as a single
`"low\u2013high"` string (en dash), small p-values are collapsed to
`"<0.001"` (or the equivalent threshold for `p_digits`), and the
estimate column is labeled by outcome type — `"OR"` for
`type == "binary"`, `"Mean Diff"` for `type == "continuous"`.

## Usage

``` r
format_comparison(comparison, digits = 2, p_digits = 3)
```

## Arguments

- comparison:

  A data.frame from
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)'s
  `$comparison` element (columns `method`, `type`, `estimate`,
  `conf_low`, `conf_high`, `p_value`, and optionally `n`).

- digits:

  Number of decimal places for `estimate`, `conf_low`, and `conf_high`
  (default 2).

- p_digits:

  Number of decimal places for `p_value` (default 3); values below
  `10^-p_digits` are rendered as `"<0.001"` (etc.).

## Value

A data.frame with columns `Method`, the outcome-appropriate estimate
label (`OR` or `Mean Diff`), `95% CI`, `p-value`, and `n`.

## Details

This is a display-layer helper: it intentionally does **not** alter the
underlying data.
[`export_results()`](https://mostafa-abbas.github.io/IndepAssoc/reference/export_results.md)
writes CSV files at full numeric precision for downstream reanalysis;
publication-style rounding belongs at the display layer only (printed
tables, vignettes), never baked into exported data.

## Examples

``` r
data(example_cohort)
res <- run_pipeline(
  data = example_cohort,
  exposure = "exposure",
  covariates = c("age", "diabetes", "hypertension", "bmi"),
  outcome = "outcome_binary",
  type = "binary",
  methods = c("regression", "matching", "stratification", "iptw", "aipw")
)
#> Step 1/9: Building propensity score model...
#> Step 2/9: Matching cohorts...
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
#> Step 3/9: Checking balance...
#> Step 4/9: Generating unmatched descriptive table...
#> The following errors were returned during `add_p()`:
#> ✖ For variable `age` (`exposure`) and "estimate", "std.error", "parameter",
#>   "statistic", "conf.low", "conf.high", and "p.value" statistics: The package
#>   "broom" (>= 1.0.8) is required.
#> ✖ For variable `bmi` (`exposure`) and "estimate", "std.error", "parameter",
#>   "statistic", "conf.low", "conf.high", and "p.value" statistics: The package
#>   "broom" (>= 1.0.8) is required.
#> ✖ For variable `diabetes` (`exposure`) and "estimate", "std.error",
#>   "parameter", "statistic", "conf.low", "conf.high", and "p.value" statistics:
#>   The package "broom" (>= 1.0.8) is required.
#> ✖ For variable `hypertension` (`exposure`) and "estimate", "std.error",
#>   "parameter", "statistic", "conf.low", "conf.high", and "p.value" statistics:
#>   The package "broom" (>= 1.0.8) is required.
#> Step 5/9: Generating matched descriptive table...
#> The following errors were returned during `add_p()`:
#> ✖ For variable `diabetes` (`exposure`) and "estimate", "std.error",
#>   "parameter", "statistic", "conf.low", "conf.high", and "p.value" statistics:
#>   The package "broom" (>= 1.0.8) is required.
#> ✖ For variable `hypertension` (`exposure`) and "estimate", "std.error",
#>   "parameter", "statistic", "conf.low", "conf.high", and "p.value" statistics:
#>   The package "broom" (>= 1.0.8) is required.
#> The following errors were returned during `add_p()`:
#> ✖ For variable `age` (`exposure`) and "estimate", "std.error", "parameter",
#>   "statistic", "conf.low", "conf.high", and "p.value" statistics: The package
#>   "broom" (>= 1.0.8) is required.
#> ✖ For variable `bmi` (`exposure`) and "estimate", "std.error", "parameter",
#>   "statistic", "conf.low", "conf.high", and "p.value" statistics: The package
#>   "broom" (>= 1.0.8) is required.
#> Step 6/9: Fitting all outcome models (3 types)...
#> Step 7/9: Running paired statistical tests...
#> Step 8/9: Generating balance table...
#> Step 9/9: Running requested confounding-adjustment methods...
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
#> Pipeline complete.
format_comparison(res$comparison)
#>           Method   OR    95% CI p-value   n
#> 1     Regression 1.71 1.15–2.53   0.008 500
#> 2       Matching 2.17 1.34–3.51   0.002 324
#> 3 Stratification 1.73 1.17–2.54   0.008 500
#> 4           IPTW 1.63 1.10–2.41   0.014 500
#> 5           AIPW 1.64 1.13–2.39   0.010 500
```
