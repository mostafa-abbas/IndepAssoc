# Simulated Example Cohort

A simulated dataset mimicking a retrospective cardiac surgery cohort for
demonstrating the `IndepAssoc` pipeline. Contains a binary exposure
(e.g., sex), several baseline covariates, a binary outcome, and a
continuous outcome.

## Usage

``` r
example_cohort
```

## Format

A data frame with 500 rows and 7 variables:

- exposure:

  Binary exposure (0/1).

- age:

  Continuous covariate (years).

- diabetes:

  Binary covariate (0/1).

- hypertension:

  Binary covariate (0/1).

- bmi:

  Continuous covariate (kg/m2).

- outcome_binary:

  Binary outcome (0/1).

- outcome_continuous:

  Continuous outcome.

## Examples

``` r
data(example_cohort)
str(example_cohort)
#> 'data.frame':    500 obs. of  7 variables:
#>  $ exposure          : int  1 0 1 1 1 0 0 0 1 1 ...
#>  $ age               : num  78.7 59.4 68.6 71.3 69 ...
#>  $ diabetes          : int  1 0 1 0 0 0 0 1 0 1 ...
#>  $ hypertension      : int  0 1 0 1 0 1 1 0 0 0 ...
#>  $ bmi               : num  39.6 30.6 32.9 29.9 23 ...
#>  $ outcome_binary    : int  1 1 1 0 1 0 0 1 1 1 ...
#>  $ outcome_continuous: num  95.6 80.3 80.7 79.6 80.1 ...
```
