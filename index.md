# IndepAssoc

[![R-CMD-check](https://github.com/mostafa-abbas/IndepAssoc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mostafa-abbas/IndepAssoc/actions/workflows/R-CMD-check.yaml)

Confounder-adjusted independent association testing via propensity-score
methods.

IndepAssoc generalizes a propensity-score-based analysis pipeline for
retrospective cohort studies. It answers whether a risk factor or
exposure is independently associated with an outcome after adjusting for
confounders via matching, weighting, stratification, or regression, and
produces publication-ready tables and effect estimates with minimal
code.

This package reports confounder-adjusted associations under the standard
no-unmeasured-confounding assumption; it does not establish causal
effects.

## Background

IndepAssoc is the packaged form of the analysis pipeline used in two
published retrospective cohort studies from the same author group:
*[Female sex is associated with short-term mortality in coronary artery
bypass grafting patients: A propensity-matched
analysis](https://doi.org/10.1016/j.heliyon.2025.e41723)* (Heliyon,
2025) and *[Atrial appendage closure is associated with increased risk
for postoperative atrial
fibrillation](https://doi.org/10.1186/s13019-024-03119-6)* (Journal of
Cardiothoracic Surgery, 2024). Both studies used the same
propensity-score workflow — a logistic propensity-score model, 1:1
nearest-neighbor matching, ASMD balance checks, paired descriptive
tests, and conditional outcome models — which this package generalizes
into a reusable interface with five confounding-adjustment methods.

## Validation

The package has 515 passing unit tests and passes `R CMD check` cleanly
(0 errors, 0 notes; one environmental warning — `qpdf` not installed on
the test machine — unrelated to package code). The methods are validated
against the bundled `example_cohort` (a simulated cohort with a known
treatment effect) and `rhc_sample`, the real Right Heart Catheterization
cohort from the SUPPORT study (5,735 patients, 50 confounders) used in
the `rhc-validation` vignette.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("mostafa-abbas/IndepAssoc")
```

Alternatively, install from source with the package source checked out:

``` r

install.packages("devtools")
devtools::install()
```

`causaldata` and `MatchIt` are needed for the vignettes.

## Datasets

Two datasets ship with the package:

- `example_cohort` — a simulated 500-row cohort with a known treatment
  effect, for quick runs of the full pipeline.
- `rhc_sample` — the cleaned Right Heart Catheterization (RHC) cohort
  from the SUPPORT study (5735 rows, 50 confounders), the basis of the
  `rhc-validation` vignette. It is a confounder-adjusted association
  benchmark, not a proof of causality (see
  [`?rhc_sample`](https://mostafa-abbas.github.io/IndepAssoc/reference/rhc_sample.md)).

Both are lazy-loaded via [`data()`](https://rdrr.io/r/utils/data.html);
the raw-generation scripts live in `data-raw/`
(`simulate_example_cohort.R`, `prepare_rhc.R`) and are excluded from the
installed package.

## Example

``` r

library(IndepAssoc)
data(example_cohort)

set.seed(1)
res <- run_pipeline(
  data = example_cohort,
  exposure = "exposure",
  covariates = c("age", "diabetes", "hypertension", "bmi"),
  outcome = "outcome_continuous",
  type = "continuous",
  methods = c("regression", "matching", "stratification", "iptw", "aipw")
)
format_comparison(res$comparison)
```

[`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)
rounds the raw `$comparison` data frame into the publication-ready table
below. Here `matching` is propensity-score matching with
conditional-logit/paired estimation (conditional logistic regression
stratified by matched pair for binary outcomes, a within-pair
fixed-effects linear model for continuous outcomes).

              Method Mean Diff     95% CI p-value   n
    1     Regression      1.54  0.59–2.48   0.001 500
    2       Matching      2.15  0.95–3.34  <0.001 324
    3 Stratification      1.58  0.45–2.71   0.006 500
    4           IPTW      1.38 -0.05–2.81   0.059 500
    5           AIPW      1.48  0.51–2.46   0.003 500

The five methods do not all target the same estimand: `matching` targets
the average treatment effect on the treated (ATT) by construction,
`iptw` and `aipw` target the marginal ATE over the full analytic sample,
`stratification` pools stratum-specific effects across the full sample,
and `regression` reports a conditional (covariate-adjusted) effect — the
binary-outcome odds ratio is non-collapsible, so it is not numerically
equal to a marginal ATE. Agreement across the five is still meaningful
robustness evidence, but they are related quantities, not five copies of
one number.

## Reproducibility

Matching-based results draw on the random number generator, so a fixed
seed is required to reproduce them. Set it explicitly —
`run_pipeline(..., seed = N)` or, for direct matching,
`match_cohort(..., seed = N)` — and reuse the same seed value to obtain
identical results.
