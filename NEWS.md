# IndepAssoc 0.5.0 (2026-08-08)

## Bug fixes

* `plot_comparison()` no longer prints the plot itself: the internal `print(p)`
  side effect was removed and the `ggplot` is now returned visibly, so a bare
  call in an R Markdown chunk (or at the console) renders exactly one plot
  instead of two. Previously, the documented usage pattern — the caller wrapping
  the call in an explicit `print()` — combined with the function's internal
  `print(p)` to render two copies of every forest plot in the vignettes. Not a
  breaking change: no capability was removed and the returned object is
  unchanged (Phase 11).
* Fixed a Markdown fence mismatch in `README.md` that caused explanatory comment
  lines to render as a large heading on GitHub (Phase 14).

## New features

* New exported `format_comparison()` and `format_combined()`: display-layer
  helpers that turn a raw `$comparison` data frame into a publication-ready
  table. `format_comparison()` rounds `estimate`, `conf_low`, and `conf_high`
  to `digits` (default 2), renders the CI as a single `"low\u2013high"` en-dash
  string, formats `p_value` to `p_digits` decimals with values below the
  threshold shown as `"<0.001"` (the threshold generalizes with `p_digits`),
  labels the estimate column `OR` (binary) or `Mean Diff` (continuous) from the
  `type` column, and capitalizes method names for display (`iptw` → `IPTW`,
  `aipw` → `AIPW`). `format_combined()` handles a multi-outcome table with an
  `Outcome` column, reusing `format_comparison()` internally. Both functions
  format for display only: `export_results()`'s CSV output retains full numeric
  precision, now guaranteed by a test (Phase 15).
* `plot_asmd_balance()` gains an opt-in `top_n` parameter (default `NULL`, so
  existing callers are unchanged). When `top_n` is set, the chart shows only the
  `top_n` covariates with the largest **unadjusted (pre-matching)** ASMD — still
  with both the unadjusted and matched bars side by side — and adds a caption
  stating exactly how many of the total are shown, e.g. `"Showing 25 of 76
  covariates with the largest unadjusted ASMD"`. Strictly additive and
  backward-compatible: without `top_n` the output is byte-for-byte identical to
  before. The `rhc-validation` vignette demonstrates `top_n = 25` on the RHC
  cohort, where the full chart's x-axis labels (76 covariate levels) become
  illegible (Phases 12-13).

## Documentation and CI

* `README.md` gained a `Background` section citing the two published studies
  whose analysis pipeline this package generalizes (Heliyon, 2025; *Journal of
  Cardiothoracic Surgery*, 2024) and a `Validation` section stating the current
  unit-test count (424) and `R CMD check` status (0 errors, 0 warnings, 0
  notes). The worked example now demonstrates `format_comparison()` (Phase 14).
* All three vignettes format their comparison tables with the exported
  `format_comparison()`/`format_combined()` functions instead of vignette-local
  helpers (the duplicate helper in the `rhc-validation` vignette is deleted).
  The combined multi-outcome table in `rhc-validation` is built from the raw,
  full-precision comparison data; the exported CSV keeps full numeric precision
  (Phase 16).
* Added a GitHub Actions R-CMD-check workflow (macOS, Windows, and Ubuntu at R
  devel/release/oldrel-1) and an R-CMD-check status badge at the top of the
  README. The workflow lives at `.github/workflows/R-CMD-check.yaml` inside the
  package, so it lands at the repository root when the package is published
  standalone; `.github` is excluded from the built package via `.Rbuildignore`
  (Phases 16-17).

# IndepAssoc 0.4.0 (2026-08-07)

## Breaking changes

* Removed the exported `plot_love()`. The package now has a single ASMD
  comparison chart: `plot_asmd_balance()`, which `run_pipeline()` also returns
  as `result$balance_plot`. Callers of `plot_love()` should switch to
  `plot_asmd_balance()` with a `run_pipeline()`, `find_matching_data_summary()`,
  or `check_balance()` result.
