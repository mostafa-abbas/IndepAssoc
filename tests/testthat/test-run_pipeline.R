test_that("run_pipeline auto-detects a continuous outcome when type is omitted", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome_continuous",
    methods = c("regression", "matching"),
    seed = 1
  )))

  expect_s3_class(res, "IndepAssoc")
  expect_equal(res$outcome_type, "continuous")
  expect_true("SC" %in% names(res$models$summary_w))
})

test_that("run_pipeline on rhc_sample continuous outcome completes without 'y values must be 0 <= y <= 1'", {
  data(rhc_sample)
  d <- rhc_sample$data[complete.cases(rhc_sample$data[, c("swang1", "los")]), ]
  res <- expect_no_error(
    suppressWarnings(suppressMessages(run_pipeline(
      data = d,
      exposure = "swang1",
      covariates = rhc_sample$covariates,
      outcome = "los",
      methods = c("regression", "matching"),
      seed = 1
    )))
  )
  expect_s3_class(res, "IndepAssoc")
  expect_equal(res$outcome_type, "continuous")
})

test_that("run_pipeline still defaults to binary for a 0/1 outcome", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    methods = c("regression", "matching"),
    seed = 1
  )))

  expect_equal(res$outcome_type, "binary")
  expect_true("OR" %in% names(res$models$summary_w))
})

test_that("run_pipeline matched Table 1 completes without gtsummary add_p errors on sparse factors", {
  data(rhc_sample)
  msgs <- testthat::capture_messages(
    suppressWarnings(run_pipeline(
      data = rhc_sample$data,
      exposure = "swang1",
      covariates = rhc_sample$covariates,
      outcome = "dth30",
      methods = c("regression", "matching"),
      seed = 1
    ))
  )
  expect_false(any(grepl("errors were returned during", msgs, ignore.case = TRUE)))
})

test_that("run_pipeline completes end-to-end with a label-coded factor exposure", {
  d <- simulate_test_cohort()
  d$exposure <- factor(d$exposure, labels = c("control", "treated"))
  res <- expect_no_error(suppressWarnings(suppressMessages(run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    methods = c("regression", "matching"),
    seed = 1
  ))))
  expect_s3_class(res, "IndepAssoc")
  expect_equal(res$outcome_type, "binary")
  expect_true("OR" %in% names(res$models$summary_w))
})
