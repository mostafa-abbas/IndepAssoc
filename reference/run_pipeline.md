# Run the IndepAssoc Analysis Pipeline

Orchestrates the full pipeline: PS model, matching, balance check,
descriptive tables, outcome models (3 types), and statistical tests.

## Usage

``` r
run_pipeline(
  data,
  exposure,
  covariates,
  outcome,
  type = c("binary", "continuous"),
  caliper = 0.2,
  ratio = 1,
  balance_threshold = 0.1,
  methods = c("regression", "matching", "stratification", "iptw", "aipw"),
  seed = NULL
)
```

## Arguments

- data:

  Data frame containing the cohort.

- exposure:

  Character string naming the binary exposure variable.

- covariates:

  Character vector of covariate names.

- outcome:

  Character string naming the outcome variable.

- type:

  Outcome type: `"binary"` or `"continuous"`.

- caliper:

  Caliper for matching (default `0.2`).

- ratio:

  Match ratio (default `1`).

- balance_threshold:

  ASMD threshold (default `0.10`).

- methods:

  Character vector of confounding-adjustment methods to run via
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
  (default all five: `"regression"`, `"matching"`, `"stratification"`,
  `"iptw"`, `"aipw"`). `"matching"` is propensity-score matching with
  conditional-logit (binary) / within-pair (continuous) estimation;
  because matching draws on the data, results are reproducible only when
  a fixed seed is set before the call. `"iptw"` is a marginal structural
  model (outcome regressed on the exposure only, weighted by stabilized
  inverse probability weights) and `"aipw"` is a doubly-robust augmented
  estimator.

- seed:

  Integer passed to [`set.seed()`](https://rdrr.io/r/base/Random.html)
  at the top of the pipeline. A fixed seed makes the whole run —
  including the step-2 matching and the step-9 `"matching"` method —
  reproducible from a single value. Default `NULL` (no seeding).

## Value

A list of class `"IndepAssoc"` containing all pipeline results,
including `balance_plot` — the `ggplot` chart of absolute standardized
mean differences (ASMD) for unadjusted vs. matched cohorts, produced by
[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
at the `balance_threshold` used.

## Details

Whenever `"matching"` is among the requested `methods`, a fixed `seed`
is required for reproducible results. Pass the same `seed` value to
`run_pipeline()` rather than setting a seed mid-pipeline, so the step-2
matching and the step-9 `"matching"` method both draw on it.

The ASMD balance chart is returned as `result$balance_plot` for you to
print or save; [`print()`](https://rdrr.io/r/base/print.html) does not
render it.

## Examples

``` r
data(example_cohort)
res <- run_pipeline(
  data = example_cohort,
  exposure = "exposure",
  covariates = c("age", "diabetes", "hypertension", "bmi"),
  outcome = "outcome_binary",
  type = "binary",
  methods = c("regression", "matching")
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
res$comparison
#>       method          label   type estimate conf_low conf_high     p_value   n
#> 1 regression outcome_binary binary 1.708602 1.153623  2.530568 0.007515561 500
#> 2   matching outcome_binary binary 2.166667 1.335788  3.514363 0.001729178 324
```
