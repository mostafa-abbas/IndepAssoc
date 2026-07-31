# IndepAssoc 0.1.0

* Initial release with core PSM pipeline.
* Functions: `build_ps_model()`, `match_cohort()`, `check_balance()`,
  `table_unmatched()`, `table_matched()`, `fit_outcome()`, `km_logrank()`,
  `subgroup_analysis()`, `run_pipeline()`.

## 0.1.0.9000 (development)

* Removed survival/time-to-event analysis: `km_logrank()` and its
  exports, NAMESPACE imports, and `time`/`event` columns from
  `example_cohort`. The `survival` dependency remains for
  `survival::clogit()` used in `fit_all_models()` (conditional logit).
