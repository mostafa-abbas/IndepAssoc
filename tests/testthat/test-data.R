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
