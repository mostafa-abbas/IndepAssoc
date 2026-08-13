# Export pipeline results to CSV files

Saves all pipeline outputs to CSV files in the specified directory.

## Usage

``` r
export_results(result, output_dir = "output")
```

## Arguments

- result:

  An `IndepAssoc` object from
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md).

- output_dir:

  Directory to write CSV files to.

## Value

Invisibly returns the output directory path.

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
out_dir <- tempfile("indepassoc_export_")
export_results(res, output_dir = out_dir)
#> Results exported to: /tmp/Rtmp4qiGXC/indepassoc_export_197518652641
list.files(out_dir)
#> [1] "balance_check_all.csv"         "balance_check_matched.csv"    
#> [3] "binary_regression_summary.csv" "comparison.csv"               
#> [5] "stat_test_binary_matched.csv" 
unlink(out_dir, recursive = TRUE)
```
