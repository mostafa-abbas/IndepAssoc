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
  estimand = c("ATE", "ATT"),
  trim = NULL,
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

- estimand:

  Causal estimand: `"ATE"` (default) or `"ATT"`. With `"ATT"`, the
  propensity-score methods target the average treatment effect on the
  treated: `"iptw"` and `"aipw"` use standardized mortality ratio (SMR)
  weights, and `"stratification"` pools each stratum's within-stratum
  effect with weights proportional to the number of treated units in the
  stratum (Austin, 2011, doi:10.1080/00273171.2011.568786). `"matching"`
  targets the ATT by construction (1:1 matching without replacement) and
  ignores this argument — a silent no-op. `"regression"` reports a
  conditional effect and also ignores it.

- trim:

  Optional length-1 or length-2 probability vector for weight trimming,
  applied to the IPTW and AIPW methods only. Weights are truncated at
  the specified percentiles of their distribution (Cole & Hernan 2008,
  doi:10.1093/aje/kwn085), so `trim = c(0.01, 0.99)` caps extreme
  weights that otherwise inflate variance. Default `NULL` (no trimming,
  current behavior preserved exactly). Ignored by `"regression"`,
  `"matching"`, and `"stratification"`.

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
stabilized inverse probability of treatment weights (or SMR weights when
`estimand = "ATT"`), with robust sandwich standard errors — confounding
is controlled by the weights alone. `"aipw"` is a doubly-robust
augmented estimator (Bang & Robins) that models both the outcome and the
propensity score. For `method = "matching"`, binary outcomes must be
coded as numeric 0/1 (the conditional-logit estimator strata on the
matched pair).

## References

Austin PC. An introduction to propensity score methods for reducing the
effects of confounding in observational studies. *Multivariate
Behavioral Research* 2011;46(3):399-424,
doi:10.1080/00273171.2011.568786. Austin 2011 is the source for the IPTW
SMR weights and the treated-count pooling used by `estimand = "ATT"`.
Lunceford JK, Davidian M. Stratification and weighting via the
propensity score in estimation of causal treatment effects. *Statistics
in Medicine* 2004;23(19):2937-2960, doi:10.1002/sim.1903. Lunceford &
Davidian (2004) is the source for the augmented influence-function
ATE/ATT derivation used by AIPW.

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
