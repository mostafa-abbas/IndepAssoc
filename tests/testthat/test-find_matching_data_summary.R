test_that("find_matching_data_summary returns the expected structure", {
  d <- simulate_test_cohort()
  res <- find_matching_data_summary(
    d, "exposure",
    c("age", "diabetes", "hypertension")
  )

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
  res <- find_matching_data_summary(
    example_cohort, "exposure",
    c("age", "diabetes", "hypertension", "bmi")
  )
  expect_true("bmi" %in% rownames(res$match_summ$all))
})
