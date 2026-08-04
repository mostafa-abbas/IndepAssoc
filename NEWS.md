# IndepAssoc (unreleased)

* BREAKING: `fit_outcome(..., method = "matching")` now uses the estimator the
  source papers used: conditional logistic regression (`survival::clogit`)
  stratified by matched pair for binary outcomes, and a within-pair
  fixed-effects linear model for continuous outcomes. Previously it fit a
  plain covariate-adjusted regression on the matched cohort. Binary-outcome
  estimates therefore change (corrected) for existing `matching` users.
  The conditional-logit fit is shared with `fit_all_models()`'s "Conditional
  logit" model so the two paths cannot drift apart.

# IndepAssoc 0.1.0 (2026-08-01)

* Confounder-adjusted association testing via propensity-score methods for
  retrospective cohort studies. Answers whether an exposure is independently
  associated with an outcome after adjusting for confounders via matching,
  weighting, stratification, or regression, and produces publication-ready
  tables and effect estimates with minimal code.
* `fit_outcome()` five-method dispatcher (`regression`, `matching`,
  `stratification`, `iptw`, `aipw`) returning a common tidy result;
  `run_pipeline(..., methods = ...)` returns a `$comparison` table;
  `subgroup_analysis()` uses the dispatcher; new `plot_comparison()` forest-plot
  helper.
  * IPTW uses manually computed stabilized weights (`P(A) / P(A | X)`) with
    robust standard errors from `sandwich::vcovHC()` on a plain weighted
    `glm`/`lm` (no `WeightIt`, no `survey`/`svyglm`).
  * AIPW is a manual Bang & Robins (2005) augmented estimator. For binary
    outcomes it returns the marginal odds ratio from augmented `E[Y(1)]` /
    `E[Y(0)]` with a delta-method log-scale SE on the influence-function
    terms; continuous returns the mean difference. Standard errors are the
    empirical influence-function SEs.
* Removed survival/time-to-event analysis (`km_logrank()` and its exports,
  NAMESPACE imports, and `time`/`event` columns). The `survival` dependency
  remains for `survival::clogit()` used in `fit_all_models()` (conditional
  logit).
* Bug fixes: `paired_wilcoxon_test()` now uses a true paired test aligned on
  `match_num`; result frames for the paired tests carry a numeric `p.value`;
  the mislabeled "doubly robust" model was removed from `fit_all_models()`;
  treatment-coefficient extraction in `model_summ()` is anchored to the
  exposure name; model confidence intervals are true Wald intervals
  (`coef +/- qnorm(0.975) * SE`) for every model class; CI bounds are no
  longer double-exponentiated; `subgroup_analysis()` warns when the subgroup
  variable was not part of the matching covariates; duplicated `match_num`
  handling consolidated into `.ensure_match_num()`.
  * The `matching` method in `fit_outcome()` fits the fully adjusted
    `glm`/`lm` on the matched cohort (not the full unmatched cohort), so
    matching estimates are no longer identical to `regression`.
* New vignettes: `applying-five-methods.Rmd` runs all five methods on
  `causaldata::nhefs` for a binary (`death`) and a continuous (`wt82_71`)
  outcome; `lalonde-benchmark.Rmd` validates `matching` and `iptw` against the
  Dehejia–Wahba experimental benchmark ($1,794) on `MatchIt::lalonde`.
* Added tests asserting all five methods recover the known simulated effect
  (binary log-OR 0.5, continuous beta 2.0) through `run_pipeline()`, plus a
  `lalonde` benchmark regression test (PSM lands closer to the $1,794
  experimental ATT than IPTW).
* Release hardening: runnable `@examples` on every help page; main vignette
  aligned to the packaged `example_cohort`; `subgroup_analysis()` honors the
  `method` argument and returns `conf_low`/`conf_high`/`p_value`;
  `export_results()` writes the method-comparison table; `R CMD check` is
  clean (0 errors, 0 warnings, 0 notes).