* `fit_outcome(..., method = "iptw")` is now a plain marginal structural model:
  the outcome is regressed on the exposure only, weighted by the existing
  stabilized inverse-probability weights. It no longer also adjusts for the full
  covariate set on top of weighting (which duplicated `aipw`), so `iptw`
  estimates change for all existing users.
* `match_cohort(..., replace = TRUE)` now fails immediately at the call site
  with a clear message instead of failing downstream with the confusing
  `Matched data must contain 'match_num' or 'strata' column.` error. Use
  `find_matching_data_summary()` when replacement matching is needed.

## Bug fixes

* `paired_wilcoxon_test()` and `mcnemar_test()` handle missing outcomes and
  many:1 (`ratio > 1`) matching correctly. The paired Wilcoxon test no longer
  crashes on `NA` outcomes and now averages the multiple controls within each
  stratum so every matched row contributes; `mcnemar_test()` uses the
  Cochran-Mantel-Haenszel test over per-stratum 2x2 tables (identical to
  McNemar for 1:1 matching) instead of returning a silent `NA`. Previously extra
  control rows were silently discarded and missing outcomes could be
  misclassified.
* `subgroup_analysis()` no longer returns silent all-`NA` results: the subgroup
  variable (constant within each subgroup) is dropped from each subgroup's
  covariate set, so every adjustment method fits real estimates.
* `table_unmatched()`/`table_matched()` stop with `Covariates not found: <name>`
  instead of silently dropping unknown covariate names via `intersect()`.
* `model_summ()` selects the treatment's coefficient row by exact name match
  (or factor-level pattern) instead of fragile substring matching that could
  steal a prefix-colliding covariate's row.
* Declared `utils` in `DESCRIPTION` Imports (hygiene fix; no behavior change).

## New features

* `run_pipeline()` now returns `result$balance_plot`: a publication-ready
  grouped bar chart of absolute standardized mean differences (unadjusted vs.
  matched) drawn at the `balance_threshold` used. The plot is returned, not
  auto-rendered — print or save it yourself.
* New `find_matching_data_summary()` (standalone PSM-style balance summary
  tables plus the matched sample) and new `plot_asmd_balance()` (the chart
  above, accepting output from `run_pipeline()`, `find_matching_data_summary()`,
  or `check_balance()`).

## Detailed changes

* `run_pipeline()` now returns `result$balance_plot`: the grouped-bar ASMD chart
  (unadjusted vs. matched) produced by `plot_asmd_balance()` at the
  `balance_threshold` used. The plot is returned, not auto-rendered — print or
  save it yourself.
* Removed the exported `plot_love()` (and its man page). `plot_asmd_balance()`,
  which `run_pipeline()$balance_plot` uses, is now the package's single ASMD
  comparison plot. **Breaking change** for anyone calling `plot_love()` directly;
  pass a `run_pipeline()` result (or `find_matching_data_summary()` /
  `check_balance()` output) to `plot_asmd_balance()` instead.
* `match_cohort()` now fails fast with a clear message when called with
  `replace = TRUE`: matching with replacement does not return a match-pair
  identifier from `MatchIt::match.data()`, which the paired downstream
  functions (balance tables, paired tests, conditional-logit matching
  estimator) all require. Previously this surfaced later as the confusing
  `Matched data must contain 'match_num' or 'strata' column.` error. Use
  `find_matching_data_summary()` when replacement matching is needed. **Behavior
  change** for calls passing `replace = TRUE`.
* New `find_matching_data_summary()`: fits a propensity score model with
  `MatchIt::matchit()` and returns the standardized balance summary tables
  (`match_summ$all`/`match_summ$matched`, with a `Std. Mean Diff.` column)
  plus the matched sample — the same structure produced by the standalone
  PSM analysis scripts.
* New `plot_asmd_balance()`: publication-ready grouped bar chart of the
  absolute standardized mean difference (ASMD) for each covariate before and
  after matching. Accepts output from `find_matching_data_summary()`,
  `run_pipeline()`, or `check_balance()`. Colors are `#005A9C`
  (Unadjusted) / `#E66101` (Matched) with a dashed balance-threshold line;
  unrecognized inputs error with `Invalid matching result object provided.`,
  and an all-filtered covariate set degrades to a warning plus an empty plot
  shell.
