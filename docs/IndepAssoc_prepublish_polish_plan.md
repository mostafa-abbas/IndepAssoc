# IndepAssoc — Pre-Publish Polish: Docs, Formatting, CI

> Working spec for OpenCode. This is the final pass before the
> repository goes public as a portfolio piece. Follow phase by phase, in
> order. Same process as every prior plan in this repo: git worktree →
> failing regression test first (where the phase involves code, not just
> prose) → fix/implement → full suite + `R CMD check` clean → update
> `NEWS.md` → commit referencing the phase number → stop and post a
> summary and wait for explicit go-ahead before merging to main and
> starting the next phase.
>
> For the documentation-only phases (14) there is no code to test in the
> usual sense, but treat “does this file actually render correctly on
> GitHub” as the acceptance check with the same rigor as a failing test
> — verify by rendering the markdown, not by eye alone, since this exact
> class of bug (a fence mismatch causing a comment to render as a giant
> heading) was already found once in `README.md` and needs to be ruled
> out everywhere else, not just patched where it was found.
>
> Do not bump the package version or tag a release until Phase 17
> explicitly says to, and even then, checkpoint with me before tagging —
> same as every prior plan.

## Context

The package is functionally done and well-tested (Phases 1-13 across
three prior plans: bugfixes, balance-plot integration, plot fixes). The
remaining gap before publishing publicly, specifically as a portfolio
piece for propensity-score/HEOR/RWE roles, is entirely in presentation:
the documentation doesn’t currently tell the reader what the package is
*for* or that it’s grounded in two peer-reviewed papers, one markdown
rendering bug was already found and fixed by hand in `README.md`
(attached to this plan — apply it as the starting point, don’t
rediscover it), numeric output isn’t formatted to a consistent
publication-ready convention anywhere, and there’s no CI badge
demonstrating the testing rigor that already exists in the git history.

The original project-planning docs in this repo already called for
“humanized professional documentation… elimination of robotic AI jargon
(delve, testament, realm, pivotal, in conclusion)” — that goal was never
executed. This plan finally does it, alongside the new formatting and CI
work.

------------------------------------------------------------------------

## Phase 14 — Documentation content and tone pass

### The problem

Three separate issues, all in the “what a reader sees first” category:

1.  **`README.md` had a markdown fence bug** (already fixed — see the
    attached, corrected `README.md`; apply this file as-is, then
    continue with the rest of this phase on top of it, don’t redo the
    fix from scratch).
2.  **No file in the repo explains the package’s real-world
    provenance.** It generalizes the shared analysis pipeline from two
    papers the author actually published — the Heliyon CABG
    sex-differences study and the *Journal of Cardiothoracic Surgery*
    LAAC/POAF study — and this context appears nowhere in `README.md`,
    `DESCRIPTION`, or any vignette. For a reader evaluating this as
    evidence of real HEOR/PSM experience, that link is the single most
    important piece of context in the repository, and it’s currently
    missing.
3.  **Tone has never been audited for AI-generated boilerplate.** Across
    `README.md`, `NEWS.md`, and all four vignettes, check for and
    rewrite: generic AI-essay phrasing (“delve into,” “it’s important to
    note,” “in conclusion,” “testament to,” “realm of,” “leverage” used
    as a verb where “use” would do, unnecessary hedging or repetition,
    or a summary paragraph that just restates what was already said).
    Prose should read the way an experienced biostatistician would
    actually write it: direct, specific, comfortable stating a number or
    a limitation plainly without padding around it.

### The fix

- Apply the attached corrected `README.md`, then add:
  - A short “Background” section (2-4 sentences, not more) near the top,
    after the one-line description, linking both papers by name/journal
    and explaining that the package generalizes their shared pipeline
    into a reusable, five-method interface.
  - A short “Validation” note (a sentence or two, with concrete numbers,
    not vague language) — e.g., what dataset it’s been validated
    against, roughly how many tests exist, that `R CMD check` is clean.
    Pull the actual current numbers from the test suite and
    `R CMD check` output rather than reusing any number quoted earlier
    in this repo’s history, since the count has grown across every
    phase.
- Read every prose paragraph in `README.md`, `NEWS.md`, and all four
  `.Rmd` vignettes (`vignettes/indepassoc-quickstart.Rmd`,
  `vignettes/rhc-validation.Rmd`, `vignettes/causal-benchmarks.Rmd`, and
  any other vignette present) end to end. Rewrite anything that reads as
  generic or AI-boilerplate per the list above. Do not rewrite
  technical/methodological content that’s already precise and accurate —
  the goal is tone, not re-deriving the statistics.
