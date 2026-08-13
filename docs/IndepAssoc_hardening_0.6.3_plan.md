# IndepAssoc — Input Validation Hardening (0.6.3)

> Working spec for OpenCode. Fixes issues/1
> (github.com/mostafa-abbas/IndepAssoc/issues/1), filed during
> 0.6.1/0.6.2 stress testing. All 8 items are minor input-validation
> gaps found by an adversarial stress script (not the regression suite)
> — none are regressions, all predate 0.6.1. This plan is scoped ONLY to
> issue \#1’s 8 items. Do not expand scope to anything else found during
> this work without asking first.
>
> Same process as every prior plan: git worktree/branch per phase →
> failing regression test first, including a backward-compatibility test
> proving valid/well-behaved input is unaffected → implement → full
> testthat suite + R CMD check clean (0 errors/warnings) → update
> NEWS.md → commit referencing the phase and issue \#1 → stop and post a
> summary → wait for explicit go-ahead before merging and starting the
> next phase.
>
> Do not bump the package version beyond 0.6.3, do not tag, do not push
> to the live repo without a separate explicit go-ahead — same
> checkpoint discipline as 0.6.1/0.6.2.

## Context

Issue \#1 lists 8 cases where malformed arguments or degenerate data
either silently succeed, behave unexpectedly, or surface only a generic
downstream warning instead of a clear, actionable error. Two independent
stress-test runs (0.6.1-era and post-0.6.2) reproduced the identical 8
cases both times — these are real, stable, reproducible gaps, not flaky
test artifacts.

For each item below: first confirm current behavior against the real
source (don’t assume the stress test’s diagnosis is complete), decide
the correct fix, then implement. Where a “degenerate but arguably
legitimate” case exists (e.g. n_strata=1, all-one-arm data), the fix may
be a documented, tested, intentional behavior rather than a forced error
— use judgment and say which you chose and why.

## Phase 30 — Argument validation (issue \#1, Section A: items 1-3)

### The problem

Three argument-validation gaps, all in early input-checking code paths:

1.  `match_cohort(ps, caliper = -0.2)` does not error on a negative
    caliper.
2.  `fit_outcome(..., method = "iptw", trim = c(0.9, 0.1))` — an
    inverted trim range — does not error. Investigation during 0.6.2
    found `.trim_probs()` silently *sorts* an inverted range rather than
    rejecting it; confirm this is still the mechanism.
3.  `check_positivity(ps, threshold = c(0.99, 0.01))` — an inverted
    threshold — does not error.

### The fix

