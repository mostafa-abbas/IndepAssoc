# Known follow-ups (filed at v0.1.0 release; not blocking, do not fix silently):
# 1. Flaky: on some full-suite runs, this file intermittently fails with an
#    lme4 "Downdated VtV is not positive definite" message. Proven unrelated to
#    the release-hardening branch (path untouched; isolates 10/10 pass). Treat
#    as a latent CI flake to diagnose in a follow-up session.
test_that("plot_comparison returns a ggplot", {
  d <- simulate_test_cohort()
  res <- suppressWarnings(run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                      type = "binary", methods = c("regression", "iptw", "aipw")))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- plot_comparison(res$comparison)
  expect_s3_class(p, "ggplot")
})

test_that("plot_comparison returns visibly and does not print internally", {
  comp <- data.frame(
    method = c("regression", "iptw", "aipw"),
    label = rep("outcome", 3),
    type = rep("binary", 3),
    estimate = c(1.5, 1.4, 1.6),
    conf_low = c(1.1, 1.0, 1.2),
    conf_high = c(2.0, 1.9, 2.1),
    p_value = c(0.01, 0.02, 0.03),
    n = rep(200, 3)
  )

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  printed <- FALSE
  testthat::local_mocked_bindings(
    print = function(x, ...) {
      printed <<- TRUE
      invisible(x)
    },
    .package = "base"
  )

  v <- withVisible(plot_comparison(comp, log_scale = TRUE))

  expect_true(v$visible)
  expect_false(printed)
  expect_s3_class(v$value, "ggplot")
})

test_that("plot_comparison returns a ggplot with the expected layers", {
  comp <- data.frame(
    method = c("regression", "iptw", "aipw"),
    label = rep("outcome", 3),
    type = rep("binary", 3),
    estimate = c(1.5, 1.4, 1.6),
    conf_low = c(1.1, 1.0, 1.2),
    conf_high = c(2.0, 1.9, 2.1),
    p_value = c(0.01, 0.02, 0.03),
    n = rep(200, 3)
  )

  p <- plot_comparison(comp, log_scale = TRUE)
  expect_s3_class(p, "ggplot")

  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true("GeomPoint" %in% geoms)
  expect_true("GeomErrorbar" %in% geoms)
  expect_true("GeomHline" %in% geoms)
})
