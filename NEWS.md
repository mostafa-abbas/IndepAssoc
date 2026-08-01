# IndepAssoc 0.1.0

* Initial release with core PSM pipeline.
* Functions: `build_ps_model()`, `match_cohort()`, `check_balance()`,
  `table_unmatched()`, `table_matched()`, `fit_outcome()`, `km_logrank()`,
  `subgroup_analysis()`, `run_pipeline()`.

## 0.1.0.9000 (development)

* New `fit_outcome()` five-method dispatcher (`regression`, `matching`,
  `stratification`, `iptw`, `aipw`) returning a common tidy result;
  `run_pipeline(..., methods = ...)` now returns a `$comparison` table;
  `subgroup_analysis()` now uses the dispatcher; new `plot_comparison()`
  forest-plot helper.
  * IPTW uses manually computed stabilized weights (`P(A) / P(A | X)`) with
    robust standard errors from `sandwich::vcovHC()` on a plain weighted
    `glm`/`lm` — no `WeightIt`, no `survey`/`svyglm` (deviation from the
    plan's Task 1–5 text, which had first adopted `survey::svyglm`; reverted
    per review to avoid a `svydesign(ids = ~1)` object and a fifth model
    class).
  * AIPW is a manual Bang & Robins (2005) augmented estimator. For binary
    outcomes it returns the marginal odds ratio from augmented `E[Y(1)]` /
    `E[Y(0)]` with a delta-method log-scale SE on the influence-function
    terms; continuous returns the mean difference. Standard errors are the
    empirical influence-function SEs, not `sandwich::vcovHC` (deviation from
    the plan's Task 6 text, which had sketched a `psi`/`theta` contrast whose
    `exp()` is not a log-OR and failed its own recovery test; the corrected
    estimator recovers the true log-OR within tolerance).
* Removed survival/time-to-event analysis: `km_logrank()` and its
  exports, NAMESPACE imports, and `time`/`event` columns from
  `example_cohort`. The `survival` dependency remains for
  `survival::clogit()` used in `fit_all_models()` (conditional logit).
* Bug fixes: `paired_wilcoxon_test()` now uses a true paired test aligned
  on `match_num`; result frames for the paired tests carry a numeric
  `p.value`; the mislabeled "doubly robust" model was removed from
  `fit_all_models()` (a real AIPW arrives in the 5-method dispatcher);
  treatment-coefficient extraction in `model_summ()` is anchored to the
  exposure name; model confidence intervals are true Wald intervals
  (`coef +/- qnorm(0.975) * SE`) for every model class instead of
  whatever `confint(..., method = "Wald")` happened to return; and the
  CI bounds are no longer double-exponentiated; `subgroup_analysis()`
  warns when the subgroup variable was not part of the matching
  covariates; duplicated `match_num` handling consolidated into
  `.ensure_match_num()`.
* Deferred to Phase 2: `fit_outcome()` multi-method dispatcher
  (referenced by `subgroup_analysis()`, which returns `NA` rows until it
  exists).
