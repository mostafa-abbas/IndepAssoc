# IndepAssoc — Estimand Clarity, Outcome-Distribution Flexibility, and PS/Weight Diagnostics

> Working spec for OpenCode. Follow phase by phase, in order. Same
> process as every prior plan in this repo: git worktree → failing
> regression test first (for code phases) or actual-rendered-output
> verification first (for documentation phases) → implement → full
> suite + `R CMD check` clean → update `NEWS.md` → commit referencing
> the phase number and root cause → stop and post a summary and wait for
> explicit go-ahead before merging to main and starting the next phase.
>
> Do not bump the package version or tag a release until the final phase
> explicitly says to, and even then, checkpoint with me before tagging.
>
> Do not start any work from other planning docs in this repo until this
> plan is merged.

## Context

An external AI-generated methodological review (both of the RHC vignette
specifically and of the package’s implementation) raised several points.
Some are already fully implemented in the package and the review simply
missed them while evaluating the rendered output — those are **not** in
this plan; they’re listed at the bottom under “Explicitly not doing” so
nobody re-litigates them later. Two points are genuinely correct,
standard causal-inference critiques that the package and its vignettes
should address: estimand heterogeneity across the five methods, and the
distributional mismatch between plain OLS and right-skewed, zero-bounded
length-of-stay data. A third point — propensity-score/weight diagnostics
— is a real, valuable, and currently missing piece of instrumentation,
separate from the balance-checking that already exists.

This plan is scoped to what’s genuinely missing and genuinely worth
doing now, not everything the review suggested. In particular,
cross-fitting / super-learner AIPW is explicitly out of scope — at this
package’s actual scale (50 covariates, ~5,700 observations, generalizing
two published papers that used standard parametric methods), that
machinery solves a problem this package doesn’t have, and adding it
would be a large, poorly-motivated undertaking. It’s noted as a
documented limitation, not implemented.

------------------------------------------------------------------------

## Phase 18 — Documentation: estimand clarity and outcome-distribution caveats (no code changes)

### The problem

The five methods compared in
[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
output do not all target the same causal estimand, and this is never
stated anywhere in the package’s documentation or vignettes:

- 1:1 nearest-neighbor matching without replacement (the `matching`
  method) targets the **average treatment effect on the treated (ATT)**
  — by construction, since only treated units that found a control match
  remain in the analysis.
- IPTW, stratification, and AIPW, as currently implemented, target the
  **average treatment effect (ATE)** across the full analytic sample.
- The `regression` method’s coefficient is a **conditional** effect
  (adjusted for the specific covariates in the model), which is not
  numerically equal to a marginal ATE under a nonlinear link (logistic
  regression’s odds ratio is non-collapsible — this is a mathematical
  fact about the OR, not a modeling choice or a bug).

Presenting five numbers side by side without this context invites a
reader to interpret “the estimates are similar” as “these are five
measurements of one true number,” when they are, more precisely, five
different (but related) quantities that happen to agree in direction and
rough magnitude — which is still real evidence of robustness, just not
the same claim.

Separately: hospital length of stay (`los` in the RHC vignette) is
heavily right-skewed and bounded at zero (in the existing vignette’s own
printed summary: median 14, mean 21.5, max 342). Plain OLS/linear
regression on a variable with this shape is a common simplification
(including in both of the source papers this package generalizes), not a
fatal error, but the vignette should say so explicitly rather than
silently presenting it as if it were an unremarkable choice.

### The fix

- Add a short, precise “Estimand” subsection to `rhc-validation.Rmd`
  (and mirror a shorter version in the README’s methods description)
  stating plainly which quantity each of the five methods targets, using
  the three-way ATT/ATE/conditional framing above. Keep it to a few
  sentences — this is a clarity fix, not a rewrite of the methods
  section.
- Add a short caveat sentence to the `los` results section noting the
  right-skew and that a log-transform or Gamma GLM would be a more
  distributionally appropriate choice for this specific outcome shape —
  do not silently imply this is unremarkable.
- No code changes in this phase. Verify by actually rendering the
  updated vignette (per this repo’s established standard for
  documentation phases) and confirming the new sections read clearly and
  are visually easy to find, not buried.

### Acceptance

- A reader of `rhc-validation.Rmd` can state, without additional
  research, which estimand each of the five methods targets and why the
  `los` outcome’s OLS treatment is a simplification worth naming.

------------------------------------------------------------------------

## Phase 19 — `estimand` parameter for IPTW, AIPW, and stratification (ATE vs. ATT)

### The problem

`matching` inherently targets ATT (no parameter needed — this is a
structural property of 1:1 matching without replacement, not something
to make configurable). `iptw`, `aipw`, and `stratification`, as
currently implemented, only target ATE. There is no way for a user to
request an ATT-consistent version of these three methods, which would
let all four propensity-score-based methods (matching, stratification,
IPTW, AIPW) target the *same* estimand — the more defensible comparison
the review correctly identified as currently missing.

### The fix

- Add an `estimand = c("ATE", "ATT")` parameter to
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)
  (and thread it through
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)),
  defaulting to `"ATE"` — **this preserves all current default behavior
  exactly**; nothing changes for an existing caller who doesn’t pass
  this argument.
