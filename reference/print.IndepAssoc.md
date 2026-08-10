# Print an IndepAssoc pipeline result

Print an IndepAssoc pipeline result

## Usage

``` r
# S3 method for class 'IndepAssoc'
print(x, ...)
```

## Arguments

- x:

  An `IndepAssoc` object from
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md).

- ...:

  Additional arguments (ignored).

## Examples

``` r
data(example_cohort)
res <- run_pipeline(
  data = example_cohort,
  exposure = "exposure",
  covariates = c("age", "diabetes", "hypertension", "bmi"),
  outcome = "outcome_binary",
  type = "binary",
  methods = "regression"
)
#> Step 1/9: Building propensity score model...
#>   Positivity: PS window [0.010, 0.990]; control [0.366, 0.906], treated [0.364, 0.878]; 0 outside window -> OK
#> Step 2/9: Matching cohorts...
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
#> Step 3/9: Checking balance...
#> Step 4/9: Generating unmatched descriptive table...
#> Step 5/9: Generating matched descriptive table...
#> Step 6/9: Fitting all outcome models (3 types)...
#> Step 7/9: Running paired statistical tests...
#> Step 8/9: Generating balance table...
#> Step 9/9: Running requested confounding-adjustment methods...
#> Pipeline complete.
print(res)
#> IndepAssoc Pipeline Result
#> ==========================
#> 
#> Exposure: exposure 
#> Covariates: age, diabetes, hypertension, bmi 
#> Outcome type: binary 
#> Matched observations: 324 
#> Balance check: FAILED 
#> 
#> Model Summary:
#>            label                   Model   OR     CI_95           p
#> 1 outcome_binary Fully adjusted logistic 1.71 1.15-2.53 0.007515561
#> 2 outcome_binary       Conditional logit 2.17 1.34-3.51 0.001729178
#> 3 outcome_binary   Mixed effect logistic 2.10 1.32-3.36 0.001879335
```
