# Match Cohort Using Propensity Scores

Performs propensity score matching via `MatchIt`.

## Usage

``` r
match_cohort(
  ps_model,
  method = "nearest",
  caliper = 0.2,
  ratio = 1,
  replace = FALSE,
  distance = "logit",
  seed = NULL
)
```

## Arguments

- ps_model:

  An `IndepPSModel` object returned by
  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md).

- method:

  Matching method passed to
  [`MatchIt::matchit()`](https://kosukeimai.github.io/MatchIt/reference/matchit.html).
  Default `"nearest"`.

- caliper:

  Caliper width in SD of logit(PS). Default `0.2`.

- ratio:

  Number of control matches per treated unit. Default `1`.

- replace:

  Whether to match with replacement. Only `FALSE` is supported; `TRUE`
  errors immediately (see Details). Default `FALSE`.

- distance:

  PS distance metric. Default `"logit"`.

- seed:

  Integer passed to [`set.seed()`](https://rdrr.io/r/base/Random.html)
  before matching; required for reproducible matching when tie-breaking
  or MatchIt internals consume randomness. Default `NULL` (no seeding).

## Value

A list of class `"IndepMatch"` with elements:

- match_obj:

  The `MatchIt` match object.

- data:

  Matched data frame.

- ps_model:

  The input `IndepPSModel` object.

## Details

`replace = TRUE` is not supported: matching with replacement produces no
match-pair identifier from
[`MatchIt::match.data()`](https://kosukeimai.github.io/MatchIt/reference/match_data.html),
which the paired downstream functions (balance tables, paired tests, and
the conditional-logit matching estimator) all require. Pass
`replace = FALSE` (the default), or use
[`find_matching_data_summary()`](https://mostafa-abbas.github.io/IndepAssoc/reference/find_matching_data_summary.md)
when replacement matching is needed.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps, caliper = 0.2, ratio = 1)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
head(matched$data)
#>    exposure      age diabetes hypertension      bmi outcome_binary
#> 2         0 59.35302        0            1 30.62061              1
#> 6         0 63.93875        0            1 25.01259              0
#> 7         0 80.11522        0            1 28.82626              0
#> 8         0 64.05341        1            0 13.35761              1
#> 9         1 85.18424        0            0 23.76043              1
#> 11        1 78.04870        0            1 26.50772              1
#>    outcome_continuous       .ps  distance weights subclass strata match_num
#> 2            80.28689 0.6291712 0.6291712       1      158    158       158
#> 6            85.79857 0.6207797 0.6207797       1        9      9         9
#> 7            91.29659 0.7481198 0.7481198       1      139    139       139
#> 8            81.35623 0.6536064 0.6536064       1      107    107       107
#> 9            90.68226 0.7230937 0.7230937       1        1      1         1
#> 11           84.97014 0.7224132 0.7224132       1        2      2         2
```
