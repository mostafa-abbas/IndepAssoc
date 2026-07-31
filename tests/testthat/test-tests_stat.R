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
