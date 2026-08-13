# IndepAssoc — Documentation Clarity Pass (README + all 3 vignettes)

> Working spec for OpenCode. This plan touches ONLY documentation:
> README.md, vignettes/indepassoc-quickstart.Rmd,
> vignettes/causal-benchmarks.Rmd, vignettes/rhc-validation.Rmd, and
> image assets under man/figures/. Do not touch anything in R/, tests/,
> DESCRIPTION, NAMESPACE, or any .Rd file. If a change to any of those
> files would be needed to accomplish something in this plan, stop and
> ask rather than making it.
>
> Audience: primarily clinicians and non-statisticians who do not know
> what a propensity score, IPTW, or a confounder-adjusted estimate is.
> Every rewrite must be readable by that audience WITHOUT losing
> statistical precision – simplify the language and structure, never the
> substance. Every existing caveat, disclaimer, and statistical nuance
> (non-collapsibility, the ATE vs

``` R
                                          > ATT distinction, "association not causation", the los right-skew caveat,
                                          > etc.) must survive the rewrite intact in meaning, even if the wording gets
```

> simpler.
>
> Same process as every prior plan: dedicated branch per phase -\> show
> the full diff for review -\> for phases touching a vignette, actually
> render it and confirm output before considering the phase done -\>
> stop and report -\> wait for my explicit go-ahead before merging and
> starting the next phase.
>
> Do not bump the package version, do not tag, do not push, without a
> separate explicit go-ahead after the final phase.

## Context

The package’s identity is currently buried under jargon: the README
leads with “confounder-adjusted… propensity-score…” before explaining
why anyone should care, and the three vignette titles read like
methods-research papers rather than what they actually are – a
quick-start guide, a proof the package gets known answers right, and a
real clinical case study.

The core identity to lead with everywhere: **IndepAssoc checks whether
an exposure-outcome association survives being tested five independent
statistical ways, so you can tell a real signal from a modeling
artifact.**

Two image assets are needed, both self-contained (no dependency on any
external stylesheet or CSS variables that won’t exist in a raw GitHub
README or the built pkgdown site – use plain hex colors, inline or in an
embedded
