# Strategic Plan & OpenCode Directives: Portfolio Optimization & Refactoring for IndepAssoc

## 1. Portfolio Alignment & Senior Data Scientist Positioning

To position `IndepAssoc` as a standout portfolio piece for a **Senior
Data Scientist / Causal Inference Specialist in Healthcare Analytics**,
the package must bridge rigorous academic epidemiology with
enterprise-grade software engineering.

### Key Portfolio Pillars:

1.  **Methodological Rigor**: Demonstrate deep understanding of
    observational study designs, propensity score matching (PSM),
    conditional logistics, inverse probability of treatment weighting
    (IPTW), and doubly robust estimation (AIPW).
2.  **Production-Grade Architecture**: Clean functional code, modular
    design, full test coverage (`testthat`), clear error handling
    (`tryCatch`), robust data handling, and CRAN-level standards.
3.  **Humanized Professional Documentation**: Elimination of robotic AI
    jargon (“delve”, “testament”, “realm”, “pivotal”, “in conclusion”).
    Narrative focus on clinical utility, epidemiological domain context,
    statistical trade-offs, and actionable insights.

------------------------------------------------------------------------

## 2. Structural Refactoring & Data Consolidation

### The Problem:

Scatter of raw data files across multiple directories (`rhc_data/`,
`data/`, temporary CSVs) creates maintenance clutter and risks broken
build pipelines.

### The Solution:

Consolidate data generation and processing into a single canonical
pipeline structure: - **`data-raw/`**: Contains raw downloads and
reproducible generation scripts (`simulate_example_cohort.R`,
`prepare_rhc.R`). - **`data/`**: Clean, binary `.rda` files created via
[`usethis::use_data()`](https://usethis.r-lib.org/reference/use_data.html)
for internal package use, vignettes, and unit tests
(`example_cohort.rda`, `rhc_sample.rda`). - **Data Helper
Consolidation**: Integrate
[`prepare_rhc_data()`](https://mostafa-abbas.github.io/IndepAssoc/reference/prepare_rhc_data.md)
into `R/data_helpers.R` to parse missing codes (`"NA"` vs `cat2`
missingness), recode binary exposures cleanly, and isolate heavy
missingness columns (`adld3p`, `urin1`) without manual directory
juggling.

------------------------------------------------------------------------

## 3. Detailed Action Plan for OpenCode

### Stage 1: Data Architecture & Folder Cleanup

- Clean up redundant folders (`rhc_data/`).
- Centralize raw data processing in `data-raw/` and export optimized
  `.rda` files into `data/`.
- Ensure `R/data_helpers.R` contains robust parsing for clinical
  datasets with custom missing value handlers.

### Stage 2: Core Estimator & Pipeline Fixes

- **Phase 1 Alignment (`matching` estimator)**: Ensure
  `fit_outcome(..., method = "matching")` uses
  [`survival::clogit()`](https://rdrr.io/pkg/survival/man/clogit.html)
  for binary outcomes with stratum conditioning on `match_num`, matching
  the methodology of the source CABG and LAAC/POAF papers.
- **Phase 2 Resiliency (`fit_all_models`)**: Wrap mixed-effects logistic
  models ([`lme4::glmer`](https://rdrr.io/pkg/lme4/man/glmer.html)) in
  defensive `tryCatch` blocks to handle constant-response subsets
  gracefully without crashing the whole pipeline.
- **Phase 3 Reproducibility**: Enforce explicit seeding across all
  stochastic matching functions (`run_pipeline(..., seed = ...)`) and
  propagate seeds down to `MatchIt`.

### Stage 3: Professional & Humanized Documentation Polish

- **Remove AI Voice**: Audit all Vignettes, `README.md`, `NEWS.md`, and
  Roxygen docs for synthetic AI phrases. Rewrite in a direct, clinical,
  and authoritative tone suitable for senior peer-review.
- **Vignette Strategy**:
  1.  `vignettes/indepassoc-quickstart.Rmd`: Clean quick-start on
      synthetic data.
  2.  `vignettes/rhc-validation.Rmd`: Deep-dive observational study
      benchmarking on the Connors et al. RHC dataset, comparing 5
      adjustment methods.
  3.  `vignettes/causal-benchmarks.Rmd`: Methodological comparison
      against
      [`causaldata::nhefs`](https://rdrr.io/pkg/causaldata/man/nhefs.html)
      and
      [`MatchIt::lalonde`](https://kosukeimai.github.io/MatchIt/reference/lalonde.html).

------------------------------------------------------------------------

## 4. OpenCode Prompt Specification

Below is the complete prompt to feed directly into OpenCode to execute
this comprehensive plan end-to-end.
