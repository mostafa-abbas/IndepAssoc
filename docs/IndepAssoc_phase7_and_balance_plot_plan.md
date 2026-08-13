# IndepAssoc — Phase 7 Redo + Balance-Plot Integration Plan

> Working spec for OpenCode. This is a follow-up to
> `IndepAssoc_verified_bugfix_plan.md` (Phases 1-8, already merged
> except Phase 7). Follow phase by phase, in order. Same process as
> before: git worktree → failing regression test first → fix → full
> suite + `R CMD check` clean → update `NEWS.md` → commit referencing
> the phase number and root cause → **stop and post a summary (root
> cause/what changed/before-after test output) and wait for explicit
> go-ahead before merging to main and starting the next phase.**
>
> Do not bump the package version or tag a release at any point in this
> plan — that decision is mine, separately, after everything below is
> merged.
>
> Do not start any work from the other planning docs in this repo (RHC
> vignette, five-method dispatcher extensions, documentation polish)
> until this plan is merged.

## Context

Phases 1-6 and 8 of the prior plan were implemented correctly and
verified against `rhc_sample`. Phase 7
(`match_cohort(..., replace = TRUE)`) was not implemented as specified:
the instruction was to make
[`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
throw an immediate, clear [`stop()`](https://rdrr.io/r/base/stop.html)
when `replace = TRUE` is passed. Instead, a new function,
[`find_matching_data_summary()`](https://mostafa-abbas.github.io/IndepAssoc/reference/find_matching_data_summary.md),
was added that supports `replace`/`ratio > 1` via its own independent
matching logic — useful, but it does not fix
[`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
itself, which still throws the same confusing downstream error it always
did. That function turns out to be a faithful port of the user’s own
pre-existing R script for propensity balance summaries (not invented
from nothing), which is why it’s being kept rather than removed — but
Phase 7 as written still needs to be done.

Separately, the user wants a new plot added to
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
output: a grouped bar chart of absolute standardized mean difference
(ASMD) per covariate, unmatched vs. matched, with a horizontal dashed
line at the (general, non-hardcoded) balance threshold — matching a
specific reference figure (navy `#005A9C` unmatched bars, orange
`#E66101` matched bars, covariate names on the x-axis, ASMD on the
y-axis, legend below the plot). Investigation found this is largely
already built:
[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
(`R/plot_asmd_balance.R`) already produces exactly this chart, with
matching colors, and already knows how to read
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
`balance_pre`/`balance_post` output directly. It is just never called by
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md),
so it’s not actually part of the pipeline result yet. There is also a
second, older, duplicate function — `plot_love()` (`R/balance.R`) —
doing a near- identical job with different default colors and, worse, an
internal [`print()`](https://rdrr.io/r/base/print.html) side effect that
would be a problem if wired into
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
directly.

------------------------------------------------------------------------

## Phase 7 (redo) — `match_cohort(..., replace = TRUE)` must fail clearly at the call site

### The problem (unchanged from the original plan)

`match_cohort(ps, replace = TRUE)` throws
`"Matched data must contain 'match_num' or 'strata' column."` from deep
inside `.ensure_match_num()`, several calls downstream of where
`replace = TRUE` was actually passed. The in-code comment documenting
this as a known, unfixed limitation is still present verbatim.

### The fix

- In
  [`match_cohort()`](https://mostafa-abbas.github.io/IndepAssoc/reference/match_cohort.md)
  itself (`R/match.R`), check `replace` up front and
  [`stop()`](https://rdrr.io/r/base/stop.html) immediately with a clear,
  actionable message if `replace = TRUE`, e.g.:
  `"match_cohort() does not support replace = TRUE: MatchIt::match.data() does not return a match-pair identifier for matching with replacement, which every downstream paired function (balance tables, paired tests, conditional-logit matching estimator) requires. Use find_matching_data_summary() if you need matching with replacement, or file a request to extend match_cohort() to support it end-to-end."`
- Remove the now-redundant top-of-file comment describing this as an
  open follow-up (it’s fixed, not deferred, once this lands) — replace
  it with a short comment pointing to
  [`find_matching_data_summary()`](https://mostafa-abbas.github.io/IndepAssoc/reference/find_matching_data_summary.md)
  as the supported alternative for replacement matching, so the next
  reader isn’t left wondering why two matching entry points exist with
  different `replace` support.
- Do **not** modify
  [`find_matching_data_summary()`](https://mostafa-abbas.github.io/IndepAssoc/reference/find_matching_data_summary.md)
  — it already handles `replace` correctly on its own terms and is out
  of scope here.

### Regression tests to add

- `match_cohort(ps, replace = TRUE)` errors immediately, with a message
  that mentions `replace` (not the old, confusing
  `"match_num or strata"` message) — assert this with
  `expect_error(..., "replace")` or similar, anchored to the new message
  text.
- `match_cohort(ps, replace = FALSE)` (and the default) still work
  exactly as before — add/confirm an existing test guards against this
  phase accidentally breaking the default path.

### Acceptance

- `match_cohort(..., replace = TRUE)` fails immediately at the call site
  with a message that explains why and points to the supported
  alternative — never a confusing error several functions downstream.

------------------------------------------------------------------------

## Phase 9 — Wire the ASMD balance plot into `run_pipeline()`

### The problem

[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
produces the exact grouped-bar ASMD chart requested (unmatched
vs. matched, general `threshold` line, correct colors), and its
column-detection logic already matches the shape of
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
`balance_pre`/`balance_post` output — but
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
never calls it, so the plot isn’t actually part of the pipeline result a
user gets back.

Separately, `plot_love()` (`R/balance.R`) duplicates this functionality
against a different code path
([`cobalt::bal.tab()`](https://ngreifer.github.io/cobalt/reference/bal.tab.html)
directly on the match object rather than the pipeline’s already-computed
balance tables), with different default colors and an internal
[`print()`](https://rdrr.io/r/base/print.html) call that makes it unsafe
to wire into a function like
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
that should return an object, not force a plot render as a side effect.

### The fix

- Add
  `result$balance_plot <- plot_asmd_balance(list(balance_pre = balance_pre, balance_post = balance_post), threshold = balance_threshold)`
  (or equivalent) to
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md),
  using the already-general `balance_threshold` parameter — no new
  parameter needed, it already threads through. Confirm the exact call
  shape against
  [`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)’s
  actual input-detection logic (`.asmd_tables()`) rather than assuming;
  write the regression test first so this is verified, not just wired
  in.
- Resolve the duplication with `plot_love()`. Recommended: remove
  `plot_love()` and `NAMESPACE`‘s export of it, since
  [`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
  is the better-designed of the two (no print side effect, already
  matches the user’s reference figure’s colors, and is now the one
  actually wired into the pipeline). If `plot_love()` is kept instead
  for any reason, document explicitly in both functions’ roxygen docs
  why two near-identical plotting functions exist and when to use which
  — don’t leave two undocumented, silently-diverging implementations of
  the same chart in the package. Grep the repo (`R/`, `tests/`,
  vignettes, README) for any existing use of `plot_love()` before
  removing it, and update/remove those call sites too.
- Confirm
  [`print.IndepAssoc()`](https://mostafa-abbas.github.io/IndepAssoc/reference/print.IndepAssoc.md)/[`summary.IndepAssoc()`](https://mostafa-abbas.github.io/IndepAssoc/reference/summary.IndepAssoc.md)
  don’t need to change — the plot should be available at
  `result$balance_plot` for the user to print/save themselves, not
  auto-rendered by [`print()`](https://rdrr.io/r/base/print.html).

### Regression tests to add

- [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  on `example_cohort` (fast, no network): assert `result$balance_plot`
  is present, is a `ggplot` object, and its data contains one row per
  covariate per cohort stage (unadjusted/matched) matching
  `nrow(result$balance_pre)` / `nrow(result$balance_post)` (after
  whatever filtering
  [`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
  applies, e.g. dropping `distance`/`(Intercept)` rows — assert the
  filtered count explicitly rather than just “no error”).
- [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  on `rhc_sample` (the real-data case, guarded the same way other
  RHC-dependent tests in this repo are, if network/runtime cost is a
  concern): assert the same shape, and that the dashed threshold line’s
  value in the returned plot matches whatever `balance_threshold` was
  passed (not hardcoded to `0.10`) — e.g. by calling
  `run_pipeline(..., balance_threshold = 0.15)` and inspecting the
  plot’s `geom_hline` layer’s `yintercept`, not just the default case.
- If `plot_love()` is removed: confirm no remaining references anywhere
  in the package (`grep -rn "plot_love" .` returns nothing outside
  historical `NEWS.md` entries).

### Acceptance

- `run_pipeline(...)$balance_plot` exists, renders the requested chart
  (unmatched vs. matched ASMD per covariate, correct colors, dashed line
  at the actual `balance_threshold` used), and there is exactly one
  supported ASMD-comparison-plot function in the package, not two.

------------------------------------------------------------------------

## Phase 10 — Verification & release

- Full `testthat` suite green, including every new test from Phases 7
  (redo) and 9.
- Re-run (or extend) the standalone verification script against
  `rhc_sample`, adding checks for: `match_cohort(replace = TRUE)`
  failing immediately with the new message, and
  `run_pipeline(...)$balance_plot` existing and reflecting a non-default
  `balance_threshold`. Attach before/after output to the PR.
- `R CMD check` clean (0 errors/warnings; document any unavoidable
  notes).
- Update `NEWS.md`: the Phase 7 redo (behavior change — `replace = TRUE`
  now fails immediately instead of failing downstream; still fails
  either way, so this is a message-quality fix, not a new capability),
  and Phase 9 (new `result$balance_plot` field; `plot_love()` removal if
  that’s the direction taken — flag removal of an exported function as a
  breaking change for anyone calling it directly).
- Checkpoint with me on the version bump before tagging, same as before
  — do not do this yourself.

------------------------------------------------------------------------

## Definition of done

`match_cohort(..., replace = TRUE)` fails immediately at the call site
with a clear, specific message; default (`replace = FALSE`) behavior
unaffected.

[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
returned object includes `balance_plot`, generated via
[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md),
using the pipeline’s actual `balance_threshold`.

Exactly one ASMD-comparison plotting function remains in the package
(`plot_love()` removed or its continued existence explicitly justified
in docs).

Regression tests cover both the default-threshold and a
non-default-threshold case for the wired-in plot, on both
`example_cohort` and `rhc_sample`.

Full suite green, `R CMD check` clean, `NEWS.md` updated, version-bump
decision checkpointed with the user before tagging.

------------------------------------------------------------------------

# OpenCode Prompt

Paste the block below into OpenCode as the task prompt. It assumes this
file (`IndepAssoc_phase7_and_balance_plot_plan.md`) is present in the
repo root or otherwise accessible to the session.

    You are working in the IndepAssoc R package repository. The working spec for this task
    is IndepAssoc_phase7_and_balance_plot_plan.md in the root directory -- read it
    completely before writing any code. It is a follow-up to
    IndepAssoc_verified_bugfix_plan.md (already merged except its Phase 7, which this file
    redoes).

    Follow the plan phase by phase, strictly in order (Phase 7 redo, then Phase 9, then
    Phase 10). Do not skip phases, and do not batch multiple phases into a single commit or
    branch.

    Execution workflow for each phase:
    1. Create a dedicated git worktree or branch for the phase.
    2. Write a failing regression test in testthat reproducing the exact issue described in
       the plan (using data(rhc_sample) and data(example_cohort) where applicable).
    3. Implement the fix cleanly in the source code.
    4. Verify the new test passes, and confirm devtools::test() and R CMD check complete
       with 0 errors and 0 warnings.
    5. Update NEWS.md with explicit details of any behavior or output changes, including
       whether it's a breaking change (e.g. if plot_love() is removed).
    6. Commit with a descriptive message referencing the phase number and root cause.
    7. Stop and post a summary: what you found, what changed, and the before/after test +
       R CMD check output. Wait for my explicit go-ahead before merging that phase into
       main and starting the next one.

    In Phase 9, before removing plot_love(), grep the entire repo for existing references
    to it (R/, tests/, vignettes, README) and report what you find before deciding whether
    removal is safe -- if anything outside NEWS.md still calls it, stop and ask me how to
    proceed instead of choosing on your own.

    Do not bump the package version or create a tag under any circumstances -- that
    decision is mine, after Phase 10, separately from this task.

    Do not start any work described in the other planning docs in this repo (RHC vignette,
    five-method dispatcher extensions, documentation polish) until this entire plan is
    merged to main.

    Begin now with Phase 7 (redo).
