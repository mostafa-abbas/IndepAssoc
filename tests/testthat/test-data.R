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
  script <- normalizePath(file.path("..", "..", "data-raw", "simulate_data.R"))
  expect_true(file.exists(script))
  lines <- readLines(script)
  expect_true(any(grepl("set.seed", lines)))
  expect_true(any(grepl("use_data", lines)))
})
