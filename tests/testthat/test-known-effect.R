test_that("all five methods recover the known binary treatment effect", {
  set.seed(1)
  d <- simulate_test_cohort(n = 2000, seed = 123)
  res <- run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    type = "binary",
    methods = c("regression", "matching", "stratification", "iptw", "aipw")
  )
  comp <- res$comparison
  expect_equal(nrow(comp), 5)
  expect_equal(comp$method, c("regression", "matching", "stratification", "iptw", "aipw"))
  for (m in comp$method) {
    est <- comp$estimate[comp$method == m]
    expect_lt(abs(log(est) - 0.5), 0.20)
  }
})

test_that("all five methods recover the known continuous treatment effect", {
  set.seed(1)
  d <- simulate_test_cohort(n = 2000, seed = 123)
  res <- run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome_continuous",
    type = "continuous",
    methods = c("regression", "matching", "stratification", "iptw", "aipw")
  )
  comp <- res$comparison
  expect_equal(nrow(comp), 5)
  for (m in comp$method) {
    est <- comp$estimate[comp$method == m]
    expect_lt(abs(est - 2.0), 0.50)
  }
})
