# IndepAssoc 0.1.0

* Initial release with core PSM pipeline.
* Functions: `build_ps_model()`, `match_cohort()`, `check_balance()`,
  `table_unmatched()`, `table_matched()`, `fit_outcome()`, `km_logrank()`,
  `subgroup_analysis()`, `run_pipeline()`.

## 0.1.0.9000 (development)

* New `fit_outcome()` five-method dispatcher (`regression`, `matching`,
  `stratification`, `iptw`, `aipw`) returning a common tidy result; new
  dependencies `survey` (IPTW robust SE) and `sandwich` (AIPW robust SE);
  `run_pipeline(..., methods = ...)` now returns a `$comparison` table;
  `subgroup_analysis()` now uses the dispatcher; new `plot_comparison()`
  forest-plot helper.
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