- Render every `.md`/`.Rmd` file that will be checked (at minimum
  `README.md`, `NEWS.md`) through an actual markdown renderer (or knit
  the `.Rmd` files) and visually confirm no heading, list, or code block
  renders unexpectedly — this is how the original README bug was
  actually caught, not by reading the raw text.
- Remove `vignettes/rhc-validation.html` from version control — a
  pre-rendered vignette output file shouldn’t be committed alongside its
  `.Rmd` source; it’s build output, not source. Confirm `.gitignore`
  covers this going forward so it doesn’t silently reappear (check the
  `.gitignore` diff flagged as pending from an earlier phase while
  you’re in this file, and report what it actually contains — it was
  never resolved).

### Acceptance

- `README.md` explains what the package is, why it exists (the two
  papers), and what validates it, in language that reads as written by a
  person with real domain expertise, not generated boilerplate.
- No markdown file in the repo has a fence-mismatch or similar rendering
  defect — confirmed by actually rendering each one, not by reading the
  source.
- No stray rendered vignette output is committed to version control.

------------------------------------------------------------------------

## Phase 15 — Publication-ready number formatting as a real package function

### The problem

Every vignette in this repo currently formats the
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)/[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
comparison table’s numbers (rounding, the OR-vs-Mean-Diff label switch,
the `<0.001` convention for small p-values) using a small,
vignette-local helper function, duplicated independently in each `.Rmd`
file. There is no package-level, reusable, tested way to turn a raw
`comparison` data frame (full floating-point precision) into a
publication-ready table — which also means every future user of the
package has to reinvent this themselves.

### The fix

- Add an exported function,
  `format_comparison(comparison, digits = 2, p_digits = 3)`, in the
  package proper (not a vignette-local helper), that:
  - Rounds `estimate`, `conf_low`, `conf_high` to `digits` decimal
    places (default 2) and renders the CI as `"low–high"` (en dash).
  - Formats `p_value` to `p_digits` decimal places, substituting
    `"<0.001"` (or the correct threshold for whatever `p_digits` is set
    to, generalized, not hardcoded to the digit `3`) for values below
    that threshold.
  - Automatically derives the estimate column’s display label (“OR” for
    `type == "binary"`, “Mean Diff” for `type == "continuous"`) from the
    `type` column already present in `comparison`, rather than requiring
    the caller to pass it manually.
  - Capitalizes `method` for display (e.g. `"aipw"` → `"AIPW"`,
    `"regression"` → `"Regression"` — check the existing vignettes’
    capitalization convention for methods like `iptw`/`aipw`
    specifically, since title-casing them naively would produce
    “Iptw”/“Aipw” rather than the correct all-caps acronyms; handle this
    explicitly rather than relying on generic title-case).
- Add a second exported function,
  `format_combined(combined_comparison, ...)`, for the multi-outcome
  case (an `Outcome` column alongside everything
  [`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)
  already handles), reusing
  [`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)
  internally rather than duplicating its logic.
- \*\*Do not apply this rounding inside
  [`export_results()`](https://mostafa-abbas.github.io/IndepAssoc/reference/export_results.md)‘s
  CSV output.\*\* Exported CSVs should retain full numeric precision for
  downstream reanalysis; publication-style rounding belongs at the
  display/reporting layer only (printed tables, vignettes, README),
  never baked destructively into the data a user might reuse for further
  computation. State this explicitly in both functions’ roxygen docs so
  it isn’t “fixed” by a future contributor who doesn’t know it’s
  deliberate.
- These names (`format_comparison`, `format_combined`) were already
  assumed to exist by an earlier user-authored analysis script for the
  LAA cohort, discovered during an earlier vignette-writing pass —
  implementing them properly now closes that gap retroactively as well
  as serving this phase’s purpose.

### Regression tests to add

- [`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)
  on a synthetic comparison data frame: correct rounding, correct CI
  string format, correct `<0.001` substitution at the boundary (test a
  p-value just above and just below the threshold), correct OR/Mean Diff
  label derived from `type`, correct method capitalization including
  `iptw`→`IPTW` and `aipw`→`AIPW` specifically.
- [`format_combined()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_combined.md)
  on a multi-outcome combined data frame: same checks, plus confirming
  the `Outcome` column passes through unchanged and rows from different
  outcome types (binary and continuous mixed together) each get their
  own correct label.
- A test confirming
  [`export_results()`](https://mostafa-abbas.github.io/IndepAssoc/reference/export_results.md)’s
  CSV output is unaffected by this phase — full precision preserved, not
  rounded.

### Acceptance

- [`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)/[`format_combined()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_combined.md)
  exist as tested, exported, documented package functions with roxygen
  `@examples`.
- Every vignette’s local formatting helper is replaced with a call to
  the real function — no duplicated formatting logic remains anywhere in
  the repo.
- [`export_results()`](https://mostafa-abbas.github.io/IndepAssoc/reference/export_results.md)’s
  CSV output is provably unrounded (covered by the test above).

------------------------------------------------------------------------

## Phase 16 — Apply the new formatting everywhere, and wire in CI

### The problem

Two remaining, unrelated pieces of polish:

1.  Phase 15’s new functions need to actually replace the ad hoc helpers
    in every vignette (`rhc-validation.Rmd` in particular, which
    currently has the most fully worked-out ad hoc version).
2.  There is no continuous integration configured. Given this
    repository’s purpose (demonstrating rigorous testing/validation
    practice to people evaluating it), a live, green `R-CMD-check` badge
    at the top of the README is worth more than the same claim stated in
    prose.

### The fix

- Update `rhc-validation.Rmd`, `indepassoc-quickstart.Rmd`, and
  `causal-benchmarks.Rmd` (and the README’s own worked example) to call
  [`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)/
  [`format_combined()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_combined.md)
  instead of any local helper. Delete the now-redundant local helper
  definitions from each vignette.
- Set up a standard GitHub Actions R-CMD-check workflow (e.g. via
  `usethis::use_github_action_check_standard()` or an equivalent
  hand-written `.github/workflows/R-CMD-check.yaml`), covering at
  minimum the current R version. Add the resulting status badge to the
  top of `README.md`.
- Re-knit every vignette end to end one more time after these changes
  and confirm no regressions (image counts, table contents) relative to
  what was already validated in prior phases.

### Acceptance

- No vignette contains its own local formatting helper; all use the
  package’s exported functions.
- A working GitHub Actions workflow file exists and (once pushed) will
  produce a visible pass/fail badge; the README links to it.

------------------------------------------------------------------------

## Phase 17 — Final verification and release checkpoint

- Full `testthat` suite green, including every new test from Phases
  15-16.
- `R CMD check` clean (0 errors/warnings; document any unavoidable
  notes, e.g. the pre-existing environmental `qpdf` note).
- Render/knit every `.md` and `.Rmd` file in the repository one final
  time and confirm none have rendering defects — this is the final check
  against the class of bug found in Phase 14’s starting point.
- Update `NEWS.md` summarizing Phases 14-16 (documentation,
  formatting, CI) under the existing `(development)` heading, consistent
  with how the two prior follow-up plans were recorded.
- Report the final state: test count, `R CMD check` result, and a list
  of every file touched across all three phases, so I can review the
  full diff before anything is tagged.
- Do not bump the version or create a tag. When I confirm everything
  above, I’ll decide separately whether this rolls into the pending
  `0.5.0` (the balance-plot/plot-fixes work already sitting in
  `NEWS.md`’s development section) as one combined release, or ships as
  its own version — that decision is mine, not yours.

------------------------------------------------------------------------

\## Definition of done

`README.md` (as ./README.md) plus a Background section and a Validation
note are in place; tone across README/NEWS/all vignettes has been
audited and rewritten where it read as generic AI boilerplate.

No markdown/R Markdown file in the repo has a rendering defect,
confirmed by actually rendering each one.

`vignettes/rhc-validation.html` removed from version control;
`.gitignore` confirmed to prevent recurrence.

[`format_comparison()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_comparison.md)/[`format_combined()`](https://mostafa-abbas.github.io/IndepAssoc/reference/format_combined.md)
exist as tested, exported functions; every vignette uses them instead of
a local helper;
[`export_results()`](https://mostafa-abbas.github.io/IndepAssoc/reference/export_results.md)’s
CSV output remains full-precision.

GitHub Actions R-CMD-check workflow configured; badge added to README.

Full suite green, `R CMD check` clean, `NEWS.md` updated, final
file-list report delivered for my review before any version-bump/tag
decision.
