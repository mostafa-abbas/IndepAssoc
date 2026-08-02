# Known follow-ups (filed at v0.1.0 release; not blocking, do not fix silently):
# 1. Flaky: on some full-suite runs, this file intermittently fails with an
#    lme4 "Downdated VtV is not positive definite" message. Proven unrelated to
#    the release-hardening branch (path untouched; isolates 10/10 pass). Treat
#    as a latent CI flake to diagnose in a follow-up session.
test_that("plot_comparison returns a ggplot", {
  d <- simulate_test_cohort()
  res <- run_pipeline(d, "exposure", c("age", "diabetes", "hypertension"), "outcome",
                      type = "binary", methods = c("regression", "iptw", "aipw"))
  p <- plot_comparison(res$comparison)
  expect_s3_class(p, "ggplot")
})
