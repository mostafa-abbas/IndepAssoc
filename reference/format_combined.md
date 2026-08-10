# Format a combined multi-outcome comparison table for publication

Format a combined multi-outcome comparison table for publication

## Usage

``` r
format_combined(combined_comparison, digits = 2, p_digits = 3)
```

## Arguments

- combined_comparison:

  A data.frame with an `Outcome` column plus the raw comparison columns
  (see
  [`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)):
  multiple outcomes' comparison rows stacked together, each tagged with
  its outcome label.

- digits:

  Number of decimal places for `estimate`, `conf_low`, and `conf_high`
  (default 2).

- p_digits:

  Number of decimal places for `p_value` (default 3); values below
  `10^-p_digits` are rendered as `"<0.001"` (etc.).

## Value

A data.frame with columns `Outcome`, `Method`, `Estimate`, `95% CI`,
`p-value`, and `n`. Because the rows may mix binary and continuous
outcomes, the estimate column keeps the generic name `Estimate` — read
it together with the `Outcome` column (an OR for binary outcomes, a mean
difference in the outcome's units for continuous ones).

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
#>   Positivity: PS window [0.010, 0.990]; control [0.366, 0.906], treated [0.364, 0.878]; 0 outside window -> OK
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
#>   IPTW weights (ATE): min 0.53, median 0.97, max 3.56, max/min ratio 6.8
#> Pipeline complete.
combined <- rbind(
  cbind(Outcome = "30-day mortality", res$comparison),
  cbind(Outcome = "Hospital length of stay (days)", res$comparison)
)
format_combined(combined)
#>                           Outcome         Method Estimate    95% CI p-value   n
#> 1                30-day mortality     Regression     1.71 1.15–2.53   0.008 500
#> 2                30-day mortality       Matching     2.17 1.34–3.51   0.002 324
#> 3                30-day mortality Stratification     1.73 1.17–2.54   0.008 500
#> 4                30-day mortality           IPTW     1.63 1.10–2.41   0.014 500
#> 5                30-day mortality           AIPW     1.64 1.13–2.39   0.010 500
#> 6  Hospital length of stay (days)     Regression     1.71 1.15–2.53   0.008 500
#> 7  Hospital length of stay (days)       Matching     2.17 1.34–3.51   0.002 324
#> 8  Hospital length of stay (days) Stratification     1.73 1.17–2.54   0.008 500
#> 9  Hospital length of stay (days)           IPTW     1.63 1.10–2.41   0.014 500
#> 10 Hospital length of stay (days)           AIPW     1.64 1.13–2.39   0.010 500
```
