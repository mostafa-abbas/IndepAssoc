# Explicit Wald confidence interval for a fitted model's coefficients

`confint(..., method = "Wald")` is silently ignored by most model
classes (`glm`/`lmer` use profile likelihood, `lm` uses t-quantiles,
`clogit`/`plm` use profile likelihood), so it does not guarantee a Wald
interval. Compute the Wald interval explicitly from
`coef +/- qnorm(0.975) * SE`.

## Usage

``` r
.wald_confint(model, rows)
```

## Examples

``` r
fit <- glm(outcome_binary ~ exposure + age,
           data = example_cohort, family = "binomial")
IndepAssoc:::.wald_confint(fit, "exposure")
#>              2.5 %   97.5 %
#> exposure 0.2491034 1.010243
```
