# Build Propensity Score Model

Fits a logistic regression model predicting exposure from covariates,
then appends predicted propensity scores to the data.

## Usage

``` r
build_ps_model(data, exposure, covariates, family = "binomial")
```

## Arguments

- data:

  Data frame containing the cohort. Must have at least 4 rows and at
  least 2 units in each exposure arm; a non-fatal warning is emitted
  when either arm has fewer than 10 units.

- exposure:

  Character string naming the binary exposure variable.

- covariates:

  Character vector of covariate names to adjust for.

- family:

  GLM family; default `"binomial"` for logistic regression.

## Value

A list of class `"IndepPSModel"` with elements:

- model:

  The fitted `glm` object.

- data:

  Data frame with an added `.ps` column (propensity scores).

- exposure:

  Name of the exposure variable.

- covariates:

  Character vector of covariates used.

## Examples

``` r
data(example_cohort)
ps <- build_ps_model(example_cohort, "exposure",
                     c("age", "diabetes", "hypertension", "bmi"))
summary(ps$model)$coefficients
#>                 Estimate Std. Error    z value    Pr(>|z|)
#> (Intercept)  -2.28986906 0.86724090 -2.6404071 0.008280648
#> age           0.02961410 0.01020326  2.9024155 0.003702971
#> diabetes      0.61916877 0.22644801  2.7342645 0.006251979
#> hypertension  0.12384881 0.19382912  0.6389587 0.522849768
#> bmi           0.03060021 0.02014597  1.5189251 0.128781349
```
