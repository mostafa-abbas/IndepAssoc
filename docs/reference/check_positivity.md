# Check Propensity-Score Positivity and IPTW Weight Diagnostics

Inspects the propensity-score distribution for the positivity (overlap)
assumption and reports the distribution of the inverse-probability
weights that
[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)'s
IPTW method uses. Extreme propensity scores (near 0 or 1) or extreme
weights are the practical symptom of positivity problems and can produce
unstable, high-variance IPTW/AIPW estimates even when covariate balance
looks fine on average.

## Usage

``` r
check_positivity(ps, threshold = c(0.01, 0.99), estimand = c("ATE", "ATT"))
```

## Arguments

- ps:

  An `IndepPSModel` object returned by
  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md).

- threshold:

  Length-2 numeric vector giving the propensity-score support window.
  Scores below the first value or above the second are flagged as
  positivity violations. Default `c(0.01, 0.99)`.

- estimand:

  Causal estimand whose IPTW weight distribution is reported: `"ATE"`
  (default) reports the stabilized inverse-probability weights
  `A/ps + (1-A)/(1-ps)`; `"ATT"` reports the standardized mortality
  ratio weights `A + (1-A)*ps/(1-ps)`. Both match the weights
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
  actually uses.

## Value

A list of class `"IndepPositivity"` with elements:

- threshold:

  The support window used.

- ps_by_group:

  Data frame of propensity-score quantiles by exposure group, with
  columns `group`, `n`, `min`, `q25`, `median`, `q75`, `max`.

- ps_violations:

  List with `n_below`, `n_above`, and `n_total` — counts of units whose
  propensity score falls outside `threshold`.

- violation:

  Logical; `TRUE` if any propensity score falls outside `threshold`.

- weights:

  List describing the IPTW weight distribution for the requested
  `estimand`: `estimand`, `n`, `min`, `median`, `max`, and
  `max_min_ratio` (largest divided by smallest weight, an extreme-weight
  summary).

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
check_positivity(ps)
#> Propensity-score positivity check
#> ================================
#> Support window: 0.01 to 0.99 
#>   exposure 0 (n=167): PS [0.366, 0.906], median 0.642
#>   exposure 1 (n=333): PS [0.364, 0.878], median 0.677
#> Positivity: OK (0 outside window)
#> IPTW weights (ATE): min 0.53, median 0.97, max 3.56, max/min ratio 6.8
```
