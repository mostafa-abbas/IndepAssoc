# data-raw/make_rhc_forest_plot.R
# Re-run the RHC 30-day-mortality five-method validation from
# vignettes/rhc-validation.Rmd and save a forest plot for the README
# (man/figures/rhc-forest-dth30.png).
# The estimates plotted must match the vignette's dth30 results exactly,
# because both call run_pipeline() on the same rhc_sample analytic sample.
# Development-only: excluded from the build via .Rbuildignore (^data-raw$).
library(IndepAssoc)

data(rhc_sample)
rhc <- rhc_sample$data
covariates <- rhc_sample$covariates
exposure <- "swang1"

analytic_sample <- rhc[stats::complete.cases(rhc[, c(exposure, covariates, "dth30")]), ]

res <- run_pipeline(
  data       = analytic_sample,
  exposure   = exposure,
  covariates = covariates,
  outcome    = "dth30",
  type       = "binary",
  methods    = c("regression", "matching", "stratification", "iptw", "aipw"),
  seed       = 1
)

comparison <- res$comparison
stopifnot(nrow(comparison) == 5)

print(format_comparison(comparison))

p <- plot_comparison(comparison, log_scale = TRUE)
ggplot2::ggsave("man/figures/rhc-forest-dth30.png", plot = p, width = 8, height = 5, dpi = 150)