- For **IPTW/AIPW**: implement standardized mortality ratio (SMR)
  weights for the ATT case, alongside the existing standard IPTW weights
  for ATE:
  - ATE weights (existing, unchanged): `W = A/ps + (1-A)/(1-ps)`
  - ATT weights (new): `W = A + (1-A) * ps/(1-ps)` Verify this exact
    formula against a citable source (e.g. Austin 2011, “An Introduction
    to Propensity Score Methods…”) before implementing — don’t implement
    from memory alone, confirm it against a real reference and cite it
    in the roxygen docs.
- For **stratification**: add an ATT-weighted pooling option that
  weights each stratum’s within-stratum effect estimate by the number of
  *treated* units in that stratum (ATT-style), alongside the existing
  pooling (which should be confirmed and documented as to which estimand
  it currently approximates — verify this rather than assuming, since
  the plan’s Phase 18 documentation work depends on this being correctly
  characterized).
- If `estimand = "ATT"` is requested together with
  `method = "matching"`, this should be a silent no-op (matching is
  always ATT regardless of this parameter) — no error, since ATT is
  already what matching provides; document this explicitly rather than
  leaving it implicit.
- Update
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
  and
  [`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)’s
  roxygen docs to state the default and the meaning of each option
  clearly.

### Regression tests to add

- A test confirming `estimand = "ATE"` (or the omitted default) produces
  numerically identical results to the current, unmodified behavior on
  existing test fixtures — this is the backward-compatibility guarantee
  and needs to be airtight.
- A test confirming the ATT weight formula matches a hand-calculated
  example on a small synthetic dataset with known propensity scores
  (compute the expected weights by hand from the cited formula, don’t
  just check the function doesn’t error).
- A test confirming `iptw`/`aipw` under `estimand = "ATT"` and
  `matching`’s existing output are targeting a comparably-defined
  population (both restricted to/weighted toward the treated group’s
  covariate distribution) — this is the actual point of the feature, so
  it needs a test that checks the *concept*, not just that a number came
  out.
- A test confirming `method = "matching"` with `estimand = "ATT"`
  behaves identically to `method = "matching"` with the default, and
  does not error.

### Acceptance

- `fit_outcome(..., method = "iptw", estimand = "ATT")` and
  `method = "aipw", estimand = "ATT"` produce SMR-weighted,
  ATT-consistent estimates, verified against a hand-checked formula.
- Default behavior (`estimand` omitted or `"ATE"`) is provably unchanged
  from the current package.

------------------------------------------------------------------------

## Phase 20 — Propensity-score and weight diagnostics

### The problem

The package has thorough covariate balance diagnostics
([`check_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_balance.md),
[`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md))
but nothing that directly inspects the propensity score distribution
itself or the resulting IPTW weights — which is a distinct, valid
diagnostic concern the review correctly raised. Extreme propensity
scores (near 0 or 1) or extreme weights can produce unstable,
high-variance IPTW/AIPW estimates even when covariate balance looks fine
on average.

### The fix

- Add a new exported function,
  [`check_positivity()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_positivity.md)
  (or fold into
  [`check_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_balance.md)
  as an additional returned component — decide which reads more
  naturally given the existing API shape, and say which you chose and
  why in the phase summary), that reports, at minimum:
  - The distribution of propensity scores by exposure group
    (e.g. min/max/quantiles), so a user can see whether treated and
    control groups have meaningfully overlapping support.
  - A simple positivity-violation flag/warning when propensity scores
    fall below or above a configurable threshold (e.g. default flagging
    scores outside `[0.01, 0.99]`), rather than silently proceeding.
  - The distribution of the actual IPTW weights used in
    `fit_outcome(..., method = "iptw")`/`"aipw"` (min/max/ratio of
    max-to-min), since extreme weights are the practical symptom of
    positivity problems.
- Add an optional weight-trimming/truncation parameter to the IPTW/AIPW
  fitting functions (e.g. `trim = NULL` default — no change to current
  behavior — or `trim = c(0.01, 0.99)` to truncate weights at those
  percentiles before fitting). Default `NULL` preserves all current
  behavior exactly.
- Wire a brief positivity/weight-diagnostic summary into
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)’s
  printed output (the existing `Step N/9: ...` progress messages) so
  it’s visible by default, not something a user has to remember to call
  separately — but keep it concise, a few lines, not a wall of output.

### Regression tests to add

- [`check_positivity()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_positivity.md)
  (or the chosen equivalent) on a synthetic dataset with a known,
  deliberately constructed positivity violation (some units with PS very
  close to 0 or 1): assert the flag correctly triggers.
- Same function on a well-behaved synthetic dataset with good overlap:
  assert no flag.
- `trim` parameter on IPTW/AIPW: assert weights are correctly truncated
  at the specified percentiles, and that `trim = NULL` (default) leaves
  weights identical to current, untrimmed behavior — backward
  compatibility, same discipline as Phase 19.
- Run the new diagnostics against `rhc_sample`’s real data (the real
  50-covariate, 2184-vs-3551 cohort) as well as synthetic cases, since
  that’s the dataset the vignette actually reports on.

### Acceptance

- A user can see propensity-score overlap and weight extremity without
  writing custom code, for every
  [`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
  call, by default.
- `trim` is opt-in and strictly backward-compatible when omitted.

------------------------------------------------------------------------

## Phase 21 — Apply everything to the RHC vignette and verify end to end

### The problem

Phases 18-20 add real capability, but none of it is useful to a reader
unless the RHC vignette (the package’s primary real-data validation
document, and the one externally reviewed) actually demonstrates it.

### The fix

- Update `rhc-validation.Rmd`:
  - Add the Estimand section from Phase 18 (if not already merged as
    part of that phase — confirm rather than duplicate).
  - Add a positivity/weight-diagnostics subsection using Phase 20’s new
    function(s)/output, showing the real RHC cohort’s propensity-score
    overlap and weight distribution.
  - Add a short supplementary chunk showing the `los` outcome’s result
    under `estimand`-aware IPTW/AIPW (Phase 19) alongside the existing
    regression result, so the vignette demonstrates the new
    ATT-consistency option is real and working, not just documented.
  - Add a brief log-transformed-LOS sensitivity check (a single extra
    `lm(log(los) ~ ...)`-style comparison, clearly labeled as a
    sensitivity check, not a replacement for the main analysis)
    addressing Phase 18’s LOS-skewness caveat concretely rather than
    only in prose.
- Re-knit all vignettes (not just `rhc-validation.Rmd` — confirm the
  other two are unaffected) end to end and confirm no regressions in
  image counts, table contents, or rendering, consistent with how every
  prior phase in this repo has verified vignette changes.

### Acceptance

- `rhc-validation.Rmd`, rendered, demonstrates every new capability from
  Phases 18-20 concretely, not just describes it in prose.

------------------------------------------------------------------------

## Phase 22 — Final verification and release checkpoint

- Full `testthat` suite green, including every new test from Phases
  19-20.
- `R CMD check` clean (0 errors/warnings; document any unavoidable
  notes, e.g. the pre-existing environmental `qpdf` note).
- Render every vignette one final time and confirm no rendering defects,
  consistent with this repo’s established documentation-phase standard.
- Update `NEWS.md` under a new, clearly-separated section (not folded
  silently into the existing 0.5.0 entry, since this is new, real,
  backward-compatible functionality, not a bug fix pass) — cover the new
  `estimand` parameter, the new positivity/weight diagnostics, and the
  vignette updates.
- Report the final state (test count, `R CMD check` result, file list)
  for my review.
- Do not bump the version or create a tag. This is a genuine minor
  version’s worth of new backward-compatible functionality (`estimand`,
  [`check_positivity()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_positivity.md),
  `trim`) — when I confirm everything above, I’ll decide the version
  number and timing separately.

