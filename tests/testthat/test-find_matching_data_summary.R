test_that("find_matching_data_summary returns the expected structure", {
  set.seed(123)
  d <- simulate_test_cohort()
  res <- suppressWarnings(find_matching_data_summary(
    d, "exposure",
    c("age", "diabetes", "hypertension")
  ))

  expect_type(res, "list")
  expect_true(is.data.frame(res$match_summ$all))
  expect_true(is.data.frame(res$match_summ$matched))
  expect_true(all(c("age", "diabetes", "hypertension") %in%
                    rownames(res$match_summ$all)))
  expect_true(all(c("age", "diabetes", "hypertension") %in%
                    rownames(res$match_summ$matched)))
  expect_true("Std. Mean Diff." %in% names(res$match_summ$all))
  expect_true("Std. Mean Diff." %in% names(res$match_summ$matched))
  expect_true(is.data.frame(res$Data_all))
  expect_true(is.data.frame(res$Data_matched))
  expect_true("match_num" %in% names(res$Data_matched))
  expect_true(nrow(res$Data_matched) > 0)
})

test_that("find_matching_data_summary runs on example_cohort with a seed", {
  data(example_cohort)
  set.seed(42)
  res <- suppressWarnings(find_matching_data_summary(
    example_cohort, "exposure",
    c("age", "diabetes", "hypertension", "bmi")
  ))
  expect_true("bmi" %in% rownames(res$match_summ$all))
})

test_that("find_matching_data_summary supports ratio > 1", {
  d <- simulate_test_cohort()
  set.seed(42)
  res1 <- suppressWarnings(find_matching_data_summary(
    d, "exposure", c("age", "diabetes", "hypertension"), ratio = 1))
  set.seed(42)
  res2 <- suppressWarnings(find_matching_data_summary(
    d, "exposure", c("age", "diabetes", "hypertension"), ratio = 2))
  expect_true(nrow(res2$Data_matched) > nrow(res1$Data_matched))
})

test_that("find_matching_data_summary emits complete pairs for ratio > 1", {
  d <- simulate_test_cohort()
  set.seed(42)
  res <- suppressWarnings(find_matching_data_summary(
    d, "exposure", c("age", "diabetes", "hypertension"), ratio = 2))

  pair_counts <- table(res$Data_matched$match_num)
  expect_true(all(pair_counts == 2))
  expect_equal(sum(pair_counts), nrow(res$Data_matched))
  expect_equal(length(unique(res$Data_all$match_num[!is.na(res$Data_all$match_num)])),
               length(unique(res$Data_matched$match_num)))
})
