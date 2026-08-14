# A Walkthrough for Clinicians: Does Right Heart Catheterization Increase Mortality Risk?

## Clinical overview

This walkthrough focuses on the clinical intuition behind checking a
clinical finding for confounding, not the underlying statistical code.
We’ll use a classic clinical question — does right heart catheterization
(RHC) increase 30-day mortality? — to show how IndepAssoc evaluates a
real-world clinical finding, using data from 5,735 critically ill
patients.

For the complete statistical methodology — every model, every parameter,
every diagnostic — see the [full RHC case study
vignette](https://mostafa-abbas.github.io/IndepAssoc/articles/rhc-validation.md).
Think of this page as the conceptual guide to interpreting those
results, and that page as the detailed reference underneath it.

## The problem: sicker patients are more likely to get the procedure

Right heart catheterization is used more often in patients who are
already more critically ill. That creates a trap: if you simply compare
the death rate in patients who got RHC to patients who didn’t, sicker
patients are overrepresented in the RHC group *before the procedure even
happens*. Any difference you see could just be “RHC patients were sicker
to begin with,” not “RHC caused harm.”

This is called **confounding by indication**, and it is the single
biggest threat to trusting any finding from real-world clinical data.

![Raw, confounded data on the left; after matching each treated patient
to a similar untreated patient, the only major difference left between
the two groups is whether they received the treatment; on the right,
five statistical approaches independently reach the same
conclusion.](../reference/figures/clinician-cohort-matching-story.png)

Raw, confounded data on the left; after matching each treated patient to
a similar untreated patient, the only major difference left between the
two groups is whether they received the treatment; on the right, five
statistical approaches independently reach the same conclusion.

## Step 1 — Load the data, and look at the raw numbers first

``` r

data(rhc_sample)
# rhc_sample bundles the classic RHC cohort:
#   - rhc_sample$data:       5,735 ICU patients
#   - rhc_sample$covariates: the confounders to adjust for (severity of
#                             illness, comorbidities, demographics, etc.)
#
# The exposure column is `swang1` (received RHC or not).
# The outcome column we'll use is `dth30` (died within 30 days).

# Check dataset dimensions: 5,735 patients across 63 recorded metrics
dim(rhc_sample$data)
#> [1] 5735   63

# Verify the number of baseline clinical confounders to control
length(rhc_sample$covariates)
#> [1] 50
```

Before doing any statistical adjustment, look at the numbers exactly as
they sit in the raw data — no propensity scores, no matching, nothing
fancy:

``` r

raw_table <- table(
  RHC = rhc_sample$data$swang1,
  Died_30d = rhc_sample$data$dth30
)
raw_table
#>    Died_30d
#> RHC    0    1
#>   0 2463 1088
#>   1 1354  830

prop.table(raw_table, margin = 1)
#>    Died_30d
#> RHC         0         1
#>   0 0.6936074 0.3063926
#>   1 0.6199634 0.3800366
```

This is the comparison a lot of casual analyses stop at — and it’s
exactly the comparison you *cannot* trust yet. In the raw data, patients
who received RHC died at a noticeably higher rate — 38.0% versus 30.6%
among those who didn’t. That difference could genuinely be because RHC
is harmful, or it could simply be because RHC patients were sicker going
in. There is no way to tell which from this table alone. That is the
whole reason the rest of this walkthrough exists.

## Step 2 — Build a propensity score

A **propensity score** is just one number per patient: *given everything
we know about this patient before the procedure, how likely were they to
receive RHC?* Two patients with similar propensity scores looked
similarly “RHC-likely” going in, even if one happened to get the
procedure and the other didn’t.

``` r

ps <- build_ps_model(rhc_sample$data, "swang1", rhc_sample$covariates)
```

Before trusting anything downstream, we need to check that treated and
untreated patients actually *overlap* on this score — if RHC patients
and non-RHC patients occupy completely different ranges of risk, no
adjustment method can fairly compare them. This is called checking
**positivity**.

``` r

positivity <- check_positivity(ps)
positivity
#> Propensity-score positivity check
#> ================================
#> Support window: 0.01 to 0.99 
#>   exposure 0 (n=3551): PS [0.003, 0.955], median 0.236
#>   exposure 1 (n=2184): PS [0.019, 0.985], median 0.555
#> Positivity: VIOLATED (12 outside window)
#> IPTW weights (ATE): min 0.39, median 0.78, max 20.18, max/min ratio 52.2
```

**In plain terms:** the word “VIOLATED” above looks alarming, but read
the number next to it — only 12 of 5,735 patients (0.2%) fell slightly
outside the ideal overlap window. That is a minor, expected amount of
imperfect overlap in a dataset this size, not a reason to distrust the
analysis. IndepAssoc flags this automatically, using a strict,
all-or-nothing label, so that even a small amount of imperfect overlap
is never silently ignored — “VIOLATED” means “worth a look,” not “the
analysis is broken.”

## Step 3 — Match each treated patient to a similar untreated patient

Now we pair up patients: each RHC patient is matched to a non-RHC
patient who looked statistically similar beforehand (similar age,
illness severity, comorbidities, and so on).

``` r

matched <- match_cohort(ps, seed = 1)
```

## Step 4 — Confirm the matching actually worked

Matching *should* make the two groups look alike on everything except
the treatment itself. We don’t just assume that happened — we check it.

``` r

balance <- check_balance(matched)
plot_asmd_balance(balance, top_n = 15)
```

![Balance plot showing standardized differences between matched groups
for the most imbalanced covariates, before and after
matching.](clinician-walkthrough_files/figure-html/balance-1.png)

Each dot shows how different the two groups are on one factor. Dots
close to zero mean the groups are well balanced on that factor after
matching. This is the same idea as comparing two arms of a clinical
trial at baseline — except here, matching (rather than randomization) is
doing the balancing.

## Step 5 — Don’t trust just one method. Check it five ways.

This is the core idea behind IndepAssoc. Instead of picking one
statistical approach and hoping it’s the right one, we run the same
question through **five methods that each rely on different
assumptions**:

- **Regression** — builds a model of the outcome that includes RHC and
  the other patient factors at once, then reports RHC’s association with
  death after holding those other factors fixed.
- **Matching** — the pairing approach from Step 3: compare outcomes
  within each matched pair.
- **Stratification** — groups patients with similar propensity scores
  into bands, compares RHC vs. no-RHC within each band, then pools the
  results.
- **IPTW** (inverse probability of treatment weighting) — reweights
  patients so the RHC and non-RHC groups look alike on the confounders,
  then compares the reweighted groups.
- **AIPW** (augmented IPTW) — combines IPTW’s reweighting with a
  regression model, so the estimate stays reliable even if one of the
  two underlying models is imperfect — not just one or the other alone.

If all five approaches — built on different assumptions, prone to
different weaknesses — point the same direction, that is much stronger
evidence than any single method alone.

``` r

results <- run_pipeline(
  rhc_sample$data, "swang1", rhc_sample$covariates, "dth30",
  type = "binary",
  methods = c("regression", "matching", "stratification", "iptw", "aipw"),
  seed = 1
)
```

``` r

format_comparison(results$comparison)
#>           Method   OR    95% CI p-value    n
#> 1     Regression 1.49 1.28–1.72  <0.001 5735
#> 2       Matching 1.39 1.20–1.61  <0.001 3370
#> 3 Stratification 1.39 1.22–1.58  <0.001 5735
#> 4           IPTW 1.32 1.14–1.53  <0.001 5735
#> 5           AIPW 1.33 1.17–1.51  <0.001 5735
```

### What does an odds ratio mean?

Every row in the table above reports an **odds ratio (OR)** — a way of
comparing how likely an outcome is in one group versus another.

- **An OR of 1.0 means no difference at all** between the RHC and
  non-RHC groups.
- **An OR above 1.0 means higher odds of the outcome** (here, dying
  within 30 days) in the RHC group.
- The regression method above estimates an OR of **1.49** — in plain
  terms, patients who received RHC had roughly **49% higher odds** of
  dying within 30 days than similar patients who didn’t, after adjusting
  for the confounders listed earlier.

The other four methods estimate slightly different numbers (this is
expected — see the caveat below on why the methods don’t target the
exact same quantity), but every one of them lands above 1.0, and every
confidence interval excludes 1.0. That consistency is the finding.

**What’s the “95% CI” column?** It’s the range the true odds ratio
plausibly falls in, given the sample size and the noise in the data — a
narrower range means a more precise estimate. When that range doesn’t
include 1.0 (as in every row above), it means “no difference” is not a
plausible value given this data, which is why we say the finding is
statistically significant, not just a one-off number.

### Why do the five methods give slightly different numbers?

Each method asks the question in a slightly different way — some focus
on the patients who actually received RHC, others on the whole ICU
cohort. What matters for this walkthrough is not the exact decimal in
each row, but that all five point the same direction (odds above 1.0)
and all five exclude “no effect.” That agreement, despite each method
looking at the question from a different angle, is the robustness signal
— not any single row’s precise value. (See “What this does — and does
not — prove,” below, for exactly which population each method
describes.)

## Step 6 — The verdict

![Panel A: treated and untreated patients overlap well on the propensity
score. Panel B: after matching, the covariates that were most imbalanced
at baseline are brought close to the balance threshold. Panel C: all
five methods estimate an odds ratio above 1 for 30-day mortality, and
every confidence interval excludes “no
effect.”](../reference/figures/clinician-rhc-panel-summary.png)

Panel A: treated and untreated patients overlap well on the propensity
score. Panel B: after matching, the covariates that were most imbalanced
at baseline are brought close to the balance threshold. Panel C: all
five methods estimate an odds ratio above 1 for 30-day mortality, and
every confidence interval excludes “no effect.”

All five methods — despite resting on different statistical assumptions
— agree: the odds of dying within 30 days were higher in the RHC group,
and no method’s confidence interval crosses 1.0 (the “no effect” line).
That agreement, across five genuinely different approaches, is what
makes this a robust finding rather than an artifact of one particular
modeling choice.

### Key takeaways

- **The raw, unadjusted comparison (Step 1) cannot be trusted on its
  own** — sicker patients were more likely to receive RHC, so any
  difference seen there is tangled up with baseline illness severity.
- **After adjusting for confounders five independent ways, the finding
  held up.** Regression, matching, stratification, IPTW, and AIPW all
  estimate an odds ratio above 1.0, with confidence intervals that all
  exclude “no effect.”
- **Agreement across five different methods is much stronger evidence
  than any single adjusted model alone** — it means the finding isn’t an
  artifact of one particular method’s assumptions.
- **This is still an association, not proof of causation** — see below.

## What this does — and does not — prove

**This is an association, not proof of causation.** IndepAssoc adjusts
for every confounder that was *measured* in this dataset. It cannot
adjust for factors that were never recorded. This is the standard
**no-unmeasured-confounding** assumption behind every method shown here
— if some unmeasured factor made sicker patients both more likely to
receive RHC *and* more likely to die, no amount of statistical
adjustment can fully remove that.

It is also worth knowing that the five methods above don’t all target
the exact same underlying quantity — matching estimates the effect
*among patients who actually received RHC*, while IPTW and AIPW estimate
the effect *across the whole cohort*, for example. These are closely
related but not literally identical questions. See the [full RHC
vignette](https://mostafa-abbas.github.io/IndepAssoc/articles/rhc-validation.md)
for the precise breakdown.

What you can say, honestly and defensibly, is this: **across five
independent modeling approaches, the association between RHC and
increased 30-day mortality held up.** That is exactly the kind of
robustness check a single p-value from a single model can never give
you.

This does not mean RHC should never be used — it is often clinically
necessary, and this walkthrough says nothing about the individual
patients for whom it is the right call. But it does mean the decision to
place a catheter should account for this independently elevated risk,
rather than assume the procedure is neutral.

## Try it on your own data

The same six steps shown here — look at the raw numbers, build a
propensity score, check overlap, match, check balance, compare five
methods — work on any binary exposure and any outcome. See the
[quick-start
guide](https://mostafa-abbas.github.io/IndepAssoc/articles/indepassoc-quickstart.md)
to run this on your own cohort.
