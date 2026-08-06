test_that("subgroup_analysis warns when subgroup_var was not a matching covariate", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_warning(
    subgroup_analysis(m, "outcome", "grp"),
    "not part of the covariates used for matching"
  )
})

test_that("subgroup_analysis does not warn when subgroup_var was a matching covariate", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_warning(
    subgroup_analysis(m, "outcome", "age"),
    NA
  )
})

test_that("subgroup_analysis returns real estimates", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  out <- suppressWarnings(subgroup_analysis(m, "outcome", "grp"))
  expect_true(all(!is.na(out$estimate)))
  expect_equal(nrow(out), length(unique(d$grp)))
  expect_true(all(c("subgroup", "n", "estimate", "conf_low", "conf_high", "p_value") %in% names(out)))
})

test_that("subgroup_analysis returns underscore column names", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  out <- suppressWarnings(subgroup_analysis(m, "outcome", "grp"))
  expect_true(all(c("subgroup", "n", "estimate", "conf_low", "conf_high", "p_value") %in% names(out)))
  expect_false(any(c("conf.low", "conf.high", "p.value") %in% names(out)))
})

test_that("subgroup_analysis honors an explicit method", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  out <- suppressWarnings(subgroup_analysis(m, "outcome", "grp", method = "iptw"))
  expect_true(all(!is.na(out$estimate)))
  expect_error(suppressWarnings(subgroup_analysis(m, "outcome", "grp", method = "iptw")), NA)
})

test_that("subgroup_analysis errors on a vector method", {
  d <- simulate_test_cohort()
  d$grp <- sample(c("A", "B"), nrow(d), replace = TRUE)
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_error(subgroup_analysis(m, "outcome", "grp",
                                method = c("regression", "iptw")),
               "single method")
})

test_that("subgroup_analysis drops a constant subgroup_var from the covariate set", {
  d <- simulate_test_cohort()
  d$grp <- factor(sample(c("A", "B"), nrow(d), replace = TRUE))
  covs <- c("age", "diabetes", "hypertension", "grp")
  ps <- build_ps_model(d, "exposure", covs)
  m <- suppressWarnings(match_cohort(ps))

  for (meth in c("regression", "matching", "stratification", "iptw", "aipw")) {
    out <- NULL
    expect_message(
      out <- suppressWarnings(subgroup_analysis(m, "outcome", "grp", method = meth)),
      "removed from the covariate set",
      info = meth
    )
    expect_true(all(!is.na(out$estimate)), info = meth)
    expect_equal(nrow(out), length(unique(d$grp)), info = meth)
  }
})

test_that("subgroup_analysis warns and returns an NA row when a subgroup fails to fit", {
  d <- simulate_test_cohort()
  d$grp <- ifelse(seq_len(nrow(d)) <= 2, "B", "A")
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- suppressWarnings(match_cohort(ps))
  expect_warning(
    withCallingHandlers(
      out <- subgroup_analysis(m, "outcome", "grp", method = "iptw"),
      warning = function(w) {
        if (!grepl("failed to fit", conditionMessage(w), fixed = TRUE)) {
          invokeRestart("muffleWarning")
        }
      }
    ),
    "Subgroup 'B' failed to fit"
  )
  expect_true(any(is.na(out$estimate)))
  expect_identical(nrow(out), 2L)
})
