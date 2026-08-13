# IndepAssoc — Bug Fixes & RHC Real-Data Validation Plan

> Working spec for OpenCode. Follow phase by phase, in order. Each phase
> should go through the repo’s established process: git worktree →
> design spec → implementation plan → TDD (failing test first) → review
> → checkpoint with the user before merging. Do not skip ahead to a
> later phase before the current one is merged to `main`.

## Context

`IndepAssoc` is an R package documenting and generalizing the
propensity-score-based analysis pipeline used in two published
retrospective cohort studies (CABG sex-differences study; LAAC/POAF
study), extended to a 5-method confounding-adjustment dispatcher
([`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md):
`regression`, `matching`, `stratification`, `iptw`, `aipw`). The package
is tagged at `v0.1.0` on `main`, with `R CMD check` clean (0
errors/warnings/ notes) and 182 passing tests.

Manual real-data testing since the `v0.1.0` tag surfaced two real issues
and one opportunity, described below.

------------------------------------------------------------------------

## Phase 1 — Fix: `matching` method does not reflect the estimator actually used in

## the source papers

### The problem

Both source papers (CABG sex-differences, LAAC/POAF) used **conditional
logistic regression**
([`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html))
on the matched-pairs cohort as their primary matched-analysis estimator
— conditioning out the matched stratum, which controls for any
confounder (measured or unmeasured) that is constant within a matched
pair.

The current
[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
dispatcher’s `matching` method (implemented in `.fit_matching()`,
`R/fit_outcome.R`) instead fits a **plain covariate-adjusted regression
on the matched cohort**, without conditioning on pair structure. This is
a real, meaningful discrepancy from what the source papers published —
verified directly on the RHC dataset, where the two estimators disagree
by a non-trivial margin (e.g., plain matched-regression: OR 2.52
vs. conditional logit: OR 2.18 on one outcome in earlier testing). This
gap traces back to an earlier bug fix (making `.fit_matching()` use the
matched cohort at all, instead of the full unmatched sample) that solved
the sample-selection bug but did not restore the pair-conditioning
estimator the papers actually used.

### The fix

- For **binary outcomes**: `.fit_matching()` should fit
  [`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html)
  on the matched pairs (conditioning on `match_num`/`strata`),
  consistent with
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)’s
  existing “Conditional logit” model in `R/outcome.R`. Do not duplicate
  the `clogit()` call logic — factor it into one shared internal helper
  used by both
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)’s
  `matching` method and
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)’s
  conditional-logit model, so the two code paths cannot silently drift
  apart again.
- For **continuous outcomes**: use an estimator that accounts for the
  paired structure — e.g., a linear model with `match_num` as a
  stratifying/clustering term (matching the spirit of a paired
  analysis), not a plain unpaired regression on the matched sample.
  Document the exact estimator chosen and why.
- Add a regression test asserting
  `fit_outcome(..., method = "matching")`’s binary- outcome estimate is
  numerically identical (or matches within a documented tolerance) to
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)’s
  “Conditional logit” estimate on the same data — this is the test that
  guards against the two paths drifting apart again in the future.
- Update the
  README/vignettes/[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  documentation to describe `matching` as “propensity-score matching
  with conditional-logit/paired estimation,” and remove any language
  that could be read as claiming it’s a plain regression on the matched
  sample.

### Acceptance

- `fit_outcome(..., method = "matching")` uses conditional logit for
  binary outcomes, a pair-aware estimator for continuous outcomes.
- New test confirms `matching` and
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)’s
  conditional-logit model agree.
- No other method (`regression`, `stratification`, `iptw`, `aipw`) is
  touched by this phase.

------------------------------------------------------------------------

## Phase 2 — Fix: `fit_all_models()` mixed-effects model can crash the whole pipeline

### The problem

Running the full pipeline on the RHC dataset (`swang1` exposure, `dth30`
binary outcome, ~48 covariates, ~5,700 patients) produced:

    Warning: glm.fit: algorithm did not converge
    Error: Response is constant

at the “Fitting all outcome models” step, which **halted the entire
pipeline run** — not just that one model. This is almost certainly
[`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html)’s “Mixed
effect logistic” model inside
[`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
(`R/outcome.R`) failing because the binary outcome has no variability in
some subset it’s being fit against after matching. The same run
succeeded on a repeat attempt with a different (unseeded) random
matching draw, meaning **this is a real, non-deterministic edge case,
not a fluke** — it depends on which specific matched pairs `MatchIt`
happens to select.

### The fix

- **Investigate first, before patching.** Reproduce the failure
  directly: build the PS model and matched cohort for the RHC data with
  a fixed seed that reproduces the crash (if it cannot be reproduced
  deterministically, construct a minimal synthetic repro — e.g., a
  matched cohort where one exposure arm has a constant outcome in some
  subgroup relevant to the `glmer` random-intercept structure). Identify
  precisely *why* the response is constant in the subset `glmer` sees —
  do not guess; confirm with
  [`table()`](https://rdrr.io/r/base/table.html)/print output on the
  actual matched data being passed to the model.
- Once the mechanism is understood: make the mixed-effects model **fail
  gracefully**, not fatally. Wrap its fit in the same pattern already
  used for other model-quality issues (`tryCatch`), returning `NA` for
  that one model’s row with a
  [`warning()`](https://rdrr.io/r/base/warning.html) explaining why
  (mirroring the pattern already established in
  [`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)’s
  fit-failure handling) — the other two models in
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
  (fully adjusted, conditional logit) and the rest of the pipeline
  should continue unaffected.
