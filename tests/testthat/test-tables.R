test_that("table_matched resolves group=strata and valid paired tests", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  tbl <- table_matched(m, c("age", "diabetes"))
  expect_s3_class(tbl, "gtsummary")
  if ("diabetes" %in% names(m$data)) {
    expect_s3_class(tbl, "tbl_merge")
  }
})
