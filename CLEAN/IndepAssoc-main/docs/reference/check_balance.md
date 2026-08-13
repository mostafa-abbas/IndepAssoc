# Check Covariate Balance After Matching

Computes absolute standardized mean differences (ASMD) before and after
matching using
[`cobalt::bal.tab()`](https://ngreifer.github.io/cobalt/reference/bal.tab.html).

## Usage

``` r
check_balance(match_obj, threshold = 0.1, plot = FALSE)
```

## Arguments

- match_obj:

  An `IndepMatch` object returned by
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md).

- threshold:

  Numeric ASMD threshold for acceptable imbalance. Default `0.10`.

- plot:

  Logical; if `TRUE`, returns a love plot via
  [`cobalt::love.plot()`](https://ngreifer.github.io/cobalt/reference/love.plot.html).

## Value

A list of class `"IndepBalance"` with elements:

- pre:

  ASMD table for unmatched data.

- post:

  ASMD table for matched data.

- threshold:

  The threshold used.

- all_balanced:

  Logical; `TRUE` if all ASMDs \< threshold after matching.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
matched <- match_cohort(ps)
#> Warning: Fewer control units than treated units; not all treated units will get
#> a match.
bal <- check_balance(matched, threshold = 0.10)
bal$all_balanced
#> [1] FALSE
```
