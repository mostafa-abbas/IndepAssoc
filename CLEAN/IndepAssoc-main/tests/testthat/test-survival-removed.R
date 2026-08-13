test_that("km_logrank() has been removed from the namespace", {
  expect_false(exists("km_logrank", envir = asNamespace("IndepAssoc"), inherits = FALSE))
})

test_that("km_logrank() is not exported", {
  expect_false("km_logrank" %in% getNamespaceExports(asNamespace("IndepAssoc")))
})

test_that("no time-to-event code remains in R sources", {
  pkg_root <- testthat::test_path("../../")
  r_files <- list.files(file.path(pkg_root, "R"), pattern = "\\.R$", full.names = TRUE)
  code <- unlist(lapply(r_files, readLines), use.names = FALSE)
  hits <- grep("km_logrank|survdiff|survfit|Surv\\(|time_to_event|time_var", code, value = TRUE)
  expect_length(hits, 0)
})
