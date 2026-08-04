# IndepAssoc

Confounder-adjusted independent association testing via propensity-score methods.

IndepAssoc generalizes a propensity-score-based analysis pipeline for retrospective
cohort studies. It answers whether a risk factor or exposure is independently
associated with an outcome after adjusting for confounders via matching, weighting,
stratification, or regression, and produces publication-ready tables and effect
estimates with minimal code.

This package reports confounder-adjusted associations under the standard
no-unmeasured-confounding assumption; it does not establish causal effects.

## Installation

Install from source in an R session with the package source checked out:

```
install.packages("devtools")
devtools::install()
```

`causaldata` and `MatchIt` are needed for the vignettes.

## Example

```r
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
res$comparison
```
# The comparison table shows all five methods' estimates. Here `matching` is
# propensity-score matching with conditional-logit/paired estimation (conditional
# logistic regression stratified by matched pair for binary outcomes, a within-pair
# fixed-effects linear model for continuous outcomes).
```
          method              label       type estimate  conf_low conf_high
1     regression outcome_continuous continuous 1.537680 0.5942670  2.481092
2       matching outcome_continuous continuous 2.146948 0.9511478  3.342748
3 stratification outcome_continuous continuous 1.581406 0.4542341  2.708577
4           iptw outcome_continuous continuous 1.483272 0.5107104  2.455833
5           aipw outcome_continuous continuous 1.484582 0.5090073  2.460157
       p_value   n
1 0.0014506971 500
2 0.0005131617 324
3 0.0059631379 500
4 0.0028681300 500
5 0.0029297046 500
```

## Reproducibility

Matching-based results draw on the random number generator, so a fixed seed is
required to reproduce them. Set it explicitly — `run_pipeline(..., seed = N)`
or, for direct matching, `match_cohort(..., seed = N)` — and reuse the same
seed value to obtain identical results.
