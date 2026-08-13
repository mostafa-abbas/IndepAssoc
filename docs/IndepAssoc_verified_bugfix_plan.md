# IndepAssoc — Verified Bug-Fix Plan (post-v0.3.0 code review + RHC validation)

> Working spec for OpenCode. Follow phase by phase, in order. Each
> phase: git worktree → failing regression test first (reproducing the
> exact bug below) → fix → confirm the test now passes → run full
> suite + `R CMD check` → commit → checkpoint with the user before
> moving to the next phase. Do not batch multiple phases into one
> commit.
>
> Every finding below was independently reproduced on the real installed
> package (`v0.3.0`) against the bundled `rhc_sample` data (5,735 rows,
> 50 covariates, exposure `swang1`) via a standalone verification
> script, not just inferred from reading the source. Specific
> counts/output are quoted where useful so the fix can be checked
> against the same numbers.

## Context

`IndepAssoc` is at `v0.3.0`. A manual code review followed by scripted
verification against `rhc_sample` surfaced six confirmed issues, two of
which are more severe than originally suspected: one is a hard crash on
real data (not just silent data loss), and one is a complete,
silently-unreported analysis failure. Fix all six before any further
feature work (vignettes, new methods, docs polish) — several of the
existing planning docs in this repo describe forward-looking work (RHC
vignette, method dispatcher extensions, documentation polish) that
should not proceed until this plan is merged, since some of that work
exercises exactly the broken code paths below.

------------------------------------------------------------------------

## Phase 1 — Fix: `paired_wilcoxon_test()` crashes on real data with missing outcomes

### The problem

Two separate defects in the same function (`R/tests_stat.R`):

1.  **Hard crash on any outcome with `NA`s.** The per-group summary
    block calls `quantile(sub[[outcome]])` with no `na.rm = TRUE`. On
    `rhc_sample`, `los` has `NA`s (patients with missing
    admission/discharge dates), so calling
    `paired_wilcoxon_test(matched_data, "los", "swang1")` on any matched
    cohort with such a patient throws:

        Error in quantile.default(sub[[outcome]]) :
          missing values and NaN's not allowed if 'na.rm' is FALSE

    This is not an edge case — it reproduces on a real, standard
    clinical dataset with ordinary missingness, using the package’s own
    bundled example data.

