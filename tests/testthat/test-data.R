test_that("example_cohort matches its documented format", {
  expect_equal(nrow(example_cohort), 500)
  expect_identical(
    names(example_cohort),
    c("exposure", "age", "diabetes", "hypertension", "bmi",
      "outcome_binary", "outcome_continuous")
  )
  expect_true(all(vapply(example_cohort, function(x) !anyNA(x), logical(1))))
})

test_that("example_cohort is reproducible from data-raw script", {
  start <- dirname(normalizePath(testthat::test_path("."), mustWork = FALSE))
  dirs <- c(start)
  while (dirname(dirs[length(dirs)]) != dirs[length(dirs)]) {
    dirs <- c(dirs, dirname(dirs[length(dirs)]))
  }
  found <- dirs[vapply(dirs, function(d) file.exists(file.path(d, "data-raw", "simulate_example_cohort.R")), logical(1))][1]
  skip_if_not(!is.na(found), "data-raw/ is a development-only directory excluded from R CMD check")
  lines <- readLines(file.path(found, "data-raw", "simulate_example_cohort.R"))
  expect_true(any(grepl("set.seed", lines)))
  expect_true(any(grepl("use_data", lines)))
})

test_that("rhc_sample matches its documented format", {
  expect_type(rhc_sample, "list")
  expect_named(rhc_sample, c("data", "covariates"))
  expect_equal(nrow(rhc_sample$data), 5735)
  expect_equal(ncol(rhc_sample$data), 63)
  expect_length(rhc_sample$covariates, 50)
  expect_true(is.data.frame(rhc_sample$data))
  expect_true(is.character(rhc_sample$covariates))
})

test_that("rhc_sample preserves the preprocessing contract", {
  d <- rhc_sample$data
  expect_false("" %in% names(d))
  expect_equal(sum(d$swang1), 2184)
  expect_true(is.numeric(d$swang1))
  expect_true(is.numeric(d$dth30))
  expect_true(is.numeric(d$death))
  expect_true(is.numeric(d$los))
  expect_false(any(is.na(d$cat2)))
  expect_true(all(c("cat1", "cat2", "ca") %in% rhc_sample$covariates))
  expect_false("surv2md1" %in% rhc_sample$covariates)
  expect_equal(nrow(d[stats::complete.cases(d[, rhc_sample$covariates]), ]), 5735)
})
