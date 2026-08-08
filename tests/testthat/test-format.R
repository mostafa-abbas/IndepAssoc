make_comparison_df <- function(type = "continuous") {
  data.frame(
    method    = c("regression", "matching", "stratification", "iptw", "aipw"),
    label     = rep("outcome", 5),
    type      = rep(type, 5),
    estimate  = c(1.537680, 2.146948, 1.581406, 1.483272, 1.484582),
    conf_low  = c(0.5942670, 0.9511478, 0.4542341, 0.5107104, 0.5090073),
    conf_high = c(2.481092, 3.342748, 2.708577, 2.455833, 2.460157),
    p_value   = c(0.0014506971, 0.0005131617, 0.0059631379, 0.0028681300, 0.0029297046),
    n         = c(500L, 324L, 500L, 500L, 500L),
    stringsAsFactors = FALSE
  )
}

test_that("format_comparison rounds the estimate and renders the CI with an en dash", {
  out <- format_comparison(make_comparison_df())
  expect_equal(names(out), c("Method", "Mean Diff", "95% CI", "p-value", "n"))
  expect_equal(out$`Mean Diff`, c(1.54, 2.15, 1.58, 1.48, 1.48))
  expect_equal(out$`95% CI`, c("0.59\u20132.48", "0.95\u20133.34",
                               "0.45\u20132.71", "0.51\u20132.46", "0.51\u20132.46"))
  expect_equal(out$n, c(500L, 324L, 500L, 500L, 500L))
})

test_that("format_comparison derives the estimate column label from type", {
  bin <- format_comparison(make_comparison_df(type = "binary"))
  cont <- format_comparison(make_comparison_df(type = "continuous"))
  expect_equal(names(bin)[2], "OR")
  expect_equal(names(cont)[2], "Mean Diff")
})

test_that("format_comparison formats p-values with the <0.001 convention at the boundary", {
  df <- make_comparison_df(type = "binary")
  df$p_value <- c(0.05, 0.001001, 0.000999, 0.0014, 0.0002)
  out <- format_comparison(df)
  expect_equal(out$`p-value`, c("0.050", "0.001", "<0.001", "0.001", "<0.001"))
})

test_that("format_comparison generalizes the p-value threshold with p_digits", {
  df <- make_comparison_df()
  df$p_value <- c(0.0002, 0.00009, 0.000009, 0.001, 0.01)
  out <- format_comparison(df, p_digits = 4)
  expect_equal(out$`p-value`, c("0.0002", "<0.0001", "<0.0001", "0.0010", "0.0100"))
})

test_that("format_comparison capitalizes methods with iptw/aipw as all-caps acronyms", {
  out <- format_comparison(make_comparison_df())
  expect_equal(out$Method, c("Regression", "Matching", "Stratification", "IPTW", "AIPW"))
})

test_that("format_comparison validates its input", {
  expect_error(format_comparison("nope"), "data.frame")
  expect_error(format_comparison(make_comparison_df()[, -3]), "type")
  df <- make_comparison_df()
  df$type <- "ordinal"
  expect_error(format_comparison(df), "type")
  expect_error(format_comparison(make_comparison_df(), digits = -1), "digits")
  expect_error(format_comparison(make_comparison_df(), p_digits = -1), "p_digits")
})

test_that("format_combined formats a multi-outcome table and passes Outcome through", {
  bin <- make_comparison_df(type = "binary")
  cont <- make_comparison_df(type = "continuous")
  combined <- rbind(
    cbind(Outcome = "30-day mortality", bin),
    cbind(Outcome = "Hospital length of stay (days)", cont)
  )
  out <- format_combined(combined)
  expect_equal(names(out), c("Outcome", "Method", "Estimate", "95% CI", "p-value", "n"))
  expect_equal(out$Outcome, combined$Outcome)
  expect_equal(out$Method, c("Regression", "Matching", "Stratification", "IPTW", "AIPW",
                             "Regression", "Matching", "Stratification", "IPTW", "AIPW"))
  expect_equal(out$`95% CI`[1:5], c("0.59\u20132.48", "0.95\u20133.34",
                                    "0.45\u20132.71", "0.51\u20132.46", "0.51\u20132.46"))
  expect_equal(out$`p-value`, c("0.001", "<0.001", "0.006", "0.003", "0.003",
                                "0.001", "<0.001", "0.006", "0.003", "0.003"))
  expect_equal(out$n, c(500L, 324L, 500L, 500L, 500L, 500L, 324L, 500L, 500L, 500L))
})

test_that("format_combined requires an Outcome column", {
  expect_error(format_combined(make_comparison_df()), "Outcome")
})

test_that("export_results writes comparison.csv at full precision, not display-rounded", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = d, exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome", type = "binary",
    methods = "regression", seed = 1
  )))
  out <- tempfile("export_")
  suppressMessages(export_results(res, output_dir = out))
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  csv <- read.csv(file.path(out, "comparison.csv"), stringsAsFactors = FALSE)
  expect_equal(csv$estimate, res$comparison$estimate, tolerance = 1e-6)
  expect_equal(csv$conf_low, res$comparison$conf_low, tolerance = 1e-6)
  expect_equal(csv$conf_high, res$comparison$conf_high, tolerance = 1e-6)
  expect_equal(csv$p_value, res$comparison$p_value, tolerance = 1e-6)
})