2.  **Silent data loss under `ratio > 1` matching.** Pairing logic does:

    ``` r
    common <- intersect(g1$match_num, g2$match_num)
    v2 <- g2[[outcome]][match(common, g2$match_num)]
    ```

    [`match()`](https://rdrr.io/r/base/match.html) returns only the
    *first* matching row per `match_num`. Confirmed on `rhc_sample` with
    `ratio = 2`: 566 matched pairs realized both controls (1,132 control
    rows), but only 1,685 of the 2,251 total control rows were used by
    the function — 566 matched control rows silently discarded, no
    warning.

### The fix

- Add `na.rm = TRUE` to every
  [`quantile()`](https://rdrr.io/r/stats/quantile.html)/summary call in
  this function, and decide (and document) how paired cases with a
  missing outcome on either side of the pair are handled: the current
  design implicitly assumes complete pairs. The most defensible fix is
  to drop incomplete pairs before the paired test (a pair missing either
  observation cannot contribute to a paired comparison) and report how
  many pairs were dropped, e.g. via a
  [`message()`](https://rdrr.io/r/base/message.html) or an attribute on
  the returned data frame — not silently.
- For `ratio > 1`: either (a) error clearly if `ratio > 1` is passed,
  stating paired Wilcoxon assumes 1:1 pairing and pointing the user to
  [`mcnemar_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/mcnemar_test.md)’s
  docs or a future many:1-aware estimator, or (b) implement a proper
  many:1 paired comparison (e.g., average the multiple controls per
  stratum before differencing, or use a stratified/weighted signed-rank
  approach) — pick one, document why, and make the chosen behavior
  explicit rather than the current silent truncation either way.
- Same audit for
  [`mcnemar_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/mcnemar_test.md)
  (`R/tests_stat.R`): confirm whether it has the same `ratio > 1` and
  `NA`-handling gaps (it wasn’t confirmed broken in the same way, but it
  shares the same pairing assumptions and hasn’t been checked against
  `NA`s or `ratio > 1`) — add regression tests either way.

### Regression tests to add

- [`paired_wilcoxon_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/paired_wilcoxon_test.md)
  on a small synthetic matched dataset with an `NA` in one outcome
  value: must not throw; must produce a documented, correct result (not
  a silently wrong one).
- [`paired_wilcoxon_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/paired_wilcoxon_test.md)
  with `ratio = 2` matching where at least one pair has 2 realized
  controls: assert the chosen ratio\>1 behavior explicitly (either the
  informative error, or that all matched observations are actually used
  — write the test to fail under the current silent-truncation
  behavior).
- Same two test shapes for
  [`mcnemar_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/mcnemar_test.md).
- A test running
  [`paired_wilcoxon_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/paired_wilcoxon_test.md)
  directly against `rhc_sample$data` (matched on `swang1` with default
  1:1) with outcome `los`, asserting it completes without error — this
  is the exact real-data repro case, use it as a standing regression
  guard.

### Acceptance

- `paired_wilcoxon_test(matched_rhc_data, "los", "swang1")` completes
  without error on the real `rhc_sample` data, 1:1 and `ratio = 2`.
- No matched observation is silently dropped without either an error or
  a reported count.

------------------------------------------------------------------------

## Phase 2 — Fix: `subgroup_analysis(..., method = "matching")` fails completely and silently on real data

### The problem

Running
`subgroup_analysis(matched_rhc, "dth30", "sex", type = "binary", method = "matching")`
on the RHC cohort returned `NA` for **every** subgroup (`Male`,
`Female`) — a complete analysis failure, not a partial one. Per
`R/subgroup.R`, this should have triggered a
`warning("Subgroup '<g>' failed to fit: ...")` inside the function’s own
`tryCatch`, but no such warning was observed in the run that produced
the all-`NA` output. That gap between “should warn” and “did not visibly
warn” needs to be resolved as part of this fix, not just the underlying
`NA`s.

### The fix — investigate before patching

- Reproduce directly, isolating `fit_outcome(..., method = "matching")`
  on the actual per-sex subset that
  [`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)
  constructs (not a synthetic stand-in), with `options(warn = 1)` so
  nothing is deferred/buffered. Identify the actual error or condition
  thrown inside `.fit_matching()` for this subset — likely candidates to
  rule in/out, in order of likelihood given the RHC covariate set and
  per-sex subgroup sizes:
  - [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)
    or
    [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
    failing/erroring on the subset (e.g. `sex` being included as a
    covariate in the PS model despite being constant within the subgroup
    — see Phase 2b below — or a near-perfect-separation `glm.fit`
    warning that doesn’t itself error but produces degenerate propensity
    scores).
  - [`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html)
    failing to converge or throwing on the subset’s matched pairs.
  - The error being thrown somewhere
    [`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)’s
    `tryCatch` doesn’t actually catch (e.g. a condition class mismatch,
    or the failure happening in a
    [`message()`](https://rdrr.io/r/base/message.html)/
    non-[`stop()`](https://rdrr.io/r/base/stop.html) path that produces
    `NA` without ever entering the `error =` handler).
- Do not guess; confirm with direct output
  (`tryCatch(..., error = function(e) e, warning = function(w) w)` on
  the isolated subset, and
  [`table()`](https://rdrr.io/r/base/table.html)/[`str()`](https://rdrr.io/r/utils/str.html)
  on what’s actually being passed to
  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)/[`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)/`.fit_matching()`).
- Once the mechanism is confirmed, fix it at its actual source, and
  separately confirm
  [`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)’s
  error handling correctly surfaces whatever this failure mode is — if
  the investigation shows the
  `tryCatch`/[`warning()`](https://rdrr.io/r/base/warning.html) plumbing
  itself has a gap (condition class, `call.` suppression, or similar),
  fix that too; a failed subgroup must never come back as a plain `NA`
  with no diagnostic trail.

### Phase 2b — related design issue to resolve in the same phase

[`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)
currently passes the *full* covariate set (including `subgroup_var`
itself, when relevant) into
[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
for each subgroup subset, where `subgroup_var` is now constant. Decide
and implement one of: - Automatically drop `subgroup_var` from the
covariate set passed to
[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
within each subgroup (it can’t be a confounder within a subset where
it’s constant), or - Leave it in but confirm and document that this
never causes the kind of hard failure found above (only, at worst, an
aliased/`NA` coefficient for that one term, unrelated to the exposure’s
own estimate).

### Regression tests to add

- A test reproducing this exact failure mode (real or minimal synthetic
  data structured like the RHC subset that failed) that currently
  returns all-`NA` with `method = "matching"`; after the fix, assert
  real (non-`NA`) estimates for both subgroups, or — if a genuine,
  unavoidable statistical failure (e.g. one subgroup’s matched cohort is
  too small/degenerate to fit at all) — assert that the returned `NA`
  row is accompanied by a specific, visible warning naming the actual
  cause.
- A test confirming
  [`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)’s
  `tryCatch` does surface warnings/errors from deep inside
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)’s
  call stack (not just top-level errors raised directly in
  [`subgroup_analysis()`](https://mostafa-abbas.github.io/IndepAssoc/reference/subgroup_analysis.md)
  itself).

### Acceptance

- `subgroup_analysis(matched_rhc, "dth30", "sex", type = "binary", method = "matching")`
  either returns real estimates for both sexes, or returns `NA` with a
  specific, correctly surfaced warning explaining exactly why — never a
  silent `NA`.

------------------------------------------------------------------------

## Phase 3 — Fix: `DESCRIPTION` missing `utils` in `Imports`

### The problem

`NAMESPACE` contains `importFrom(utils, read.csv)` and
`importFrom(utils, write.csv)` (used in `R/data_helpers.R` and
`R/utils.R`), but `DESCRIPTION`’s `Imports:` field does not list
`utils`. Confirmed directly: `packageDescription("IndepAssoc")$Imports`
omits it while the `NAMESPACE` import lines are present.

### The fix

- Add `utils` to `DESCRIPTION`’s `Imports:` field.
- Run `R CMD build IndepAssoc/ && R CMD check IndepAssoc_*.tar.gz` and
  confirm this removes the corresponding NOTE/WARNING about an
  undeclared package dependency (paste the before/after `R CMD check`
  output into the commit message or PR description as evidence, since
  this is otherwise invisible to `testthat`).

### Acceptance

- `R CMD check` no longer flags `utils` as an undeclared dependency.

------------------------------------------------------------------------

## Phase 4 — Resolve: `iptw` method regression-adjusts on top of weighting

### The problem

Confirmed via
`formula(fit_outcome(rhc, "swang1", covariates, "dth30", type = "binary", method = "iptw")$model)`:
the fitted model is `dth30 ~ swang1 + cat1 + cat2 + ... + income` (all
50 covariates), fit with IPT weights. A standard IPTW / marginal
structural model estimator regresses `outcome ~ exposure` *only*,
relying on the weights alone to balance confounders; regressing on the
full covariate set on top of weighting is a different
(doubly-robust-style) estimator that substantially overlaps with what
`aipw` already does, and is not what “iptw” would be understood to mean
by a reader of the methods section.

### The fix (requires a decision, not just a patch — checkpoint with the user first)

Two defensible resolutions; pick one and document the reasoning in
`NEWS.md` and the function’s roxygen docs:

- **(a) Make `iptw` a plain marginal structural model**:
  `outcome ~ exposure`, weighted only, sandwich/robust SE. This makes
  `iptw` and `aipw` genuinely distinct methods on the comparison table,
  matching standard terminology.
- **(b) Keep the covariate-adjusted weighted model, but
  rename/re-document it** as what it actually is (a
  weighted/doubly-adjusted estimator), and keep `aipw` as the “real”
  doubly robust estimator using the Bang & Robins augmented formula it
  already implements — in which case, explain in the docs why both exist
  and how they differ (e.g. `aipw` uses the formal augmentation term
  with the influence-function-based variance; this method is a simpler
  “belt and suspenders” weighted regression).

This is a **behavior change to a public method’s output** if (a) is
chosen — flag it in `NEWS.md` as such regardless of which option is
picked, the same way the `matching` estimator change was flagged in the
`rhc_fixes_plan.md` precedent.

### Regression tests to add

- A test asserting the `iptw` model’s formula matches whichever
  resolution was chosen (either `outcome ~ exposure` only, or the full
  covariate set — pinning it explicitly so this doesn’t drift silently
  again).
- If (a): re-run the “known binary/continuous treatment effect”
  simulation tests already in `test-known-effect.R` and confirm `iptw`
  still recovers the known effect within tolerance under the simplified
  specification.

### Acceptance

- The `iptw` and `aipw` methods are each implementing what their names
  claim, and the difference between them is explicit in the docs.

------------------------------------------------------------------------

## Phase 5 — Fix: inconsistent covariate validation across functions

### The problem

Confirmed directly:
`table_unmatched(rhc, "swang1", c(covariates[1:3], "not_a_real_column"))`
runs to completion, silently dropping the bogus name (via
`intersect(covariates, names(data))` in `R/tables.R` and
`R/tables_matched.R`), while
`build_ps_model(rhc, "swang1", c(covariates[1:3], "not_a_real_column"))`
correctly errors with `"Covariates not found: not_a_real_column"`. A
typo’d covariate name currently fails loudly in some entry points and
silently changes the analysis (fewer covariates adjusted for, with no
indication) in others.

### The fix

- Make
  [`table_unmatched()`](https://mostafa-abbas.github.io/IndepAssoc/reference/table_unmatched.md)
  and
  [`table_matched()`](https://mostafa-abbas.github.io/IndepAssoc/reference/table_matched.md)
  validate covariates the same way
  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)/[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
  do: [`stop()`](https://rdrr.io/r/base/stop.html) listing the missing
  names, rather than silently using
  [`intersect()`](https://rdrr.io/r/base/sets.html).
- Grep the rest of the package for other uses of
  `intersect(covariates, names(data))` or similar silent-drop patterns
  and apply the same fix everywhere for consistency.

### Regression tests to add

- [`table_unmatched()`](https://mostafa-abbas.github.io/IndepAssoc/reference/table_unmatched.md)/[`table_matched()`](https://mostafa-abbas.github.io/IndepAssoc/reference/table_matched.md)
  with a bogus covariate name: assert an error listing the missing name
  (mirroring the existing
  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)
  test for the same input).

### Acceptance

- Every exported function taking a `covariates` argument behaves
  identically (errors, same message format) when given an unknown
  covariate name.

------------------------------------------------------------------------

## Phase 6 — Harden: fragile coefficient-row matching in `model_summ()`/`.wald_confint()`

### The problem

[`model_summ()`](https://mostafa-abbas.github.io/IndepAssoc/reference/model_summ.md)
(`R/outcome.R`) locates the exposure’s coefficient row via
`grep(paste0("^", treatment_feature), rownames(summ_coeff))`, taking
`[1]` of whatever matches, with a fallback assuming the exposure is the
*second* row if nothing matches. Not confirmed to have misfired on the
current test/RHC data, but it’s a latent correctness risk: any covariate
name sharing the exposure name as a literal prefix (or any exposure fit
as a multi-level factor, expanding to multiple contrast rows) can pick
the wrong row silently, since
[`grep()`](https://rdrr.io/r/base/grep.html) pattern-matches rather than
doing an exact/ anchored lookup against the model’s actual term
structure.

### The fix

- Replace the [`grep()`](https://rdrr.io/r/base/grep.html)-based lookup
  with a match against the model’s actual term structure (e.g. via
  [`stats::terms()`](https://rdrr.io/r/stats/terms.html)/coefficient
  names known to correspond to the exposure term specifically, or an
  exact `rownames(summ_coeff) == treatment_feature` check first, falling
  back to an anchored regex only for expanded factor-level names like
  `^treatment_feature` immediately followed by a level suffix, not an
  arbitrary suffix).
- Explicitly handle (or explicitly document as unsupported, with a clear
  error) the case of a multi-level factor exposure expanding to multiple
  coefficient rows — decide whether
  [`model_summ()`](https://mostafa-abbas.github.io/IndepAssoc/reference/model_summ.md)
  should return all expanded rows or require a binary/two-level
  exposure, and enforce that decision with a check rather than leaving
  it implicit.

### Regression tests to add

- A synthetic case where a covariate name is a literal prefix of the
  exposure name (or vice versa), asserting the correct row is selected.
- A case with a 3+ level factor exposure, asserting either correct
  multi-row output or a clear, intentional error (per whichever design
  decision is made above).

### Acceptance

- Coefficient-row selection is exact/anchored, not substring-matched,
  and multi-level factor exposures have defined, tested behavior.

------------------------------------------------------------------------

## Phase 7 — Decide and resolve: `match_cohort(..., replace = TRUE)`

### The problem

Already flagged in-code (`R/match.R` header comment) and confirmed by
direct test: `match_cohort(ps, replace = TRUE)` throws
`"Matched data must contain 'match_num' or 'strata' column"`, because
[`MatchIt::match.data()`](https://kosukeimai.github.io/MatchIt/reference/match_data.html)
doesn’t return a `subclass`/`strata` column for matching with
replacement. `replace` is a documented, exposed parameter that currently
cannot be used at all.

### The fix (pick one, checkpoint with the user)

- **(a) Implement it properly**: with replacement, a control can serve
  multiple treated units, so there’s no single non-overlapping
  `strata`/`match_num` grouping in the way `.ensure_match_num()`
  expects. Derive an appropriate per-treated-unit pairing identifier
  from `MatchIt`’s match-with-replacement output (e.g. its weights/match
  matrix) that downstream paired functions
  ([`mcnemar_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/mcnemar_test.md),
  [`paired_wilcoxon_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/paired_wilcoxon_test.md),
  `.fit_matching()`) can consume correctly — this likely requires
  reworking those functions too, since “pairs” aren’t disjoint anymore.
- **(b) Explicitly disable it** for now: have
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
  itself [`stop()`](https://rdrr.io/r/base/stop.html) with a clear,
  immediate message if `replace = TRUE` is passed, rather than letting
  the user hit a confusing downstream error inside `.ensure_match_num()`
  several steps later. Remove or clearly caveat `replace` from the
  exported function’s advertised behavior until (a) is done.

Given the scope of (a), (b) is the pragmatic choice for this pass unless
the user wants to invest in full replacement-matching support now.

### Acceptance

- `replace = TRUE` either works end-to-end (paired tables, outcome
  models, everything downstream), or fails immediately and clearly at
  the
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
  call site with an actionable message — never a confusing error several
  functions downstream.

------------------------------------------------------------------------

## Phase 8 — Verification & release

- Full `testthat` suite green, including every new regression test from
  Phases 1–7.
- Re-run the standalone verification script (`verify_indepassoc_bugs.R`,
  or an updated version of it) against `rhc_sample` after all fixes;
  every `>>> CONFIRMED` / problem-indicating line from the original run
  should now read as fixed. Attach the before/after output to the PR.
- `R CMD check` clean (0 errors/warnings; document any unavoidable
  notes).
- Update `NEWS.md`, calling out explicitly which fixes are **behavior
  changes** to existing public function output (at minimum: Phase 1’s
  ratio\>1/NA handling, Phase 4’s `iptw` resolution if option (a) is
  chosen, Phase 5’s stricter covariate validation) — anyone who already
  called these functions on data with `NA` outcomes, `ratio > 1`
  matching, or typo’d covariate names will see different behavior after
  this merges.
- Checkpoint with the user on a version bump (this plan contains
  multiple public behavior changes and at least one crash fix — likely
  warrants `0.4.0` per semantic versioning, not a patch release) before
  tagging.

------------------------------------------------------------------------

## Definition of done

[`paired_wilcoxon_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/paired_wilcoxon_test.md)
no longer crashes on outcomes with `NA`s; `ratio > 1` behavior is
explicit (documented error or correct many:1 handling), verified against
`rhc_sample`.

[`mcnemar_test()`](https://mostafa-abbas.github.io/IndepAssoc/reference/mcnemar_test.md)
audited for the same two gaps, with regression tests either way.

`subgroup_analysis(..., method = "matching")` no longer silently returns
all-`NA` on the RHC cohort; root cause is documented; failures are
always visibly warned.

`utils` added to `DESCRIPTION` Imports; `R CMD check` no longer flags
it.

`iptw` vs `aipw` distinction is resolved and documented; behavior-change
status recorded in `NEWS.md`.

Covariate-name validation is consistent (errors, not silent drops)
across every exported function that takes a `covariates` argument.

Coefficient-row matching in
[`model_summ()`](https://mostafa-abbas.github.io/IndepAssoc/reference/model_summ.md)
is exact/anchored, with defined behavior for multi-level factor
exposures.

`match_cohort(replace = TRUE)` either works end-to-end or fails
immediately and clearly at the call site.

Full suite green, `R CMD check` clean, `NEWS.md` updated, version-bump
decision checkpointed with the user before tagging.

------------------------------------------------------------------------

# OpenCode Prompt

Paste the block below into OpenCode as the task prompt. It assumes this
file (`IndepAssoc_verified_bugfix_plan.md`) is present in the repo root
or otherwise accessible to the session.

    You are working in the IndepAssoc R package repo (currently tagged v0.3.0). Read
    IndepAssoc_verified_bugfix_plan.md in full before starting. That file is the working
    spec for this task -- follow it phase by phase, in the order given.

    Process for every phase:
    1. Create a git worktree/branch for the phase.
    2. Reproduce the bug first, exactly as described in the plan (use the bundled
       rhc_sample data where the plan references it -- it's already in data/, load via
       data(rhc_sample)). Write this reproduction as a failing testthat test before
       touching any implementation code.
    3. Implement the fix described in the phase. Where the plan presents a choice (Phase 4,
       Phase 7), stop and ask me which option to take before writing code for that phase --
       do not pick silently.
    4. Confirm the new test(s) pass, then run the full testthat suite and R CMD check.
       Do not proceed to the next phase if either is not clean.
    5. Update NEWS.md for that phase's change, noting explicitly if it's a behavior change
       to existing public function output (the plan flags which ones are).
    6. Commit with a message referencing the phase number and a one-line summary of the
       root cause (not just "fix bug").
    7. Stop and give me a summary of what changed and what you found (especially for
       Phase 2's investigation) before merging to main and starting the next phase.

    Do not skip ahead, do not batch phases into one commit, and do not start any work from
    the other planning docs in this repo (RHC vignette, new methods, documentation polish)
    until this entire plan is merged -- flag it to me if you think something from those
    docs is actually a prerequisite for a phase here rather than assuming so yourself.

    Start with Phase 1.
