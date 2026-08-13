# Paired Wilcoxon Test on Matched Data

Paired signed-rank test comparing a continuous `outcome` between the two
levels of `exposure` within matched strata. For 1:1 matching each
stratum contributes its treated and control value directly; for many:1
(ratio \> 1) matching the outcome is first averaged over the multiple
controls within each stratum, so every matched row contributes to the
test.

## Usage

``` r
paired_wilcoxon_test(matched_data, outcome, exposure)
```

## Arguments

- matched_data:

  Matched data frame with `match_num` column.

- outcome:

  Character; continuous outcome variable name.

- exposure:

  Character; binary exposure variable name.

## Value

A data frame with Wilcoxon test results.

## Details

Strata (pairs) missing an observed outcome on either side of the pair
cannot contribute to the paired comparison and are dropped; the number
dropped is reported via a
[`message()`](https://rdrr.io/r/base/message.html). Descriptive
quantiles are computed with `na.rm = TRUE`.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
paired_wilcoxon_test(matched$data, "outcome_continuous", "exposure")
#>                label        0(n=162)        1(n=162) statistic     p.value
#> 1 outcome_continuous 84.3(79.2-88.5) 86.1(81.1-90.6)      4734 0.001795215
```
