# Subgroup Analysis

Repeats
[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
within each level of a subgroup variable.

## Usage

``` r
subgroup_analysis(
  match_obj,
  outcome,
  subgroup_var,
  type = c("binary", "continuous"),
  method = "regression",
  ...
)
```

## Arguments

- match_obj:

  An `IndepMatch` object from
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md).

- outcome:

  Character string naming the outcome variable.

- subgroup_var:

  Character string naming the subgroup variable.

- type:

  Outcome type (`"binary"`, `"continuous"`).

- method:

  Confounding-adjustment method, passed to
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
  (default `"regression"`).

- ...:

  Additional arguments passed to
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md).

## Value

A data frame with one row per subgroup level, containing subgroup name,
n, estimate, CI, and p-value.

## Details

`subgroup_var` is intended to be a categorical variable with a small
number of levels and adequate per-subgroup sample size; continuous
variables should be binned first (e.g. `cut(age, breaks = 4)`).
Subgroups whose model fails to fit (e.g. a degenerate outcome within the
subgroup) return an NA row rather than halting the analysis; when
several subgroups fail, the individual failure messages are consolidated
into a single summary warning naming each affected subgroup (details
truncated beyond the first few).

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
subgroup_analysis(matched, "outcome_binary", "diabetes", type = "binary")
#> Subgroup variable 'diabetes' removed from the covariate set for subgroup models because it is constant within each subgroup.
#>   subgroup   n estimate  conf_low conf_high     p_value
#> 1        0 244 1.577556 0.9418082  2.642452 0.083244661
#> 2        1  80 4.374751 1.4322448 13.362550 0.009582596
```
