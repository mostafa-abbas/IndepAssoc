# Fit an Outcome Model with a Chosen Confounding-Adjustment Method

Fit an Outcome Model with a Chosen Confounding-Adjustment Method

## Usage

``` r
fit_outcome(
  data,
  exposure,
  covariates,
  outcome,
  type = c("binary", "continuous"),
  method = c("regression", "matching", "stratification", "iptw", "aipw"),
  ...
)
```

## Arguments

- data:

  Data frame containing exposure, covariates, and outcome.

- exposure:

  Character; exposure variable name (binary).

- covariates:

  Character vector of covariate names.

- outcome:

  Character; outcome variable name.

- type:

  Outcome type: `"binary"` or `"continuous"`.

- method:

  One or more of `"regression"`, `"matching"`, `"stratification"`,
  `"iptw"`, `"aipw"`. If a vector, returns a list of results, one per
  method. `"matching"` is propensity-score matching with
  conditional-logit (binary) / within-pair (continuous) estimation.

- ...:

  Passed to the per-method estimators. `seed` is accepted by the
  matching method for reproducible matching.

## Value

A named list with `method`, `type`, `estimate`, `conf_low`, `conf_high`,
`p_value`, `n`, and `model`. If `method` has length \> 1, a named list
of such results.

## Details

`"regression"` adjusts for covariates directly in the outcome model.
`"matching"` is propensity-score matching with conditional-logit
(binary) / within-pair (continuous) estimation. `"stratification"`
stratifies on the propensity score. `"iptw"` is a marginal structural
model: the outcome model regresses on the exposure only, weighted by
stabilized inverse probability of treatment weights, with robust
sandwich standard errors — confounding is controlled by the weights
alone. `"aipw"` is a doubly-robust augmented estimator (Bang & Robins)
that models both the outcome and the propensity score. For
`method = "matching"`, binary outcomes must be coded as numeric 0/1 (the
conditional-logit estimator strata on the matched pair).

## Examples

``` r
data(example_cohort)
res <- fit_outcome(example_cohort, "exposure",
                   c("age", "diabetes", "hypertension", "bmi"),
                   "outcome_binary", type = "binary",
                   method = c("regression", "iptw"))
res$regression$estimate
#> [1] 1.708602
res$iptw$estimate
#> [1] 1.632152
```
