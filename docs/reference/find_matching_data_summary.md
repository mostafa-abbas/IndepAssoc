# Summarize Balance Before and After Propensity Score Matching

Fits a propensity score model with
[`MatchIt::matchit()`](https://kosukeimai.github.io/MatchIt/reference/matchit.html)
and returns the standardized balance summary tables for the full
(unmatched) and matched samples, mirroring the structure produced by the
standalone PSM analysis scripts (`match_summ$all`,
`match_summ$matched`).

## Usage

``` r
find_matching_data_summary(data, exposure, covariates, caliper = 0.2, ...)
```

## Arguments

- data:

  Data frame containing the cohort.

- exposure:

  Character; binary exposure variable name.

- covariates:

  Character vector of covariate names.

- caliper:

  Caliper width passed to
  [`MatchIt::matchit()`](https://kosukeimai.github.io/MatchIt/reference/matchit.html).
  Default `0.20`.

- ...:

  Additional arguments passed to
  [`MatchIt::matchit()`](https://kosukeimai.github.io/MatchIt/reference/matchit.html)
  (e.g. `method`, `ratio`, `replace`). `ratio > 1` (multiple control
  units per treated unit) is supported.

## Value

A list with:

- match_summ:

  List with `all` and `matched` data frames from
  `summary(matchit(...), standardize = TRUE)`; covariate names are the
  row names and each table carries a `Std. Mean Diff.` column.

- Data_all:

  The input data frame with a `match_num` column added (all `NA` for
  units outside the matched sample).

- Data_matched:

  The matched subset with a `match_num` column.

## Details

For `ratio > 1`, `Data_matched` retains one row per treated/control
pair: each treated unit appears once for every one of its matched
controls, and every row carries the `match_num` of its pair. `Data_all`
keeps one row per unit, so a treated unit matched to several controls
carries the `match_num` of its first pair there. When `replace = TRUE`,
a control unit reused across multiple pairs appears once per reuse in
`Data_matched`, but can carry only a single `match_num` in `Data_all`
(the first pair that matched it wins).

## Examples

``` r
data(example_cohort)
res <- find_matching_data_summary(
  example_cohort,
  "exposure",
  c("age", "diabetes", "hypertension", "bmi")
)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
head(res$match_summ$all)
#>              Means Treated Means Control Std. Mean Diff. Var. Ratio  eCDF Mean
#> distance         0.6779234     0.6422246      0.40466753  1.0342505 0.11632886
#> age             65.5322946    63.0390107      0.26689479  0.8279526 0.07585981
#> diabetes         0.3243243     0.2155689      0.23232298         NA 0.10875546
#> hypertension     0.5255255     0.5089820      0.03313018         NA 0.01654349
#> bmi             28.0618722    27.2558694      0.16383500  1.1302040 0.05753854
#>                eCDF Max Std. Pair Dist.
#> distance     0.18791246              NA
#> age          0.16958875              NA
#> diabetes     0.10875546              NA
#> hypertension 0.01654349              NA
#> bmi          0.11542680              NA
```
