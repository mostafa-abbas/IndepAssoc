test_that("run_pipeline returns full result", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    type = "binary"
  ))

  expect_s3_class(res, "IndepAssoc")
  expect_s3_class(res$ps_model, "IndepPSModel")
  expect_s3_class(res$matched, "IndepMatch")
  expect_s3_class(res$balance, "IndepBalance")
  expect_s3_class(res$models, "IndepOutcomeModels")
  expect_true("OR" %in% names(res$models$summary_w))
})

test_that("print.IndepAssoc works", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(run_pipeline(
    data = d,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension"),
    outcome = "outcome",
    type = "binary"
  ))
  expect_output(print(res), "IndepAssoc Pipeline Result")
})

test_that("run_pipeline returns a comparison table across methods", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                      type = "binary",
                      methods = c("regression", "iptw", "aipw")))
  expect_s3_class(res, "IndepAssoc")
  expect_true("comparison" %in% names(res))
  expect_equal(nrow(res$comparison), 3)
  expect_identical(names(res$comparison),
                   c("method", "label", "type", "estimate", "conf_low", "conf_high", "p_value", "n"))
})

test_that("run_pipeline prints sequentially numbered step messages in execution order", {
  d <- simulate_test_cohort()
  msgs <- testthat::capture_messages(
    suppressWarnings(
      run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                   type = "binary", methods = "regression")
    )
  )
  steps <- unlist(regmatches(msgs, gregexpr("Step [0-9]+/[0-9]+", msgs)))
  expect_false(any(grepl("Step 6b", msgs)))
  expect_identical(steps, paste0("Step ", 1:9, "/9"))
})

test_that("run_pipeline errors on a constant binary response", {
  d <- simulate_test_cohort()
  d$outcome <- 0L
  expect_error(
    suppressWarnings(suppressMessages(run_pipeline(
      data = d,
      exposure = "exposure",
      covariates = c("age", "diabetes", "hypertension"),
      outcome = "outcome",
      type = "binary",
      methods = "regression"
    ))),
    "zero variance"
  )
})

test_that("run_pipeline with a fixed seed is reproducible", {
  d <- simulate_test_cohort()
  r1 <- suppressWarnings(suppressMessages(run_pipeline(
    d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
    type = "binary", methods = c("regression", "matching"), seed = 1)))
  r2 <- suppressWarnings(suppressMessages(run_pipeline(
    d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
    type = "binary", methods = c("regression", "matching"), seed = 1)))
  expect_identical(r1$comparison, r2$comparison)
  expect_identical(r1$matched_data$match_num, r2$matched_data$match_num)
})

test_that("run_pipeline applies the seed at the top (RNG state check)", {
  d <- simulate_test_cohort()
  runif(1)
  set.seed(42)
  expected <- .Random.seed
  invisible(suppressWarnings(suppressMessages(run_pipeline(
    d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
    type = "binary", methods = c("regression", "matching"), seed = 42))))
  expect_identical(.Random.seed, expected)
})

test_that("run_pipeline result includes balance_plot with one bar per covariate and stage", {
  data(example_cohort)
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = example_cohort,
    exposure = "exposure",
    covariates = c("age", "diabetes", "hypertension", "bmi"),
    outcome = "outcome_binary",
    type = "binary",
    methods = "regression",
    seed = 1
  )))

  expect_true("balance_plot" %in% names(res))
  p <- res$balance_plot
  expect_s3_class(p, "ggplot")

  all_vars <- rownames(res$balance_pre)
  keep <- !all_vars %in% c("distance", "propensity scores", "(Intercept)") &
    !is.na(all_vars)
  pre_asmd <- abs(as.numeric(res$balance_pre[["Diff.Un"]]))
  post_asmd <- abs(as.numeric(res$balance_post[["Diff.Adj"]]))
  keep_vars <- all_vars[keep][!(is.na(pre_asmd[keep]) & is.na(post_asmd[keep]))]

  expect_equal(sort(levels(p$data$Variable)), sort(keep_vars))
  expect_equal(nrow(p$data), 2 * length(keep_vars))
})

test_that("run_pipeline balance_plot reflects a non-default balance_threshold on rhc_sample", {
  data(rhc_sample)
  res <- suppressWarnings(suppressMessages(run_pipeline(
    data = rhc_sample$data,
    exposure = "swang1",
    covariates = rhc_sample$covariates,
    outcome = "dth30",
    type = "binary",
    methods = "regression",
    balance_threshold = 0.15,
    seed = 42
  )))

  p <- res$balance_plot
  expect_s3_class(p, "ggplot")

  all_vars <- rownames(res$balance_pre)
  keep <- !all_vars %in% c("distance", "propensity scores", "(Intercept)") &
    !is.na(all_vars)
  pre_asmd <- abs(as.numeric(res$balance_pre[["Diff.Un"]]))
  post_asmd <- abs(as.numeric(res$balance_post[["Diff.Adj"]]))
  keep_vars <- all_vars[keep][!(is.na(pre_asmd[keep]) & is.na(post_asmd[keep]))]

  expect_equal(sort(levels(p$data$Variable)), sort(keep_vars))
  expect_equal(nrow(p$data), 2 * length(keep_vars))

  built <- ggplot2::ggplot_build(p)
  hline_layer <- built$data[[2]]
  expect_equal(unique(hline_layer$yintercept), 0.15)
})