* `model_summ()` (used by `fit_outcome()` and `fit_all_models()`) now selects
  the treatment's coefficient rows by exact name match, or — for a factor
  exposure — by the factor levels recovered from the model frame
  (`<feature><level>`), instead of substring-matching coefficient names. A
  covariate whose name shares the exposure name as a prefix (e.g. `age_group`
  alongside exposure `age`) can no longer steal the treatment row. A treatment
  with no coefficient row in the model now errors with `No coefficient row
  found for treatment feature '<name>'` instead of silently returning the
  second coefficient (typically the intercept-adjusted row). **Behavior
  change** for models where the exposure term was missing or its name was
  shadowed by a prefix-colliding covariate.
* `table_unmatched()` and `table_matched()` now validate `covariates` against
  the data, stopping with `Covariates not found: <name>` when given an
  unknown covariate name — the same behavior and message format as
  `build_ps_model()` and `fit_outcome()`. Previously they silently dropped
  bogus names via `intersect()`, quietly changing which covariates were
  summarized. **Behavior change**: a typo'd covariate name now errors instead
  of being silently ignored in these two functions.
* `fit_outcome(..., method = "iptw")` is now a plain marginal structural
  model: the outcome model regresses on the exposure only (`outcome ~
  exposure`), weighted by the existing stabilized inverse probability of
  treatment weights, with robust `sandwich` standard errors. Previously it
  regressed the outcome on the exposure *and* the full covariate set on top
  of weighting, which duplicated `aipw`'s doubly-robust role. `iptw` now
  controls confounding through the weights alone and is genuinely distinct
  from `aipw` (the Bang & Robins augmented estimator). **Behavior change**:
  `iptw` binary and continuous estimates change for all existing users.
  Known-effect simulation tests confirm `iptw` still recovers the known
  effect within the existing tolerances.
* `utils` is now declared in `DESCRIPTION` `Imports` (it was used via
  `utils::read.csv`/`write.csv`/`tail` in `R/data_helpers.R`, `R/utils.R`,
  and `R/tests_stat.R` but not listed). No behavior change. Note: `R CMD
  check` does not flag this on current R because `utils` is a recommended
  package, so this is a hygiene/future-proofing fix rather than a check
  cleanup.
* `subgroup_analysis()` no longer passes the full covariate set (including
  the subgroup variable itself) into each subgroup's model. The subgroup
  variable is constant within a subgroup, so keeping it made `glm()` error
  with "contrasts can be applied only to factors with 2 or more levels" and
  every adjustment method returned all-`NA` rows. The subgroup variable is
  now dropped from the covariate set (with a `message()`), so subgroup
  analyses complete with real estimates. The `matching` method also now
  strips MatchIt output columns (`distance`/`weights`/`subclass`) before
  re-matching a subgroup, avoiding a "distance is already the name of a
  variable" collision. **Behavior change** for subgroup analyses where the
  subgroup variable is also a matching covariate.
* `paired_wilcoxon_test()` no longer crashes on continuous outcomes with
  missing values (e.g. `rhc_sample$los`): descriptive quantiles now use
  `na.rm = TRUE`, and strata (pairs) missing an observed outcome on either
  side are dropped before the paired test, with the number dropped reported
  via a `message()`.
* `paired_wilcoxon_test()` now supports many:1 matching (`ratio > 1`): the
  outcome is averaged over the multiple controls within each stratum before
  differencing, so every matched row contributes to the test. Previously the
  extra control rows were silently discarded (on `rhc_sample` at `ratio = 2`,
  566 of 2,251 control rows went unused with no warning). **Behavior change**
  for `ratio > 1` cohorts.
