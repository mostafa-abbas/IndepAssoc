# data-raw/prepare_rhc.R
# Download the raw RHC CSV and build data/rhc_sample.rda (cleaned cohort).
# Development-only: excluded from the build via .Rbuildignore (^data-raw$).
library(IndepAssoc)

rhc_url <- "https://hbiostat.org/data/repo/rhc.csv"
raw_csv <- tempfile(fileext = ".csv")
download.file(rhc_url, raw_csv, mode = "wb")

rhc_sample <- prepare_rhc_data(raw_csv)
stopifnot(
  nrow(rhc_sample$data) == 5735,
  ncol(rhc_sample$data) == 63,
  length(rhc_sample$covariates) == 50
)

usethis::use_data(rhc_sample, overwrite = TRUE, compress = "xz")
