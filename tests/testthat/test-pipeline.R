test_that("run_pipeline returns full result", {
  d <- simulate_test_cohort()
  res <- run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    type = "binary"
  )

  expect_s3_class(res, "IndepAssoc")
  expect_s3_class(res$ps_model, "IndepPSModel")
  expect_s3_class(res$matched, "IndepMatch")
  expect_s3_class(res$balance, "IndepBalance")
  expect_s3_class(res$models, "IndepOutcomeModels")
  expect_true("OR" %in% names(res$models$summary_w))
})

test_that("print.IndepAssoc works", {
  d <- simulate_test_cohort()
  res <- run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    type = "binary"
  )
  expect_output(print(res), "IndepAssoc Pipeline Result")
})
