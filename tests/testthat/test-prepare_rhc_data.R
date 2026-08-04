synthetic_rhc <- function() {
  data.frame(
    ptid = c("p1", "p2", "p3", "p4"),
    cat1 = c("COPD", "ARF", "COPD", "ARF"),
    cat2 = c("NA", "MOSF w/Sepsis", "NA", "Other"),
    ca = c("No", "Yes", "No", "No"),
    sex = c("Male", "Female", "Male", "Female"),
    age = c("70.25", "78.18", "46.09", "75.33"),
    meanbp1 = c("41", "NA", "63", "57"),
    t3d30 = c("30", "30", "30", "30"),
    swang1 = c("No RHC", "RHC", "RHC", "No RHC"),
    dth30 = c("No", "No", "Yes", "No"),
    death = c("No", "Yes", "No", "Yes"),
    sadmdte = c("11142", "11799", "12083", "11146"),
    dschdte = c("11151", "NA", "12143", "11183"),
    dthdte = c("NA", "11844", "NA", "11183"),
    lstctdte = c("11382", "11844", "12400", "11182"),
    adld3p = c("0", "NA", "NA", "1"),
    urin1 = c("NA", "1437", "599", "NA"),
    stringsAsFactors = FALSE
  )
}

.local_rhc_path <- function() {
  "/home/mostafa/my-coding-project/rhc_data/rhc.csv"
}

.rhc_excluded <- function() {
  c("ptid", "swang1", "death", "dth30", "sadmdte", "dschdte", "dthdte",
    "lstctdte", "adld3p", "urin1", "t3d30", "surv2md1", "los")
}

test_that("prepare_rhc_data drops the write.csv row-names column", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_false("" %in% names(res$data))
  expect_equal(names(res$data)[1], "ptid")
  expect_equal(names(res), c("data", "covariates"))
  expect_true(is.data.frame(res$data))
  expect_true(is.character(res$covariates))
})

test_that("prepare_rhc_data maps cat2 literal 'NA' to the None category", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_equal(res$data$cat2, c("None", "MOSF w/Sepsis", "None", "Other"))
  expect_true(is.character(res$data$cat2))
  expect_false(any(is.na(res$data$cat2)))
})

test_that("prepare_rhc_data turns literal 'NA' into real NA in other columns", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_true(is.numeric(res$data$meanbp1))
  expect_true(is.na(res$data$meanbp1[2]))
  expect_equal(res$data$meanbp1[c(1, 3, 4)], c(41, 63, 57))
})

test_that("prepare_rhc_data re-types fully numeric columns to numeric", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_true(is.numeric(res$data$age))
  expect_equal(res$data$age, c(70.25, 78.18, 46.09, 75.33))
  expect_true(is.numeric(res$data$t3d30))
  expect_true(is.numeric(res$data$adld3p))
})

test_that("prepare_rhc_data leaves categorical text columns as character", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_true(is.character(res$data$sex))
  expect_equal(res$data$sex, c("Male", "Female", "Male", "Female"))
  expect_true(is.character(res$data$cat1))
  expect_true(is.character(res$data$ptid))
})

test_that("prepare_rhc_data recodes swang1 to numeric 0/1 with RHC = 1", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_true(is.numeric(res$data$swang1))
  expect_equal(res$data$swang1, c(0, 1, 1, 0))
})

test_that("prepare_rhc_data recodes dth30 and death to numeric 0/1", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_true(is.numeric(res$data$dth30))
  expect_equal(res$data$dth30, c(0, 0, 1, 0))
  expect_true(is.numeric(res$data$death))
  expect_equal(res$data$death, c(0, 1, 0, 1))
})

test_that("prepare_rhc_data derives los as discharge minus admit dates", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  expect_true(is.numeric(res$data$los))
  expect_equal(res$data$los, c(9, NA, 60, 37))
  expect_true(is.na(res$data$los[2]))
})

test_that("prepare_rhc_data builds the covariate vector from the exclusion list", {
  path <- tempfile(fileext = ".csv")
  write.csv(synthetic_rhc(), path)
  res <- prepare_rhc_data(path)
  excluded <- .rhc_excluded()
  expect_false(any(excluded %in% res$covariates))
  expect_true(all(c("age", "sex", "meanbp1") %in% res$covariates))
  expect_setequal(res$covariates, setdiff(names(res$data), excluded))
})

test_that("prepare_rhc_data reproduces the real RHC preprocessing findings", {
  local_rhc <- .local_rhc_path()
  skip_if_not(file.exists(local_rhc), "RHC data file not available locally")
  rhc <- prepare_rhc_data(local_rhc)
  expect_true(is.data.frame(rhc$data))
  expect_equal(nrow(rhc$data), 5735)
  expect_equal(ncol(rhc$data), 63)
  expect_false("" %in% names(rhc$data))
  expect_equal(length(rhc$covariates), 50)
  expect_true(is.numeric(rhc$data$swang1))
  expect_equal(sum(rhc$data$swang1), 2184)
  expect_true(is.numeric(rhc$data$dth30))
  expect_true(is.numeric(rhc$data$death))
  expect_true(is.numeric(rhc$data$los))
  expect_false(any(is.na(rhc$data$cat2)))
  expect_true("cat1" %in% rhc$covariates)
  expect_true("cat2" %in% rhc$covariates)
  expect_true("ca" %in% rhc$covariates)
  expect_false("surv2md1" %in% rhc$covariates)
  complete <- rhc$data[stats::complete.cases(rhc$data[, rhc$covariates]), ]
  expect_equal(nrow(complete), 5735)
})
