test_that("DESCRIPTION declares utils in Imports", {
  desc_path <- testthat::test_path("../../DESCRIPTION")
  if (!file.exists(desc_path)) {
    desc_path <- system.file("DESCRIPTION", package = "IndepAssoc")
  }
  desc <- read.dcf(desc_path)
  imports <- trimws(unlist(strsplit(desc[1, "Imports"], "[,\n]")))
  expect_true("utils" %in% imports)
})
