# IndepAssoc — Finalize and Ship 0.6.1

> Working spec for OpenCode. The two bug fixes in this release
> (outcome-type auto-detection,
> [`table_matched()`](https://mostafa-abbas.github.io/IndepAssoc/reference/table_matched.md)
> sparse-factor screening) are already implemented, already tested, and
> already on `main` at `github.com/mostafa-abbas/IndepAssoc`, sitting
> under a `# IndepAssoc (unreleased)` heading in `NEWS.md`. This plan
> verifies that work, cleans up two known-stale documentation items, and
> ships it as `0.6.1`.
>
> Same process as every prior plan: implement/fix → verify → report →
> stop and wait for explicit go-ahead before merging/pushing/tagging.
> Given the scope is small, this can move faster than prior plans, but
> the checkpoint discipline still applies — nothing gets pushed or
> tagged without an explicit go-ahead after Phase 29.

## Context

`0.6.0` is tagged and live. Since then, two real bugs were found and
fixed directly against the live repository (outside this project’s usual
monorepo/subtree-split extraction flow, since there’s no reconciliation
needed this time — confirm this in Phase 27 rather than assuming):
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)/[`fit_all_models()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_all_models.md)
crashed on a continuous outcome when `type` was omitted (defaulted to
binomial, threw `y values must be 0 <= y <= 1`), and
[`table_matched()`](https://mostafa-abbas.github.io/IndepAssoc/reference/table_matched.md)
crashed via
[`gtsummary::add_p()`](https://www.danieldsjoberg.com/gtsummary/reference/add_p.html)
when propensity-score matching caused a categorical covariate to lose a
rare level in one exposure arm. Both fixes are implemented, documented
in code, and covered by tests using real `rhc_sample` data as the
regression case. This plan does not re-implement anything — it verifies,
finalizes, and ships what’s already there.

------------------------------------------------------------------------

## Phase 27 — Verify the existing fixes

### The problem

The two fixes exist on `main` but haven’t been through this project’s
usual independent verification step (full suite + `R CMD check`,
confirmed and reported, not assumed).

### The fix

- First, confirm and report which local working copy actually has this
  work (exact path, git remote, current HEAD commit) — don’t assume it’s
  the same monorepo location used for `0.6.0`, since this work was done
  directly against the live repo.
- Run the full `testthat` suite. Report the count and confirm 0 failures
  — pay particular attention to `test-run_pipeline.R` and the
  sparse-factor test in `test-tables.R`, since those are the regression
  tests for these exact two bugs.
- Run `R CMD check`. Confirm clean (0 errors/warnings; document any
  unavoidable environmental notes — `qpdf`, the previously-identified
  `makeindex`/TinyTeX PDF-manual issue — same as every prior release).
- Confirm `DESCRIPTION`’s version is still `0.6.0` (i.e. nobody bumped
  it prematurely) and that `NEWS.md`’s `(unreleased)` section accurately
  describes what the code actually does — spot-check the two bullet
  points against the real implementation (`R/utils.R`’s
  `detect_outcome_type()`, `R/tables_matched.R`’s
  `.paired_levels_safe()`) rather than trusting the changelog text as
  written.

### Acceptance

- Full suite green, `R CMD check` clean, `NEWS.md`’s existing
  description verified accurate against the real code — reported with
  evidence, not assumed.

------------------------------------------------------------------------

## Phase 28 — Finalize `NEWS.md`, fix known-stale docs, bump version

### The problem

Three small, independent things:

1.  `NEWS.md`’s top section needs to become a proper `0.6.1` entry, not
    stay as `(unreleased)` indefinitely.
2.  `README.md`’s Validation section still says “424 passing unit tests”
    — stale since the `0.6.0` work, now doubly stale with this release’s
    additions.
3.  `vignettes/rhc-validation.Rmd` has a typo: “the cohort is not
    structurally non-positivious” should read “the cohort does not have
    a structural positivity violation” (or similarly natural phrasing —
    avoid the non-word “non-positivious”).

### The fix

- Replace `# IndepAssoc (unreleased)` with
  `# IndepAssoc 0.6.1 (<date>)`. Keep the existing bug-fix descriptions
  if Phase 27 confirmed them accurate; tighten the wording only if Phase
  27 found something imprecise. This is a patch release (pure bug fixes,
  no new public API) — do not add a version bump beyond `0.6.1`.
- Bump `DESCRIPTION`’s `Version:` to `0.6.1`.
- Update `README.md`’s Validation section to state the actual current
  test count (verify it directly from Phase 27’s suite run, don’t
  estimate).
- Fix the `rhc-validation.Rmd` typo.
- Show all diffs before committing.

### Acceptance

- `NEWS.md` has a clean `0.6.1` entry; `DESCRIPTION` is `0.6.1`;
  README’s test count is accurate; the vignette typo is fixed.

------------------------------------------------------------------------

## Phase 29 — Final verification, push, and tag (only on separate explicit go-ahead)

**Do not proceed into this phase automatically after Phase 28 — wait for
a separate instruction, even if Phase 28 is clean.**

- Re-run the full suite and `R CMD check` on the finalized tree (post
  Phase 28’s edits) — the version bump and doc changes shouldn’t affect
  test results, but confirm rather than assume.
- Re-knit `rhc-validation.Rmd` (the only vignette touched) and confirm
  the typo fix rendered correctly and nothing else regressed.
- Push the finalized commit(s) to `main` (this should be a normal,
  direct push/PR merge on the live repo this time — no
  subtree-split/reconciliation needed, since this work was never done
  through the monorepo. Confirm this assumption in Phase 27 and flag
  immediately if it turns out to be wrong).
- Tag `v0.6.1` (annotated, same message-style convention as
  `v0.5.0`/`v0.6.0`).
- Confirm both GitHub Actions workflows (`R-CMD-check`, `pkgdown`)
  trigger and report their status.

### Acceptance

- `main` reflects the finalized `0.6.1` tree; `v0.6.1` is tagged; both
  CI workflows confirmed run.

------------------------------------------------------------------------

## Definition of done

Phase 27: existing fixes independently verified (suite, `R CMD check`,
`NEWS.md` accuracy) with evidence reported.

Phase 28: `NEWS.md` finalized as `0.6.1`, `DESCRIPTION` bumped, README
test count corrected, vignette typo fixed.

Phase 29 (only on separate go-ahead): pushed, tagged `v0.6.1`, both CI
workflows confirmed.

------------------------------------------------------------------------
