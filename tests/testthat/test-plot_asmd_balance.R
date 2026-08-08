test_that(".asmd_tables rejects non-list input", {
  expect_error(IndepAssoc:::.asmd_tables("nope"),
               "Invalid matching result object provided.")
  expect_error(IndepAssoc:::.asmd_tables(list(foo = 1)),
               "Invalid matching result object provided.")
  expect_error(IndepAssoc:::.asmd_tables(
    list(match_summ = list(all = NULL, matched = NULL))
  ), "Invalid matching result object provided.")
})

test_that(".asmd_tables extracts match_summ with abs()", {
  all_tab <- data.frame("Std. Mean Diff." = c(-0.25, 0.10),
                        row.names = c("age", "diabetes"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(-0.05, 0.02),
                            row.names = c("age", "diabetes"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  tabs <- IndepAssoc:::.asmd_tables(res)
  expect_equal(tabs$unadjusted$Variable, c("age", "diabetes"))
  expect_equal(tabs$unadjusted$ASMD, c(0.25, 0.10))
  expect_equal(tabs$matched$ASMD, c(0.05, 0.02))
})

test_that(".asmd_tables prefers an explicit ASMD column", {
  all_tab <- data.frame(ASMD = c(0.1), "Std. Mean Diff." = c(0.9),
                        row.names = "age", check.names = FALSE)
  matched_tab <- data.frame(ASMD = c(0.01), "Std. Mean Diff." = c(0.09),
                            row.names = "age", check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  tabs <- IndepAssoc:::.asmd_tables(res)
  expect_equal(tabs$unadjusted$ASMD, 0.1)
  expect_equal(tabs$matched$ASMD, 0.01)
})

test_that(".asmd_tables falls back to the first numeric column", {
  all_tab <- data.frame(Means = c(1.5), Var = c(3.0), row.names = "age")
  matched_tab <- data.frame(Means = c(1.0), Var = c(1.5), row.names = "age")
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  tabs <- IndepAssoc:::.asmd_tables(res)
  expect_equal(tabs$unadjusted$ASMD, 1.5)
  expect_equal(tabs$matched$ASMD, 1.0)
})

test_that("plot_asmd_balance returns a ggplot from find_matching_data_summary output", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(find_matching_data_summary(
    d, "exposure", c("age", "diabetes", "hypertension")
  ))
  p <- plot_asmd_balance(res)
  expect_s3_class(p, "ggplot")
  expect_equal(levels(p$data$Cohort), c("Unadjusted", "Matched"))
})

test_that("plot_asmd_balance accepts run_pipeline output", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = d, exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome", type = "binary",
    methods = "regression", seed = 1
  )))
  p <- plot_asmd_balance(res)
  expect_s3_class(p, "ggplot")
})

test_that("plot_asmd_balance accepts check_balance output", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  bal <- check_balance(m)
  p <- plot_asmd_balance(bal)
  expect_s3_class(p, "ggplot")
})

test_that("plot_asmd_balance rejects invalid input", {
  expect_error(plot_asmd_balance(list(foo = 1)),
               "Invalid matching result object provided.")
  expect_error(plot_asmd_balance("not a list"),
               "Invalid matching result object provided.")
})

test_that("plot_asmd_balance plots absolute values", {
  all_tab <- data.frame("Std. Mean Diff." = c(-0.25, 0.10),
                        row.names = c("age", "diabetes"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(-0.05, 0.02),
                            row.names = c("age", "diabetes"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res)
  built <- ggplot2::ggplot_build(p)
  expect_true(all(built$data[[1]]$y >= 0))
})

test_that("plot_asmd_balance filters non-covariate rows", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.5, 0.3, 0.1, 0.4, 0.2),
                        row.names = c("distance", "age", "diabetes",
                                      "propensity scores", "(Intercept)"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.1, 0.05, 0.02, 0.08, 0.03),
                            row.names = c("distance", "age", "diabetes",
                                          "propensity scores", "(Intercept)"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res)
  expect_false(any(c("distance", "propensity scores", "(Intercept)") %in%
                     levels(p$data$Variable)))
  expect_true(all(c("age", "diabetes") %in% levels(p$data$Variable)))
})

test_that("plot_asmd_balance preserves unmatched variable order", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.3, 0.1),
                        row.names = c("age", "bmi"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.02, 0.05),
                            row.names = c("bmi", "age"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res)
  expect_equal(levels(p$data$Variable), c("age", "bmi"))
})

test_that("plot_asmd_balance drops covariates with NA in both cohorts but keeps NA-in-one", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.2, NA, NA),
                        row.names = c("age", "bmi", "wasted_var"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.01, 0.05, NA),
                            row.names = c("age", "bmi", "wasted_var"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res)
  expect_false("wasted_var" %in% levels(p$data$Variable))
  expect_true(all(c("age", "bmi") %in% levels(p$data$Variable)))
})

