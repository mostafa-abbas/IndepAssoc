test_that(".ensure_match_num adds match_num from strata", {
  d <- data.frame(strata = c(1, 1, 2, 2), x = 1:4)
  out <- IndepAssoc:::.ensure_match_num(d)
  expect_true("match_num" %in% names(out))
  expect_type(out$match_num, "double")
  expect_equal(out$match_num, c(1, 1, 2, 2))
})

test_that(".ensure_match_num keeps existing match_num", {
  d <- data.frame(match_num = 1:3, strata = 1:3, x = 1:3)
  out <- IndepAssoc:::.ensure_match_num(d)
  expect_identical(out$match_num, 1:3)
})

test_that(".ensure_match_num errors without match_num or strata", {
  d <- data.frame(x = 1:3)
  expect_error(IndepAssoc:::.ensure_match_num(d), "match_num")
})

test_that("export_results writes comparison.csv", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                      type = "binary", methods = c("regression", "iptw", "aipw")))
  out_dir <- tempfile("indepassoc_export_")
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)
  export_results(res, output_dir = out_dir)
  expect_true(file.exists(file.path(out_dir, "comparison.csv")))
  comp <- read.csv(file.path(out_dir, "comparison.csv"))
  expect_equal(nrow(comp), 3)
  expect_identical(names(comp),
                   c("method", "label", "type", "estimate", "conf_low", "conf_high", "p_value", "n"))
})
