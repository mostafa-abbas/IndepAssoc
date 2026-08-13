test_that("paired_wilcoxon_test uses the paired path", {
  set.seed(1)
  pair <- rep(1:20, each = 2)
  pair_effect <- rnorm(20, 0, 1)
  delta <- 0.35
  noise <- rnorm(40, 0, 0.05)
  value <- rep(pair_effect, each = 2) + rep(c(0, delta), 20) + noise
  md <- data.frame(exposure = rep(c(0, 1), 20), value = value, match_num = pair)

  res <- paired_wilcoxon_test(md, "value", "exposure")

  expect_type(res$p.value, "double")
  v0 <- value[md$exposure == 0]; v1 <- value[md$exposure == 1]
  expect_equal(res$p.value, wilcox.test(v0, v1, paired = TRUE)$p.value)
  unpaired_p <- wilcox.test(v0, v1)$p.value
  expect_lt(res$p.value, unpaired_p)
  expect_lt(res$p.value, 0.05)
  expect_gt(unpaired_p, 0.05)
})

test_that("mcnemar_test returns a numeric p.value", {
  set.seed(7)
  md <- data.frame(
    exposure = rep(c(0, 1), 50),
    outcome = rbinom(100, 1, 0.4),
    match_num = rep(1:50, each = 2)
  )
  res <- mcnemar_test(md, "outcome", "exposure")
  expect_type(res$p.value, "double")
  expect_true(!is.na(res$p.value))
})

test_that("mcnemar_test degrades gracefully on a constant response", {
  set.seed(7)
  md <- data.frame(
    exposure = rep(c(0, 1), 50),
    outcome = 0L,
    match_num = rep(1:50, each = 2)
  )
  expect_warning(res <- mcnemar_test(md, "outcome", "exposure"),
                 "McNemar test failed to fit")
  expect_true(is.na(res$statistic))
  expect_true(is.na(res$p.value))
})

test_that("paired_wilcoxon_test handles NA outcomes without crashing", {
  set.seed(1)
  pair <- rep(1:20, each = 2)
  pair_effect <- rnorm(20, 0, 1)
  delta <- 0.35
  noise <- rnorm(40, 0, 0.05)
  value <- rep(pair_effect, each = 2) + rep(c(0, delta), 20) + noise
  md <- data.frame(exposure = rep(c(0, 1), 20), value = value, match_num = pair)

  # pair 7: both members missing; pair 10: treated member missing
  md$value[md$match_num == 7] <- NA
  md$value[md$match_num == 10 & md$exposure == 1] <- NA

  expect_message(
    res <- paired_wilcoxon_test(md, "value", "exposure"),
    "incomplete"
  )
  expect_true(!is.na(res$p.value))
  expect_type(res$statistic, "double")

  keep <- !(md$match_num %in% c(7, 10))
  v0 <- md$value[keep & md$exposure == 0]
  v1 <- md$value[keep & md$exposure == 1]
  expect_equal(res$p.value, wilcox.test(v0, v1, paired = TRUE)$p.value)
})

test_that("paired_wilcoxon_test uses all matched rows under ratio > 1 matching", {
  # 4 treated strata; strata 1-2 have two controls, strata 3-4 one control
  md <- data.frame(
    match_num = c(1, 1, 1, 2, 2, 2, 3, 3, 4, 4),
    exposure  = c(1, 0, 0, 1, 0, 0, 1, 0, 1, 0),
    value     = c(10, 12, 16, 20, 23, 26, 30, 33, 40, 42)
  )
  # Per-stratum control means: stratum 1 = 14, 2 = 24.5, 3 = 33, 4 = 42
  expect_message(res <- paired_wilcoxon_test(md, "value", "exposure"), NA)
  v1 <- c(10, 20, 30, 40)
  v0 <- c(14, 24.5, 33, 42)
  expect_equal(res$p.value, wilcox.test(v1, v0, paired = TRUE)$p.value)
  # every matched row is reflected in the reported group sizes
  expect_true("0(n=6)" %in% names(res))
  expect_true("1(n=4)" %in% names(res))
})

test_that("mcnemar_test handles NA outcomes without returning a silent NA", {
  set.seed(7)
  md <- data.frame(
    exposure = rep(c(0, 1), 50),
    outcome = rbinom(100, 1, 0.4),
    match_num = rep(1:50, each = 2)
  )
  # both members of pair 2 have missing outcomes
  md$outcome[c(3, 4)] <- NA

  expect_message(res <- mcnemar_test(md, "outcome", "exposure"), "incomplete")
  expect_true(!is.na(res$p.value))
  expect_type(res$statistic, "double")
})

test_that("mcnemar_test completes without NA under ratio > 1 matching", {
  # 6 strata, each 1 treated + 2 controls (m:1)
  md <- data.frame(
    match_num = rep(1:6, each = 3),
    exposure = rep(c(1, 0, 0), 6),
    outcome = c(1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0)
  )
  expect_message(res <- mcnemar_test(md, "outcome", "exposure"), NA)
  expect_true(!is.na(res$p.value))

  # reference: Cochran-Mantel-Haenszel over per-stratum 2x2 tables
  arr <- array(0, dim = c(2, 2, 6))
  for (s in 1:6) {
    sub <- md[md$match_num == s, ]
    arr[, , s] <- table(factor(sub$outcome, levels = 0:1),
                        factor(sub$exposure, levels = 0:1))
  }
  mh <- stats::mantelhaen.test(arr)
  expect_equal(res$p.value, mh$p.value)
})

test_that("paired statistical tests complete on rhc_sample at ratio 1 and 2", {
  data(rhc_sample)
  ps <- build_ps_model(rhc_sample$data, "swang1", rhc_sample$covariates)
  for (r in c(1, 2)) {
    m <- suppressWarnings(match_cohort(ps, ratio = r, seed = 42))
    w <- suppressMessages(paired_wilcoxon_test(m$data, "los", "swang1"))
    expect_true(!is.na(w$p.value))
    mc <- suppressMessages(mcnemar_test(m$data, "dth30", "swang1"))
    expect_true(!is.na(mc$p.value))
  }
})
