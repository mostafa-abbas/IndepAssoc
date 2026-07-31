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