test_that("plot_asmd_balance uses the manuscript colors and threshold line", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(find_matching_data_summary(
    d, "exposure", c("age", "diabetes", "hypertension")
  ))
  p <- plot_asmd_balance(res, threshold = 0.10)

  fill_scale <- p$scales$get_scales("fill")
  expect_equal(unname(fill_scale$palette(2)),
               c("#005A9C", "#E66101"))

  built <- ggplot2::ggplot_build(p)
  expect_equal(unique(built$data[[1]]$fill), c("#005A9C", "#E66101"))
  hline_data <- built$data[[2]]
  expect_equal(unique(hline_data$yintercept), 0.10)
})

test_that("plot_asmd_balance warns and returns an empty shell when no covariates remain", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.5),
                        row.names = c("distance"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.1),
                            row.names = c("distance"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  expect_warning(
    p <- plot_asmd_balance(res),
    "No valid covariate rows found to plot."
  )
  expect_s3_class(p, "ggplot")
  expect_equal(nrow(p$data), 0)
})

test_that("plot_love is removed; plot_asmd_balance is the single ASMD plot function", {
  expect_false("plot_love" %in% getNamespaceExports("IndepAssoc"))
})

test_that("plot_asmd_balance top_n keeps the top_n covariates ranked by unadjusted ASMD", {
  # unadjusted ranking selects var_a/var_b; matched ranking would select var_c/var_d,
  # so this discriminates between ranking on the two columns
  all_tab <- data.frame("Std. Mean Diff." = c(0.9, 0.8, 0.7, 0.1),
                        row.names = c("var_a", "var_b", "var_c", "var_d"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.05, 0.05, 0.5, 0.4),
                            row.names = c("var_a", "var_b", "var_c", "var_d"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res, top_n = 2)
  expect_equal(levels(p$data$Variable), c("var_a", "var_b"))
  expect_equal(nrow(p$data), 4)
  expect_equal(sort(as.character(unique(p$data$Cohort))), c("Matched", "Unadjusted"))
  expect_equal(p$labels$caption,
               "Showing 2 of 4 covariates with the largest unadjusted ASMD")
})

test_that("plot_asmd_balance top_n ignores non-covariate rows when ranking", {
  # distance has the largest unadjusted ASMD but must be excluded from the
  # ranking and from the reported total
  all_tab <- data.frame("Std. Mean Diff." = c(0.9, 0.8, 0.7, 0.1, 0.99),
                        row.names = c("var_a", "var_b", "var_c", "var_d", "distance"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.05, 0.05, 0.5, 0.4, 0.1),
                            row.names = c("var_a", "var_b", "var_c", "var_d", "distance"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res, top_n = 2)
  expect_equal(levels(p$data$Variable), c("var_a", "var_b"))
  expect_equal(p$labels$caption,
               "Showing 2 of 4 covariates with the largest unadjusted ASMD")
})

test_that("plot_asmd_balance without top_n shows the full set and no caption", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.3, 0.1, 0.2),
                        row.names = c("age", "bmi", "diabetes"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.02, 0.05, 0.01),
                            row.names = c("age", "bmi", "diabetes"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res)
  expect_equal(levels(p$data$Variable), c("age", "bmi", "diabetes"))
  expect_equal(nrow(p$data), 6)
  expect_null(p$labels$caption)
})

test_that("plot_asmd_balance top_n larger than the covariate count shows all and no caption", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.3, 0.1),
                        row.names = c("age", "bmi"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.02, 0.05),
                            row.names = c("age", "bmi"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  p <- plot_asmd_balance(res, top_n = 10)
  expect_equal(levels(p$data$Variable), c("age", "bmi"))
  expect_null(p$labels$caption)
})

test_that("plot_asmd_balance rejects invalid top_n", {
  all_tab <- data.frame("Std. Mean Diff." = c(0.3, 0.1),
                        row.names = c("age", "bmi"),
                        check.names = FALSE)
  matched_tab <- data.frame("Std. Mean Diff." = c(0.02, 0.05),
                            row.names = c("age", "bmi"),
                            check.names = FALSE)
  res <- list(match_summ = list(all = all_tab, matched = matched_tab))

  expect_error(plot_asmd_balance(res, top_n = 0), "top_n")
  expect_error(plot_asmd_balance(res, top_n = -1), "top_n")
  expect_error(plot_asmd_balance(res, top_n = NA), "top_n")
})

test_that("plot_asmd_balance top_n on the real RHC balance data keeps the top-25 by unadjusted ASMD", {
  data(rhc_sample)
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = rhc_sample$data,
    exposure = "swang1",
    covariates = rhc_sample$covariates,
    outcome = "dth30",
    type = "binary",
    methods = "regression",
    seed = 42
  )))

  full <- plot_asmd_balance(res)
  n_total <- length(levels(full$data$Variable))

  p <- plot_asmd_balance(res, top_n = 25)
  expect_equal(length(levels(p$data$Variable)), 25)
  expect_match(
    p$labels$caption,
    sprintf("Showing 25 of %d covariates with the largest unadjusted ASMD", n_total)
  )

  unadj <- full$data[full$data$Cohort == "Unadjusted", c("Variable", "ASMD")]
  unadj <- unadj[order(-unadj$ASMD), ]
  expect_equal(sort(levels(p$data$Variable)),
               sort(as.character(unadj$Variable[1:25])))
})