------------------------------------------------------------------------

## Explicitly not doing (and why)

- **Cross-fitting / super-learner / double-ML AIPW.** Valid technique in
  general, but motivated by high-dimensional or flexible-ML
  nuisance-model settings; this package’s actual use case (50
  covariates, ~5,700 observations, generalizing two published papers
  that used standard parametric methods) doesn’t call for it. Note it as
  a documented limitation/possible future direction in the AIPW method’s
  roxygen docs, don’t build it.
- **A new `get_balance()`/Love-plot function.** Already fully
  implemented —
  [`check_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_balance.md),
  [`plot_asmd_balance()`](https://mostafa-abbas.github.io/IndepAssoc/reference/plot_asmd_balance.md),
  and the `top_n` truncation feature already do this, and the RHC
  vignette already has a dedicated “Balance check before and after
  matching” section with a rendered chart. The external review appears
  to have missed this (possibly didn’t parse the embedded chart image),
  not identified a real gap. No action needed beyond Phase 21’s general
  “make sure nothing new is buried” check.
- **Sandwich/robust SEs for IPTW, pair-stratified SEs for matching.**
  Already implemented — `.fit_iptw()` uses
  [`sandwich::vcovHC()`](https://rdrr.io/pkg/sandwich/man/vcovHC.html);
  binary-outcome matching uses
  [`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html)
  conditioned on `match_num` (which conditions out the pair exactly),
  and continuous-outcome matching uses a pair-fixed-effects model. No
  action needed.
- **Weight stabilization for IPTW.** Already implemented (the existing
  weights are stabilized). No action needed.

------------------------------------------------------------------------

## Definition of done

`rhc-validation.Rmd` (and README) explicitly state which estimand each
method targets and why LOS’s right-skew matters, in plain language.

`estimand = c("ATE", "ATT")` exists on
[`fit_outcome()`](https://mostafa-abbas.github.io/IndepAssoc/reference/fit_outcome.md)/[`run_pipeline()`](https://mostafa-abbas.github.io/IndepAssoc/reference/run_pipeline.md)
for IPTW/AIPW/stratification, with SMR weighting for the ATT case,
verified against a hand-checked formula; default behavior is provably
unchanged.

Propensity-score and weight diagnostics
([`check_positivity()`](https://mostafa-abbas.github.io/IndepAssoc/reference/check_positivity.md)
or equivalent) exist, with a positivity-violation flag and an opt-in
`trim` parameter that defaults to current, untrimmed behavior.

The RHC vignette demonstrates all of the above concretely, not just in
prose.

Full suite green, `R CMD check` clean, `NEWS.md` updated in its own
clearly labeled section, final report delivered for my review before any
version decision.