- Add a regression test using a constructed dataset that deliberately
  reproduces a constant-response subset, asserting: (a)
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
  does not throw, (b) the mixed-effects row is `NA` with an accompanying
  warning, (c) the other two models still return valid estimates.

### Acceptance

- The exact failure mechanism is documented (in code comments and the
  ledger/plan doc), not just patched blind.
- [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
  never throws a fatal, pipeline-halting error due to this cause.
- New test reproduces the failure mode deterministically and confirms
  graceful degradation.

------------------------------------------------------------------------

## Phase 3 — Reproducibility: seeding for matching-based methods

### The problem

[`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
(via `MatchIt`) involves random tie-breaking, but nothing in the package
enforces, documents, or reminds the caller to set a seed. This makes
`matching`, and any method downstream of it, non-reproducible run-to-run
— which is exactly what let Phase 2’s crash appear on one run and not
the next, and which undermines any specific numeric result being citable
without also citing an exact seed.

### The fix

- Add an explicit `seed` argument to
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  (and, if natural, to
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
  directly) that, when provided, calls
  [`set.seed()`](https://rdrr.io/r/base/Random.html) internally before
  any matching-dependent step. Default `NULL` (no forced seeding,
  preserving existing behavior) but document prominently — in
  [`?run_pipeline`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md),
  the README, and both real- data vignettes — that a seed is required
  for reproducible results whenever `matching` is among the requested
  methods.
- Update the `nhefs`/`lalonde` vignettes (and the new RHC vignette from
  Phase 4) to explicitly set and report the seed used, if they don’t
  already.

### Acceptance

- `run_pipeline(..., seed = <value>)` produces identical
  `matching`/downstream results across repeated runs.
- Documentation clearly states the reproducibility requirement.

------------------------------------------------------------------------

## Phase 4 — RHC as a validated real-data benchmark

[Right Heart Catheterization
dataset](https://hbiostat.org/data/repo/rhc.csv) — from the original
Connors et al. 1996 JAMA study, one of the most widely cited propensity-
score-matching examples in the causal inference literature. This becomes
a third real-data vignette, alongside the existing `nhefs` and `lalonde`
ones, and is the most directly relevant validation dataset the package
has been tested against, since it’s a genuine retrospective clinical
cohort with a binary exposure and multiple outcome types — structurally
the closest public dataset to the CABG/LAAC/POAF study designs this
package was built to generalize.

### Known preprocessing requirements (established through manual testing — encode

### these as a reusable helper, not vignette-only prose)

1.  **NA encoding is unreliable via
    [`read.csv()`](https://rdrr.io/r/utils/read.table.html) defaults.**
    The file’s missing values and the `cat2` column’s literal `"NA"`
    text (meaning “no secondary diagnosis,” a real category, not
    missingness) cannot be reliably disambiguated through `na.strings`
    alone — confirmed empirically across two failed attempts. The robust
    approach: read all columns as raw character text with NA-detection
    disabled, fix `cat2`‘s `"NA"` → `"None"` first, then convert all
    other columns’ literal `"NA"` text to real `NA`, then re-type the
    genuinely numeric columns.
2.  **Exposure (`swang1`) is text** (`"RHC"` / `"No RHC"`), requires
    explicit 0/1 recoding.
3.  **Two mortality-like columns exist and mean different things**:
    `death` (long-term/ all-cause — confirmed via cross-tab: every
    `dth30 = Yes` patient has `death = Yes`, but not vice versa)
    vs. `dth30` (true 30-day mortality). Use `dth30` for any “30-day
    mortality” claim; document `death` as a separate, valid, longer-term
    outcome, not a synonym.
4.  **`los` (length of stay) is not a column in this file** — derive it
    as `dschdte - sadmdte`.
5.  **`cost` is not present in this file at all** — do not fabricate it;
    omit this outcome or note it requires an external data source.
6.  **`adld3p` (74.9% missing) and `urin1` (52.8% missing)** must be
    excluded from the covariate set — including either collapses the
    complete-case sample from 5,735 to 634 patients. The remaining
    ~48-covariate set retains the full sample.

### Implementation

- Add a documented (not necessarily exported) helper,
  e.g. `prepare_rhc_data(path)`, encoding steps 1–5 above, so this
  hard-won data-cleaning logic lives in one tested function rather than
  being re-derived by hand every time. Add unit tests for it using a
  small synthetic CSV that reproduces the `cat2`-“NA” and numeric-“NA”
  encoding quirks, so the parsing logic is regression-tested without
  depending on downloading the real file during `R CMD check`.
- Add `vignettes/rhc-validation.Rmd`: download (or reference a
  documented local path for) the RHC data, run the preprocessing helper,
  run
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  with all 5 methods for at least `dth30` (binary) and `los`
  (continuous), with a fixed `seed` (Phase 3) for reproducibility. Guard
  network-dependent chunks the same way the `nhefs` vignette guards
  `causaldata` (`requireNamespace`/reachability check with a graceful
  skip), so `R CMD check` and CI don’t hard-fail without network access.
- Interpret the results **directionally against the published
  literature, not by asserting an exact numeric match**: Connors et
  al. 1996 and the substantial body of RHC reanalyses since have
  consistently found RHC associated with *increased* mortality (harm),
  not benefit. State that the package’s results are directionally and
  qualitatively consistent with this literature (all methods agreeing on
  direction and significance), without claiming to exactly reproduce any
  specific published point estimate — that claim would need to be
  checked against the actual published number, which has not been done
  as part of this plan.
- Include the same causal-language caveat used in the other vignettes
  (confounder- adjusted association under the no-unmeasured-confounding
  assumption, not proven causation).

### Acceptance

- [`prepare_rhc_data()`](https://mostafa-abbas.github.io/IndepAssoc/reference/prepare_rhc_data.md)
  (or equivalent) exists, is tested, and correctly reproduces the known
  preprocessing findings above.
- `vignettes/rhc-validation.Rmd` builds successfully (network-guarded),
  runs all 5 methods on at least one binary and one continuous RHC
  outcome, with a fixed seed.
- The vignette explicitly states its literature comparison is
  directional, not an exact-value claim.

------------------------------------------------------------------------

## Phase 5 — Verification & release

- Full test suite green, including all new tests from Phases 1–4.
- `R CMD check` clean (0 errors/warnings, or documented exceptions
  consistent with the project’s existing standard).
- All three real-data vignettes (`nhefs`, `lalonde`, `rhc`) build
  successfully.
- Update `NEWS.md` documenting: the `matching` method’s estimator change
  (this is a behavior change worth calling out explicitly, since anyone
  who already used `method = "matching"` on a binary outcome will get a
  different, corrected number), the
  [`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
  crash fix, the new `seed` parameter, and the new RHC vignette/helper.
- Checkpoint with the user before any version bump/tag — this plan
  includes at least one real behavior change (Phase 1), so consider
  whether it warrants a `0.2.0` minor version bump rather than a patch
  release, given semantic versioning conventions (behavior change to an
  existing public method’s output).

------------------------------------------------------------------------

## Definition of done

`matching` method uses conditional logit (binary) / pair-aware
estimation (continuous), verified consistent with
[`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)’s
conditional-logit model.

[`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
no longer crashes the pipeline on constant-response subsets; failure
mode is documented and gracefully handled.

[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
supports an explicit `seed` parameter; reproducibility is documented.

RHC preprocessing is encoded in a tested helper function, not one-off
vignette code.

`vignettes/rhc-validation.Rmd` exists, builds (network-guarded), and
reports results directionally consistent with the published RHC
literature.

Full suite green, `R CMD check` clean, `NEWS.md` updated, version-bump
decision checkpointed with the user before tagging.
