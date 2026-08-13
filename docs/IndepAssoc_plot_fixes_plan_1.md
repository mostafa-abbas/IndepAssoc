# IndepAssoc — Plot Fixes: plot_comparison() Double-Render + plot_asmd_balance() Top-N

> Working spec for OpenCode. Follow phase by phase, in order. Same
> process as the prior plans: git worktree → failing regression test
> first → fix → full suite + `R CMD check` clean → update `NEWS.md` →
> commit referencing the phase number and root cause → stop and post a
> summary (root cause/what changed/before-after test output) and wait
> for explicit go-ahead before merging to main and starting the next
> phase.
>
> Do not bump the package version or tag a release at any point in this
> plan.
>
> Do not start any work from the other planning docs in this repo
> (five-method dispatcher extensions, documentation polish) until this
> plan is merged.

## Context

Both issues below were found by actually knitting the new RHC validation
vignette end to end (not from source review alone) and inspecting the
real output — a PNG diff of the balance chart and a count of rendered
images in the HTML output.

## Phase 11 — Fix: `plot_comparison()` renders the plot twice

### The problem

[`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md)
(`R/plot_comparison.R`) builds the ggplot object, calls `print(p)`
internally, and then also returns `p` via `invisible(p)`. Its own
roxygen docs promise “A `ggplot` object (invisible)” — implying the
caller is expected to [`print()`](https://rdrr.io/r/base/print.html) it
themselves to see it (since
[`invisible()`](https://rdrr.io/r/base/invisible.html) suppresses R’s
normal top-level auto-print). Both the RHC and LAA vignettes follow
exactly that documented pattern —
`print(plot_comparison(res$comparison, ...))` — and, confirmed directly
from the rendered RHC vignette’s HTML output, this produces **two**
rendered copies of every forest plot: one from the function’s internal
`print(p)`, one from the caller’s explicit
[`print()`](https://rdrr.io/r/base/print.html). This is the identical
anti-pattern `plot_love()` had before it was removed in an earlier phase
(Phase 9) — it just wasn’t caught there because that audit was scoped to
the ASMD balance charts, not the forest plots.

### The fix

- Remove the internal `print(p)` call from
  [`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md).
  Return `p` the normal way (drop the
  [`invisible()`](https://rdrr.io/r/base/invisible.html) wrapper too,
  unless there’s a specific reason to keep it — if kept, update the
  roxygen `@return` to accurately describe the resulting behavior either
  way, since the current docs describe the *intended* pattern, not the
  actual double-render bug).
- Update every call site in the package’s own vignettes
  (`rhc-validation.Rmd`, and any others using this pattern) to match
  whichever convention is chosen: if the function returns visibly,
  calling it bare at the top of an R Markdown chunk is enough — the
  explicit [`print()`](https://rdrr.io/r/base/print.html) wrapper
  becomes unnecessary and should be removed to avoid reintroducing the
  double-render.
- Update the `@examples` block in
  [`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md)’s
  roxygen docs to reflect the corrected usage.

### Regression tests to add

- A test asserting
  [`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md)
  does not call [`print()`](https://rdrr.io/r/base/print.html)
  internally — e.g., by checking that calling it inside a context that
  would error or flag on any graphics device output (or, more simply, by
  checking the returned object’s class and confirming no plot was
  written to the active device before the caller does so themselves —
  pick whichever mechanism `testthat`/the existing test suite already
  uses for similar checks, if any precedent exists in the repo).
- A test confirming
  [`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md)
  still returns a valid `ggplot` object with the expected layers (point,
  error bar, reference line) — this shouldn’t change, only the print
  side effect should be removed.

### Acceptance

- Knitting `rhc-validation.Rmd` (or any vignette using
  [`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md))
  produces exactly one rendered forest plot per call, not two.

------------------------------------------------------------------------

## Phase 12 — Add opt-in `top_n` truncation to `plot_asmd_balance()`

### The problem

Confirmed directly by rendering the RHC balance chart: the 50 covariates
in `rhc_sample$covariates` expand to roughly 76 bars in
[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)’s
output, because several are multi-level categorical variables (`cat1`,
`cat2`, `ninsclas`, `income`, `race`) that
[`cobalt::bal.tab()`](https://ngreifer.github.io/cobalt/reference/bal.tab.html)
expands into one dummy-variable row per level (e.g. `cat1_ARF`,
`ninsclas_Medicaid`, `ninsclas_Medicare`). At that density, the x-axis
labels overlap and are largely illegible — the chart stops doing its job
on a cohort with this many categorical confounders, which is a realistic
case, not an edge case (RHC is a real published benchmark dataset, not a
contrived stress test).

### The fix

- Add a `top_n` parameter to
  [`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md),
  default `NULL` (current behavior: show every covariate/level,
  unchanged for existing callers).
- When `top_n` is set, rank covariates by their **unadjusted
  (pre-matching)** ASMD — not the matched/post-matching value — and keep
  only the `top_n` with the largest unadjusted imbalance. Rank by
  unadjusted ASMD specifically because that’s what the chart exists to
  communicate: which covariates started out most imbalanced, and whether
  matching fixed them. Both the unadjusted and matched bars for each
  selected covariate should still be shown side by side, exactly as in
  the untruncated chart — only the *set* of covariates displayed
  changes, not what’s shown per covariate.
- When truncation is applied, add a subtitle or caption stating exactly
  how many of the total are shown,
  e.g. `"Showing 25 of 76 covariates with the largest unadjusted ASMD"`
  — computed from the actual counts, not hardcoded — so the chart never
  silently implies it’s showing the complete covariate set when it
  isn’t.
- Do not change the default behavior for any existing caller that
  doesn’t pass `top_n` — this must be a strictly additive, opt-in
  change.

### Regression tests to add

- `plot_asmd_balance(x, top_n = 25)` on a balance table with more than
  25 covariates/levels: assert the returned plot’s underlying data
  contains exactly 25 covariates, and that they are the 25 with the
  largest unadjusted ASMD (not the largest matched ASMD — construct a
  synthetic case where the ranking would differ between the two, so this
  actually discriminates between a correct and an almost-correct
  implementation).
- `plot_asmd_balance(x)` (no `top_n`, or a balance table with fewer than
  `top_n` covariates): assert the output is unchanged from current
  behavior — full covariate set, no caption about truncation.
- Assert the truncation caption’s covariate counts match the actual
  input data (e.g. test with a table that has 76 total covariates/levels
  and `top_n = 25`, asserting the caption text contains both “25” and
  “76”, not a hardcoded example count).
- Run this against `rhc_sample`’s real balance output (via
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  or
  [`check_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_balance.md))
  in addition to a synthetic case, since that’s the real 76-bar scenario
  that motivated this phase.

### Acceptance

- `plot_asmd_balance(result, top_n = 25)` on the RHC cohort’s balance
  data produces a readable chart with 25 covariates, correctly selected
  by unadjusted ASMD, with an accurate caption — and
  `plot_asmd_balance(result)` (no `top_n`) is byte-for-byte unchanged
  from its current output.

------------------------------------------------------------------------

## Phase 13 — Verification & release

- Full `testthat` suite green, including every new test from Phases
  11-12.
- Re-knit `rhc-validation.Rmd` end to end and confirm: exactly one
  forest plot per outcome (not two), and (optionally, if the vignette is
  updated to demonstrate it) a `top_n = 25` balance chart renders
  correctly. Attach the before/after image counts and a screenshot or
  description of the truncated chart to the PR.
- `R CMD check` clean (0 errors/warnings; document any unavoidable
  notes).
- Update `NEWS.md`: Phase 11 is a bug fix (double-render), Phase 12 is a
  new, backward-compatible feature (opt-in `top_n` parameter) — neither
  is a breaking change, since Phase 12 defaults to current behavior and
  Phase 11 only removes an unwanted duplicate render, not a capability.
- No version-bump/tag action — checkpoint with me on whether this
  warrants folding into whatever release currently follows `0.4.0`, or
  shipping separately; don’t decide this yourself.

------------------------------------------------------------------------

## Definition of done

[`plot_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_comparison.md)
no longer double-renders; internal `print(p)` removed; all internal call
sites (vignettes, examples) updated to match.

[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
supports an opt-in `top_n` parameter, ranked by unadjusted ASMD, with an
accurate, dynamically-computed truncation caption.

Default behavior of
[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md)
(no `top_n`) is unchanged.

Regression tests cover both phases, including a test on the real RHC
balance data that motivated Phase 12.

Full suite green, `R CMD check` clean, `NEWS.md` updated.

------------------------------------------------------------------------

# OpenCode Prompt

Paste the block below into OpenCode as the task prompt. It assumes this
file (`IndepAssoc_plot_fixes_plan.md`) is present in the repo root or
otherwise accessible to the session.

    You are working in the IndepAssoc R package repository. The working spec for this task
    is IndepAssoc_plot_fixes_plan.md in the root directory -- read it completely before
    writing any code. It follows on from the previously merged bugfix and
    balance-plot-integration plans.

    Follow the plan phase by phase, strictly in order (Phase 11, then 12, then 13). Do not
    skip phases, and do not batch multiple phases into a single commit or branch.

    Execution workflow for each phase:
    1. Create a dedicated git worktree or branch for the phase.
    2. Write a failing regression test in testthat reproducing the exact issue described in
       the plan (using data(rhc_sample) where the plan calls for it, since that's the real
       dataset that surfaced both issues).
    3. Implement the fix cleanly in the source code.
    4. Verify the new test passes, and confirm devtools::test() and R CMD check complete
       with 0 errors and 0 warnings.
    5. Update NEWS.md with explicit details of any behavior or output changes -- note
       plainly that neither phase is a breaking change, and say why.
    6. Commit with a descriptive message referencing the phase number and root cause.
    7. Stop and post a summary: what you found, what changed, and the before/after test +
       R CMD check output. Wait for my explicit go-ahead before merging that phase into
       main and starting the next one.

    In Phase 11, after removing the internal print(p) call, grep the repo (R/, vignettes/,
    man/) for every existing call site that wraps plot_comparison() in an explicit print()
    and update each one so the vignettes don't end up with zero rendered plots instead of
    one -- report which files you changed.

    In Phase 12, the ranking must use the unadjusted/pre-matching ASMD column, not the
    matched one -- if you're not sure which column that is in the balance data structure,
    check R/balance.R and R/pipeline.R rather than guessing, and say in your phase summary
    which column you used and how you confirmed it was the right one.

    Do not bump the package version or create a tag under any circumstances -- that
    decision is mine, separately from this task.

    Do not start any work described in the other planning docs in this repo (five-method
    dispatcher extensions, documentation polish) until this entire plan is merged to main.

    Begin now with Phase 11.