- Add explicit validation to each of the three call sites/helpers so an
  inverted or invalid range triggers a clear error
  (e.g. `` `caliper` must be non-negative, not {caliper}. `` /
  `` `trim` bounds must be ascending (lower, upper), got {trim[1]}, {trim[2]}. ``
  / same pattern for
  [`check_positivity()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_positivity.md)’s
  `threshold`).
- Decide explicitly: should `trim`/`threshold` inversion always be a
  hard error, or is silently sorting a defensible behavior worth keeping
  and just documenting? Pick one, document the choice in roxygen, and
  say why in the phase summary — don’t silently keep today’s
  sort-without-warning behavior without an explicit decision.

### Regression tests to add

- Each of the 3 cases: assert the corrected behavior (error, or
  documented sort, per your Phase 30 decision) with an exact/regex
  message match, not just “doesn’t error.”
- Backward-compat: assert a valid, correctly-ordered
  caliper/trim/threshold still works identically to today’s behavior.

------------------------------------------------------------------------

## Phase 31 — Degenerate data: zero/single-arm and n=1 (issue \#1, Section B: items 4-6)

### The problem

1.  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)
    on `n = 1` row does not error — undefined/unexpected behavior.
2.  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)
    on all-treated (zero controls) does not error.
3.  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)
    on all-control (zero treated) does not error.

### The fix

- Add an explicit, early check in
  [`build_ps_model()`](https://mostafa-abbas.github.io/IndepAssoc/reference/build_ps_model.md)
  for: fewer than some minimum usable row count (decide and document a
  sensible floor, e.g. n \>= 2 with both arms represented), and for zero
  units in either exposure arm — fail fast with a clear message naming
  the problem
  (e.g. `No control units found in the data — cannot build a propensity score model.`)
  rather than letting it proceed into an undefined/confusing downstream
  state.
- Confirm what currently actually happens in each case (what does
  [`glm()`](https://rdrr.io/r/stats/glm.html) return/do with a single
  row or a single-class outcome?) before deciding the exact fix — don’t
  assume, verify against source and by reproducing.

### Regression tests to add

- Each of the 3 cases: assert a clear, specific error.
- Backward-compat: assert well-formed data with both arms represented
  and n well above any new floor is unaffected.

------------------------------------------------------------------------

## Phase 32 — Zero-variance outcome (issue \#1, Section B: items 7-8)

### The problem

`fit_outcome(..., type = "binary")` on an outcome that is all-0 or all-1
(zero variance) does not error — it proceeds into
[`glm()`](https://rdrr.io/r/stats/glm.html), which only emits a generic
`glm.fit: algorithm did not converge` warning, not a clear, actionable
error naming the actual problem (no outcome variance to estimate an
effect from).

### The fix

- Add an explicit pre-fit check in the binary-regression path (and
  confirm whether other methods — matching, iptw, aipw, stratification —
  have the same exposure to this problem; check each, don’t assume only
  `regression` is affected) that detects zero-variance outcome and fails
  with a clear message before reaching
  [`glm()`](https://rdrr.io/r/stats/glm.html).
- Decide and document: is zero-variance outcome always a hard error, or
  should it be allowed with a loud warning for some methods? State your
  reasoning.

### Regression tests to add

- All-0 and all-1 binary outcome: assert the new clear error (or
  documented behavior) for every method actually exposed to this
  problem, not just `regression`.
- Backward-compat: assert an outcome with normal variance is unaffected
  across the same set of methods.

------------------------------------------------------------------------

## Phase 33 — Final verification and close-out

- Full testthat suite green, including every new test from Phases 30-32.
- R CMD check clean (0 errors/warnings; document any unavoidable
  environmental notes).
- Re-run the adversarial stress script (or the specific 8 repro cases
  from it) against the built package and confirm all 8 MISMATCH cases
  from issue \#1 are now resolved — report the before/after mismatch
  count with evidence, not assumption.
- Update NEWS.md under its own clearly-separated 0.6.3 section.
- Close issue \#1 with a comment summarizing what changed for each of
  the 8 items and linking the commits — do this only after my go-ahead,
  not automatically.
- Report final state (test count, R CMD check result, file list,
  mismatch count before/after) for my review before any version/tag/push
  decision.

## Definition of done

All 8 items in issue \#1 have an explicit, deliberate fix or documented
intentional behavior — none left as silent gaps.

Each item has a dedicated regression test plus a backward-compat test.

Full suite green, R CMD check clean, NEWS.md updated in its own section.

Adversarial stress script re-run confirms 0 remaining mismatches from
issue \#1’s original list.

Issue \#1 closed only after my explicit review and go-ahead.

No version bump beyond 0.6.3, no tag, no push to live repo without a
separate explicit go-ahead, same as every prior release.

opencode prompt

    You are working in the IndepAssoc R package repository (currently v0.6.2, live at
                                                            github.com/mostafa-abbas/IndepAssoc). The working spec for this task is
    IndepAssoc_hardening_0.6.3_plan.md -- read it completely before writing any code.

    This plan fixes all 8 items in github issue #1, filed during earlier stress testing.
    These are minor, non-regression input-validation gaps -- not urgent, but I want every
    one of them addressed properly, not just the ones that seemed most serious. Do not
    skip or defer any of the 8 items without asking me first, and do not expand scope to
    anything beyond issue #1 without asking me first either.

    Follow the plan phase by phase, strictly in order (30 through 33). Do not skip phases,
    and do not batch multiple phases into a single commit or branch.

    Execution workflow for each phase:
      1. Create a dedicated git worktree or branch for the phase.
    2. Write a failing regression test first, including a backward-compatibility test
    proving well-formed/valid input is unaffected by the new validation -- required for
    every fix in this plan, not optional.
    3. Before implementing each fix, confirm current behavior against the actual source
    and by reproducing the case yourself -- don't rely on the stress test's diagnosis
    alone, verify it.
    4. Implement the change.
    5. Verify: full test suite and R CMD check with 0 errors/warnings.
    6. Update NEWS.md.
    7. Commit with a descriptive message referencing the phase number and issue #1.
    8. Stop and post a summary: what you found, what changed, and evidence it works.

    Wait for my explicit go-ahead before merging that phase into main and starting the
    next one.

    For any item where the "correct" fix isn't obvious (e.g. whether an inverted range
    should hard-error or be silently corrected, or what minimum row count is reasonable),
    state your recommendation and reasoning in the phase summary and wait for my
    confirmation before implementing -- don't decide silently on judgment calls.

    Do not bump the package version beyond 0.6.3, do not create a tag, and do not push to
    the live repo under any circumstances -- those decisions are mine, after Phase 33,
    separately from this task.

    Begin now with Phase 30.
