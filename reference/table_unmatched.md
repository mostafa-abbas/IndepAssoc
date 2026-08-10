# Unmatched Descriptive Table

Produces a summary table of covariates by exposure group using
chi-square (categorical) or Wilcoxon rank-sum (continuous) tests.

## Usage

``` r
table_unmatched(data, exposure, covariates)
```

## Arguments

- data:

  Data frame (unmatched).

- exposure:

  Character string naming the exposure variable.

- covariates:

  Character vector of covariate names.

## Value

A `gtsummary` table object.

## Examples

``` r
data(example_cohort)
table_unmatched(example_cohort, "exposure",
                c("age", "diabetes", "hypertension", "bmi"))


  

Characteristic
```
