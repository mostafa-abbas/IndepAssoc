# McNemar Test on Matched Data

Tests for association between a binary `exposure` and a binary `outcome`
within matched strata, using the Cochran-Mantel-Haenszel test
([`stats::mantelhaen.test()`](https://rdrr.io/r/stats/mantelhaen.test.html))
over the per-stratum 2x2 tables. For 1:1 matching this is equivalent to
McNemar's test; it generalizes naturally to many:1 (ratio \> 1)
matching, where each stratum may hold several control units.

## Usage

``` r
mcnemar_test(matched_data, outcome, exposure)
```

## Arguments

- matched_data:

  Matched data frame with `match_num` column.

- outcome:

  Character; binary outcome variable name, coded 0/1.

- exposure:

  Character; binary exposure variable name.

## Value

A data frame with McNemar test results.

## Details

Strata (pairs) with no observed outcome on any member cannot contribute
to the test and are dropped; the number dropped is reported via a
[`message()`](https://rdrr.io/r/base/message.html). Rows with a missing
outcome within otherwise-usable strata are excluded from that stratum's
table and also counted in the message. If the resulting table is
degenerate (e.g. a constant outcome), the test degrades to an `NA` row
with a warning rather than halting the pipeline.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
mcnemar_test(matched$data, "outcome_binary", "exposure")
#>            label  0(n=162) 1(n=162) statistic     p.value           p
#> 1 outcome_binary 74(45.7%) 102(63%)  9.592105 0.001954158 0.001954158
```
