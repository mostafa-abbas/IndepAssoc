test_that("table_matched resolves group=strata and valid paired tests", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  tbl <- table_matched(m, c("age", "diabetes"))
  expect_s3_class(tbl, "gtsummary")
  if ("diabetes" %in% names(m$data)) {
    expect_s3_class(tbl, "tbl_merge")
  }
})

test_that("table_unmatched errors on unknown covariate names", {
  d <- simulate_test_cohort()
  expect_error(
    table_unmatched(d, "exposure", c("age", "not_a_real_column")),
    "Covariates not found: not_a_real_column"
  )
})

test_that("table_matched errors on unknown covariate names", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_error(
    table_matched(m, c("age", "not_a_real_column")),
    "Covariates not found: not_a_real_column"
  )
})

test_that("covariate validation is consistent across pipeline entry points", {
  d <- simulate_test_cohort()
  bogus <- c("age", "diabetes", "hypertension", "not_a_real_column")
  entry_points <- list(
    ps_model   = function() build_ps_model(d, "exposure", bogus),
    fit_outcome = function() fit_outcome(d, "exposure", bogus, "outcome", type = "binary"),
    table_unmatched = function() table_unmatched(d, "exposure", bogus),
    run_pipeline = function() run_pipeline(d, "exposure", bogus, "outcome", type = "binary")
  )
  msgs <- vapply(entry_points, function(f) {
    tryCatch(conditionMessage(f()), error = function(e) conditionMessage(e))
  }, character(1))
  expect_true(all(grepl("Covariates not found: not_a_real_column", msgs, fixed = TRUE)))
})

test_that("table_matched pre-screens sparse factors that drop levels after matching", {
  data(rhc_sample)
  ps <- build_ps_model(rhc_sample$data, "swang1", rhc_sample$covariates)
  m <- match_cohort(ps, seed = 1)
  msgs <- testthat::capture_messages(table_matched(m, rhc_sample$covariates))
  expect_false(any(grepl("errors were returned during", msgs, ignore.case = TRUE)))
})
