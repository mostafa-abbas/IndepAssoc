test_that("match_cohort returns correct structure", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))

  expect_s3_class(m, "IndepMatch")
  expect_true("strata" %in% names(m$data))
  expect_true(nrow(m$data) > 0)
  expect_true(nrow(m$data) <= nrow(d))
  expect_equal(m$ps_model$exposure, "exposure")
})

test_that("match_cohort respects caliper and ratio", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps, caliper = 0.1, ratio = 2))

  expect_s3_class(m, "IndepMatch")
  expect_true(nrow(m$data) > 0)
})

test_that("match_cohort applies seed and leaves RNG at the seeded state", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  runif(1)
  set.seed(42)
  expected <- .Random.seed
  set.seed(999)
  m <- suppressWarnings(match_cohort(ps, seed = 42))
  expect_identical(.Random.seed, expected)
  expect_s3_class(m, "IndepMatch")
})

test_that("match_cohort with a fixed seed is reproducible", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m1 <- suppressWarnings(match_cohort(ps, seed = 42))
  m2 <- suppressWarnings(match_cohort(ps, seed = 42))
  expect_identical(m1$data$match_num, m2$data$match_num)
})

test_that("match_cohort without a seed leaves RNG state unchanged (current behavior)", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  runif(1)
  set.seed(999)
  pre <- .Random.seed
  m1 <- suppressWarnings(match_cohort(ps))
  expect_identical(.Random.seed, pre)
  m2 <- suppressWarnings(match_cohort(ps))
  expect_identical(m1$data$match_num, m2$data$match_num)
})
