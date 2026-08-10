# Matched Descriptive Table

Produces a summary table for matched data using paired tests: McNemar
(categorical) or Wilcoxon signed-rank (continuous).

## Usage

``` r
table_matched(match_obj, covariates)
```

## Arguments

- match_obj:

  An `IndepMatch` object returned by
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md).

- covariates:

  Character vector of covariate names.

## Value

A `gtsummary` table object.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
table_matched(matched, c("age", "diabetes", "hypertension", "bmi"))


  


Characteristic
```
