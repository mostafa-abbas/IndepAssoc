# IndepAssoc — Reconcile, Finalize, and Ship 0.6.0

> Working spec for OpenCode. This is the final step before v0.6.0
> replaces what’s currently live on GitHub. Follow phase by phase, in
> order. Same process as every prior plan: git worktree where applicable
> → implement → verify → report → stop and wait for explicit go-ahead
> before merging/pushing anything.
>
> This plan involves pushing to the live, public
> `mostafa-abbas/IndepAssoc` repository. Nothing in Phase 26 (the actual
> push/tag) happens without an explicit, separate go-ahead after Phase
> 25 is confirmed clean — do not chain Phase 25’s completion straight
> into Phase 26’s push.

## Context

Three separate lines of work exist right now and need to become one:

1.  **The local monorepo’s `IndepAssoc/` subtree**
    (`~/my-coding-project`, `main` branch, currently at commit
    `2428ce9`) — has all of Phases 18-22 (estimand parameter,
    positivity/weight diagnostics, updated RHC vignette), but does
    **not** have items 2 or 3 below.
2.  **Direct edits made via the GitHub web UI** on
    `mostafa-abbas/IndepAssoc`’s `main` branch after the `v0.5.0` push
    (commits `3464e4b`, `22fce59`) — README wording fixes (the
    `R CMD check` validation claim softened to acknowledge the `qpdf`
    warning, and
    [`remotes::install_github()`](https://remotes.r-lib.org/reference/install_github.html)
    instructions added).
3.  **The `pkgdown` site setup**, pushed from a separate, one-off clone
    at `/tmp/indepassoc-pkgdown` (commit `4a24e23` on
    `mostafa-abbas/IndepAssoc`’s `main`) — `.gitignore`, `.Rbuildignore`
    additions, `DESCRIPTION`’s `URL:` field, `_pkgdown.yml`,
    `.github/workflows/pkgdown.yaml`, `.github/.gitignore`.

None of items 2 or 3 exist anywhere in the local monorepo’s history. If
Phase 18-22’s work is extracted and pushed the same way `0.5.0` was (a
fresh `subtree split` from local `main`, pushed to replace GitHub’s
`main`), items 2 and 3 will be silently lost — not merged, not
conflicted, just gone, since the push would overwrite `main` with a
history that never contained them.

------------------------------------------------------------------------

## Phase 23 — Reconcile: recover the GitHub-only and pkgdown-only work into the local tree

### The problem

The local working tree needs to end up containing all three lines of
work, and this needs to be done by actually diffing against the live
repository’s current state — not by trusting this document’s summary of
what changed, since more edits may have happened since this plan was
written.

### The fix

- Clone `https://github.com/mostafa-abbas/IndepAssoc.git` fresh into a
  scratch directory (read-only reference, not a working copy to push
  from) — call it `/tmp/indepassoc-live-reference`.
- Diff `/tmp/indepassoc-live-reference`’s `main` against the local
  monorepo’s `IndepAssoc/` subtree as it currently stands (at
  `2428ce9`), file by file. Do not assume the diff is limited to what’s
  listed in this plan’s Context section — confirm it directly, and
  report anything found that isn’t mentioned above.
- For each difference found that originated from GitHub-web-editing or
  the `pkgdown` setup (not from Phases 18-22’s own work, which is
  expected to differ since it’s not on GitHub yet): manually re-apply
  that exact change into the local monorepo’s `IndepAssoc/` directory,
  as its own clearly-described commit (e.g. one commit for the README
  wording/install-instructions recovery, one for the `pkgdown`
  configuration recovery) — do not silently fold this into a Phase 18-22
  commit or amend history.
- After reapplying, diff the local tree against
  `/tmp/indepassoc-live-reference` again, restricted to the files that
  are *not* part of Phases 18-22’s intended changes (i.e. everything
  except `R/`, `man/`, `NAMESPACE`, `tests/`, the RHC vignette, and
  `NEWS.md`) — this remaining diff should now be empty. Report the
  actual diff output proving this, not just a claim that it’s empty.

### Acceptance

- The local monorepo’s `IndepAssoc/` tree contains: the live GitHub
  repo’s current README wording and install instructions, the full
  `pkgdown` configuration, *and* Phases 18-22’s work — verified by an
  actual diff against a fresh clone of the live repo, not asserted.

------------------------------------------------------------------------

## Phase 24 — Finalize `NEWS.md` and bump the version

### The problem

`NEWS.md` currently has Phases 18-22’s changes recorded as a
development-process log under `# IndepAssoc (development)`. Nobody has
used `0.5.0` as a dependency yet, so there is no audience for a
phase-by-phase changelog of internal process — it should read as a clean
description of what’s new in this release, the same style as the `0.5.0`
entry, not a diary.

### The fix

Replace the `# IndepAssoc (development)` section with the following
(adjust only if something concrete in the repo contradicts a specific
claim — verify before committing, don’t just paste this in blind):

``` markdown
# IndepAssoc 0.6.0

Adds explicit control over which causal estimand the propensity-score methods
target, plus propensity-score and weight diagnostics.

- `fit_outcome()` and `run_pipeline()` gain an `estimand = c("ATE", "ATT")`
  argument. With `"ATT"`, IPTW and AIPW use standardized mortality ratio (SMR)
  weighting and stratification pools by treated-unit count, so all four
  propensity-score-based methods can target the average treatment effect on
  the treated rather than the population average. Matching already targets
  the ATT by construction and ignores this argument. The default (`"ATE"`)
  is unchanged from prior behavior.
- New `check_positivity()` reports propensity-score overlap between exposure
  groups, flags units outside a configurable support window (default
  `[0.01, 0.99]`), and summarizes the resulting IPTW weight distribution.
  `run_pipeline()` now prints this summary on every run and returns it as
  `result$positivity`.
- `fit_outcome()` gains a `trim` argument for the `"iptw"`/`"aipw"` methods,
  truncating extreme weights at specified percentiles. Default (`trim =
  NULL`) is unchanged from prior behavior.
- The RHC validation vignette now includes a worked positivity/weight
  diagnostic on the real cohort, a demonstration of the `estimand` and `trim`
  arguments, and a log-transformed sensitivity check for the right-skewed
  `los` outcome, alongside an expanded discussion of which estimand each of
  the five methods targets.

# IndepAssoc 0.5.0
...
```

(Keep everything from the existing `# IndepAssoc 0.5.0` heading down
unchanged — only the top section is being replaced.)

- Bump `DESCRIPTION`’s `Version:` to `0.6.0`.
- Show the exact `NEWS.md` and `DESCRIPTION` diffs for review before
  committing — same as the `0.5.0` rollup.

### Acceptance

- `NEWS.md` reads as a clean, user-facing release description for
  `0.6.0`, with no reference to phase numbers, dates of internal work,
  or process detail.
- `DESCRIPTION` version is `0.6.0`.

------------------------------------------------------------------------

## Phase 25 — Full verification

- Full `testthat` suite green.
- `R CMD check` clean (0 errors/warnings; document any unavoidable
  environmental notes — `qpdf`, and the previously-identified
  `makeindex`/TinyTeX PDF-manual issue, both pre-existing and unrelated
  to package code).
- Re-knit **all three vignettes** (`indepassoc-quickstart.Rmd`,
  `causal-benchmarks.Rmd`, `rhc-validation.Rmd`) end to end from a fresh
  install of the reconciled tree. Confirm: no errors, image counts
  unchanged from what was last validated for `quickstart` (2) and
  `causal-benchmarks` (3), `rhc-validation`’s new sections render
  correctly (the positivity check, the ATE/ATT table, the trim table,
  the log-LOS section) alongside its existing 5 images, and no
  unrounded/raw-precision numbers appear anywhere (grep the rendered
  HTML for `[0-9]\.[0-9]{4,}` as a mechanical check, the same standard
  used throughout this project).
- Confirm the README renders correctly (no markdown fence defects, per
  this project’s established standard) and that the reconciled version
  (Phase 23) is the one being rendered/checked, not a stale copy.
- Report full results (test count, `R CMD check` status, per-vignette
  image counts and confirmation of new-section presence, README render
  check) before Phase 26.

### Acceptance

- Everything above is confirmed clean on the actual reconciled tree, not
  on the pre-reconciliation Phase 22 state.

------------------------------------------------------------------------

## Phase 26 — Push and tag (only after explicit go-ahead)

**Do not start this phase automatically after Phase 25 — wait for a
separate, explicit instruction to proceed, even if Phase 25 is fully
clean.**

- Commit the reconciled tree (Phases 23-25’s work) on the local
  monorepo’s `main`.
- Run `git subtree split --prefix=IndepAssoc -b release-0.6.0` from the
  monorepo.
- Verify: tree byte-diff between `release-0.6.0` and the monorepo’s
  current `main:IndepAssoc` is empty (same check as every prior
  extraction), and — this is the new check specific to this phase — diff
  `release-0.6.0` against a **fresh clone of the still-live GitHub
  repo** restricted to non-Phase-18-26 files (README, gitignore,
  Rbuildignore, pkgdown config, DESCRIPTION’s URL field) and confirm
  that diff is also empty, proving Phase 23’s reconciliation actually
  made it through the extraction.
- Push `release-0.6.0` to `mostafa-abbas/IndepAssoc`’s `main` (this will
  move `main` forward from its current live state — confirm it’s a
  fast-forward, not a force-push, since Phase 23 was built starting from
  the live state’s actual content).
- Tag `v0.6.0` on the new `main` (fresh clone, same process as
  `v0.5.0`’s tagging — tags don’t survive `subtree split`).
- Confirm both GitHub Actions workflows (`R-CMD-check` and `pkgdown`)
  trigger and report their status — do not consider this phase done
  until both are observed to either pass or fail with a specific,
  reportable reason.

### Acceptance

- `main` on GitHub reflects the fully reconciled tree; `v0.6.0` is
  tagged; both CI workflows have run and their results are reported.

------------------------------------------------------------------------

## Definition of done

Phase 23: local tree provably contains the live repo’s GitHub-web edits,
the full `pkgdown` setup, and Phases 18-22’s work, verified by diff.

Phase 24: `NEWS.md` is a clean, forward-looking 0.6.0 entry with no
process diary; `DESCRIPTION` is `0.6.0`.

Phase 25: full suite green, `R CMD check` clean, all three vignettes
re-knit and verified on the reconciled tree specifically.

Phase 26 (only on separate explicit go-ahead): pushed, tagged, both CI
workflows confirmed run.
