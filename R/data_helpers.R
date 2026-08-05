# Coercing these categorical text columns collapses them to all-NA (or
# destroys their category/factor structure), so they must stay character.
.rhc_denylist <- c("cat1", "cat2", "ca", "swang1", "death", "dth30", "sex",
                   "race", "income", "ninsclas", "dnr1", "resp", "card",
                   "neuro", "gastr", "renal", "meta", "hema", "seps", "trauma",
                   "ortho", "ptid")

# Excluded from the covariate vector: the patient id, the exposure, both
# outcomes, the admission/discharge/event dates, adld3p and urin1 (excessive
# missingness collapses complete-case n from 5735 to ~634), t3d30 (collinear
# with the dth30 outcome), surv2md1 (the SUPPORT model's predicted 2-month
# survival probability -- a model-derived composite of the other covariates,
# not a raw confounder; excluded to avoid double adjustment, matching the
# reference manual analysis), and the derived los.
.rhc_excluded <- c("ptid", "swang1", "death", "dth30", "sadmdte", "dschdte",
                   "dthdte", "lstctdte", "adld3p", "urin1", "t3d30",
                   "surv2md1", "los")

#' Prepare the RHC dataset for analysis
#'
#' Reads a raw RHC (Right Heart Catheterization) CSV and returns a cleaned
#' data frame plus the 50-column covariate vector. The raw file carries a
#' `write.csv` row-names column named `""`, stores the `cat2` category "None"
#' as the literal text `"NA"`, stores every other missing value as the literal
#' text `"NA"`, and codes the `swang1` exposure and the `death`/`dth30`
#' outcomes as text. These quirks are resolved here so downstream analysis
#' receives a typed, numeric-encoded data frame.
#'
#' @param path Character; path to the RHC CSV file.
#'
#' @return A list with two elements: `data`, the cleaned data frame, and
#'   `covariates`, a character vector of the 50 covariate column names.
#'
#' @importFrom utils read.csv
#'
#' @examples
#' tmp <- tempfile(fileext = ".csv")
#' write.csv(data.frame(ptid = "p1", cat2 = "None", swang1 = "RHC",
#'                      dth30 = "Yes", death = "Yes",
#'                      sadmdte = "11142", dschdte = "11151"),
#'           tmp)
#' prepare_rhc_data(tmp)
#'
#' @export
prepare_rhc_data <- function(path) {
  raw <- read.csv(path, colClasses = "character", na.strings = NULL,
                  check.names = FALSE)

  if (names(raw)[1] == "") raw <- raw[, -1]

  raw[["cat2"]][raw[["cat2"]] == "NA"] <- "None"

  for (nm in names(raw)) {
    raw[[nm]][raw[[nm]] == "NA"] <- NA
  }

  for (nm in names(raw)) {
    if (nm %in% .rhc_denylist) next
    numeric_vec <- suppressWarnings(as.numeric(raw[[nm]]))
    if (identical(is.na(numeric_vec), is.na(raw[[nm]]))) {
      raw[[nm]] <- numeric_vec
    }
  }

  raw[["swang1"]] <- as.numeric(raw[["swang1"]] == "RHC")
  raw[["dth30"]] <- as.numeric(raw[["dth30"]] == "Yes")
  raw[["death"]] <- as.numeric(raw[["death"]] == "Yes")

  raw[["los"]] <- as.numeric(raw[["dschdte"]]) - as.numeric(raw[["sadmdte"]])

  list(data = raw, covariates = setdiff(names(raw), .rhc_excluded))
}
