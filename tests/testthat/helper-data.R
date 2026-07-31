# Helper: simulate a small cohort for testing
simulate_test_cohort <- function(n = 200, seed = 123) {
  set.seed(seed)

  age <- rnorm(n, 65, 10)
  diabetes <- rbinom(n, 1, 0.3)
  hypertension <- rbinom(n, 1, 0.5)

  logit_exposure <- -2 + 0.03 * age + 0.5 * diabetes + 0.3 * hypertension
  prob_exposure <- 1 / (1 + exp(-logit_exposure))
  exposure <- rbinom(n, 1, prob = prob_exposure)

  logit_outcome <- -3 + 0.5 * exposure + 0.04 * age + 0.8 * diabetes
  prob_outcome <- 1 / (1 + exp(-logit_outcome))
  outcome <- rbinom(n, 1, prob = prob_outcome)

  data.frame(
    exposure = exposure,
    age = age,
    diabetes = diabetes,
    hypertension = hypertension,
    outcome = outcome,
    time = rexp(n, 0.01),
    event = rbinom(n, 1, 0.7)
  )
}
