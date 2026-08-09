# Fit All 3 Outcome Models

Fits 3 regression models matching the published pipeline:

1.  Fully adjusted (on full unmatched data)

2.  Conditional (clogit/plm on matched data)

3.  Mixed effect (glmer/lmer on matched data)

## Usage

``` r
fit_all_models(
  ps_model,
  matched_data,
  outcome,
  type = c("binary", "continuous")
)
```

## Arguments

- ps_model:

  An `IndepPSModel` object.

- matched_data:

  Matched data frame from
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md).

- outcome:

  Character; outcome variable name.

- type:

  `"binary"` or `"continuous"`.

## Value

A list of class `"IndepOutcomeModels"` with `$models`, `$summary`,
`$summary_w`.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
models <- fit_all_models(ps, matched$data, "outcome_binary", type = "binary")
models$summary_w
#>            label                   Model   OR     CI_95           p
#> 1 outcome_binary Fully adjusted logistic 1.71 1.15-2.53 0.007515561
#> 2 outcome_binary       Conditional logit 2.17 1.34-3.51 0.001729178
#> 3 outcome_binary   Mixed effect logistic 2.10 1.32-3.36 0.001879335
```
