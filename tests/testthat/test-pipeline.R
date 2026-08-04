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

test_that("run_pipeline returns a comparison table across methods", {
  d <- simulate_test_cohort()
  res <- run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                      type = "binary",
                      methods = c("regression", "iptw", "aipw"))
  expect_s3_class(res, "IndepAssoc")
  expect_true("comparison" %in% names(res))
  expect_equal(nrow(res$comparison), 3)
  expect_identical(names(res$comparison),
                   c("method", "label", "type", "estimate", "conf_low", "conf_high", "p_value", "n"))
})

test_that("run_pipeline prints sequentially numbered step messages in execution order", {
  d <- simulate_test_cohort()
  msgs <- testthat::capture_messages(
    suppressWarnings(
      run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                   type = "binary", methods = "regression")
    )
  )
  steps <- unlist(regmatches(msgs, gregexpr("Step [0-9]+/[0-9]+", msgs)))
  expect_false(any(grepl("Step 6b", msgs)))
  expect_identical(steps, paste0("Step ", 1:9, "/9"))
})

test_that("run_pipeline completes on a constant binary response", {
  d <- simulate_test_cohort()
  d$outcome <- 0L
  res <- suppressWarnings(run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    type = "binary",
    methods = "regression"
  ))
  expect_s3_class(res, "IndepAssoc")
})
