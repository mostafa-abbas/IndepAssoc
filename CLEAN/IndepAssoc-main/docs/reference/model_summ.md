# Summarize a glm/lm/clogit model for the treatment effect

Summarize a glm/lm/clogit model for the treatment effect

## Usage

``` r
model_summ(model, treatment_feature, type = c("binary", "continuous"))
```

## Details

The exposure's coefficient rows are selected by exact name match, or —
for a factor exposure — by the factor levels recovered from the model
frame (`<feature><level>`), never by substring matching, so a covariate
whose name shares the exposure name as a prefix cannot steal the row. A
multi-level factor exposure returns one row per non-reference level. A
treatment with no coefficient row in the model errors rather than
silently selecting a different term.

## Examples

``` r
fit <- glm(outcome_binary ~ exposure + age,
           data = example_cohort, family = "binomial")
IndepAssoc:::model_summ(fit, "exposure", type = "binary")
#>           Estimate Std. Error  z value    Pr(>|z|)     2.5 %   97.5 %       OR
#> exposure 0.6296734  0.1941719 3.242865 0.001183341 0.2491034 1.010243 1.876997
#>             lower    upper
#> exposure 1.282875 2.746269
```