* `mcnemar_test()` now uses the Cochran-Mantel-Haenszel test
  (`stats::mantelhaen.test()`) over per-stratum 2x2 tables instead of
  `rstatix::pairwise_mcnemar_test()`. For 1:1 matching this is identical to
  McNemar's test, and it generalizes correctly to many:1 matching (which
  previously returned a silent `NA` result). **Behavior change** for
  `ratio > 1` cohorts and for cohorts with missing outcomes.
* `mcnemar_test()` now validates that the outcome is binary coded 0/1 and the
  exposure is binary, and excludes rows with missing outcomes from the test
  (reported via a `message()`), instead of misclassifying missing values as a
  third outcome level.
* `rstatix` removed from Imports (no longer used).

# IndepAssoc 0.3.0 (2026-08-05)

* Data architecture: raw-data generation is consolidated in `data-raw/`
  (`simulate_example_cohort.R`, `prepare_rhc.R`); the cleaned RHC cohort now
  ships as the bundled, documented `rhc_sample` dataset (a list of the 5735-row
  data frame and its 50-column covariate vector) so vignettes and tests run
  offline and deterministically. The redundant `rhc_data/` folders were
  removed and `prepare_rhc_data()` moved to `R/data_helpers.R`.
* Vignettes reorganized into three: `indepassoc-quickstart.Rmd`,
  `causal-benchmarks.Rmd` (NHEFS and Lalonde), and `rhc-validation.Rmd`
  (Connors et al. RHC benchmark). The RHC vignette now loads the bundled
  dataset and keeps its directional comparison against Connors et al. (1996)
  with the standard no-unmeasured-confounding caveat.
* Documentation tone pass across README, NEWS, and help pages: direct,
  clinical framing focused on confounder control and the trade-offs among
  the five adjustment methods.
* Test suite now runs with zero warnings: `tbl_summary()` calls use
  `tidyselect::all_of()` for external-vector selectors (removing the
  tidyselect 1.1.0 deprecation, `tidyselect` added to Imports), `tbl_merge()`
  merges quietly, and incidental statistical warnings (MatchIt unmatched
  treated units, non-convergence, singular variance) are suppressed or
  explicitly expected in the tests. Still `FAIL 0 | WARN 0 | SKIP 0 | PASS 268`.

# IndepAssoc 0.2.0 (2026-08-04)

* BREAKING: `fit_outcome(..., method = "matching")` now uses the estimator the
  source papers used: conditional logistic regression (`survival::clogit`)
  stratified by matched pair for binary outcomes, and a within-pair
  fixed-effects linear model for continuous outcomes. Previously it fit a
  plain covariate-adjusted regression on the matched cohort. Binary-outcome
  estimates therefore change (corrected) for existing `matching` users.
  The conditional-logit fit is shared with `fit_all_models()`'s "Conditional
  logit" model so the two paths cannot drift apart.
* `fit_all_models()` no longer crashes the pipeline when a matched subset's
  outcome is constant (single-valued): degenerating models degrade to `NA`
  results with a warning instead of erroring, and `run_pipeline()` still
  returns comparison rows for the models that fit. (Surfaced by the RHC data,
  where a longer-term mortality coding can collapse to a constant response in
  matched subsets; the RHC vignette therefore uses `dth30`, the true 30-day
  mortality.)
* New `seed` parameter on `run_pipeline()`, `match_cohort()`, and
  `fit_outcome()`: when non-`NULL` it is applied before matching so results are
  reproducible. `?run_pipeline` documents that a seed is required to reproduce
  matching-based results.
* New exported `prepare_rhc_data()` helper: encodes the RHC CSV's preprocessing
  quirks (a `write.csv` row-names column, the `cat2` literal `"NA"` that really
  means the "None" category, literal `"NA"` missingness, text-to-numeric
  recodes of `swang1`/`dth30`/`death`, a derived `los`, and no `cost` column)
  and returns a 50-column covariate vector. New network-guarded vignette
  `vignettes/rhc-validation.Rmd` runs all five methods on `dth30` and `los`
  with a fixed seed; all five find RHC associated with increased 30-day
  mortality and longer length of stay, directionally consistent with
  Connors et al. (1996).

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
