# Simulate example cohort for IndepAssoc
set.seed(42)
n <- 500

# Covariates
age <- rnorm(n, mean = 65, sd = 10)
diabetes <- rbinom(n, 1, prob = 0.3)
hypertension <- rbinom(n, 1, prob = 0.5)
bmi <- rnorm(n, mean = 28, sd = 5)

# Exposure influenced by covariates (confounding)
logit_exposure <- -2 + 0.03 * age + 0.5 * diabetes + 0.3 * hypertension + 0.02 * bmi
prob_exposure <- 1 / (1 + exp(-logit_exposure))
exposure <- rbinom(n, 1, prob = prob_exposure)

# Outcomes (true exposure effect OR = 1.5 for binary, beta = 2.0 for continuous)
logit_outcome <- -3 + 0.5 * exposure + 0.04 * age + 0.8 * diabetes + 0.4 * hypertension
prob_outcome <- 1 / (1 + exp(-logit_outcome))
outcome_binary <- rbinom(n, 1, prob = prob_outcome)

outcome_continuous <- 50 + 2.0 * exposure + 0.5 * age + 3 * diabetes + 2 * hypertension + rnorm(n, 0, 5)

example_cohort <- data.frame(
  exposure = exposure,
  age = age,
  diabetes = diabetes,
  hypertension = hypertension,
  bmi = bmi,
  outcome_binary = outcome_binary,
  outcome_continuous = outcome_continuous
)

usethis::use_data(example_cohort, overwrite = TRUE)
