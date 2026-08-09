# Summary of an IndepAssoc pipeline result

Summary of an IndepAssoc pipeline result

## Usage

``` r
# S3 method for class 'IndepAssoc'
summary(object, ...)
```

## Arguments

- object:

  An `IndepAssoc` object from
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md).

- ...:

  Additional arguments passed to
  [`print.IndepAssoc()`](https://mostafa-abbas.github.io/IndepAssoc/reference/print.IndepAssoc.md).

## Examples

``` r
data(example_cohort)
res <- run_pipeline(
  data = example_cohort,
  exposure = "exposure",
  covariates = c("age", "diabetes", "hypertension", "bmi"),
  outcome = "outcome_continuous",
  type = "continuous",
  methods = "regression"
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
#> Pipeline complete.
summary(res)
#> IndepAssoc Pipeline Result
#> ==========================
#> 
#> Exposure: exposure 
#> Covariates: age, diabetes, hypertension, bmi 
#> Outcome type: continuous 
#> Matched observations: 324 
#> Balance check: FAILED 
#> 
#> Model Summary:
#>                label                            Model     SC         CI_95
#> 1 outcome_continuous Fully adjusted linear regression 0.0334  0.013-0.0538
#> 2 outcome_continuous    Conditional linear regression 0.0466 0.0209-0.0724
#> 3 outcome_continuous   Mixed effect linear regression 0.0466 0.0209-0.0724
#>               SC_CI_95            p
#> 1  0.033(0.013-0.0538) 0.0014506971
#> 2 0.047(0.0209-0.0724) 0.0005131617
#> 3 0.047(0.0209-0.0724) 0.0005131617
```
