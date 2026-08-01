test_that("subgroup_analysis warns when subgroup_var was not a matching covariate", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  expect_warning(
    subgroup_analysis(m, "outcome", "grp"),
    "not part of the covariates used for matching"
  )
})

test_that("subgroup_analysis does not warn when subgroup_var was a matching covariate", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  expect_warning(
    subgroup_analysis(m, "outcome", "age"),
    NA
  )
})

test_that("subgroup_analysis returns real estimates", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  out <- suppressWarnings(subgroup_analysis(m, "outcome", "grp"))
  expect_true(all(!is.na(out$estimate)))
  expect_equal(nrow(out), length(unique(d$grp)))
  expect_true(all(c("subgroup", "n", "estimate", "conf.low", "conf.high", "p.value") %in% names(out)))
})
