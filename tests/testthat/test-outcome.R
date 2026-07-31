test_that("fit_all_models has no mislabeled doubly robust model", {
  d <- simulate_test_cohort()
  ps <- build_ps_model(d, "exposure", c("age", "diabetes", "hypertension"))
  m <- match_cohort(ps)
  bin <- fit_all_models(ps, m$data, "outcome", type = "binary")
  cont <- fit_all_models(ps, m$data, "outcome", type = "continuous")
  expect_false(any(grepl("Doubly robust", names(bin$models))))
  expect_false(any(grepl("Doubly robust", names(cont$models))))
  expect_equal(length(bin$models), 3)
  expect_equal(length(cont$models), 3)
})

test_that("model_summ anchors the treatment feature to the left", {
  set.seed(3)
  d <- data.frame(
    outcome = rbinom(200, 1, 0.4),
    treatment = rbinom(200, 1, 0.5),
    prev_treatment = rnorm(200),
    age = rnorm(200)
  )
  fit <- glm(outcome ~ treatment + prev_treatment + age, data = d, family = "binomial")
  summ <- model_summ(fit, "treatment", type = "binary")
  expect_equal(rownames(summ), "treatment")
})

test_that("model_summ captures all levels of a factor exposure", {
  set.seed(4)
  d <- data.frame(
    outcome = rbinom(300, 1, 0.4),
    treatment = factor(sample(c("none", "low", "high"), 300, replace = TRUE),
                       levels = c("none", "low", "high")),
    age = rnorm(300)
  )
  fit <- glm(outcome ~ treatment + age, data = d, family = "binomial")
  summ <- model_summ(fit, "treatment", type = "binary")
  expect_setequal(rownames(summ), c("treatmentlow", "treatmenthigh"))
  expect_equal(nrow(summ), 2)
})
