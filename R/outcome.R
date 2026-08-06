#' Normalize a numeric vector (min-max)
#' @examples
#' IndepAssoc:::normalize(c(0, 5, 10))
#' @keywords internal
normalize <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (rng[2] == rng[1]) return(rep(0, length(x)))
  (x - rng[1]) / (rng[2] - rng[1])
}

#' Summarize a glm/lm/clogit model for the treatment effect
#' @examples
#' fit <- glm(outcome_binary ~ exposure + age,
#'            data = example_cohort, family = "binomial")
#' IndepAssoc:::model_summ(fit, "exposure", type = "binary")
#' @details The exposure's coefficient rows are selected by exact name match,
#'   or — for a factor exposure — by the factor levels recovered from the
#'   model frame (`<feature><level>`), never by substring matching, so a
#'   covariate whose name shares the exposure name as a prefix cannot steal
#'   the row. A multi-level factor exposure returns one row per
#'   non-reference level. A treatment with no coefficient row in the model
#'   errors rather than silently selecting a different term.
#' @keywords internal
model_summ <- function(model, treatment_feature, type = c("binary", "continuous")) {
  type <- match.arg(type)
  summ_coeff <- as.data.frame(summary(model)$coefficients)
  row_treat <- .match_treatment_rows(model, treatment_feature)
  summ_coeff <- summ_coeff[row_treat, , drop = FALSE]

  summ_confint <- .wald_confint(model, row_treat)

  summ <- cbind(summ_coeff, summ_confint)

  if (type == "binary") {
    summ$OR <- exp(summ[, 1])
    summ$lower <- exp(summ[, "2.5 %"])
    summ$upper <- exp(summ[, "97.5 %"])
  } else {
    summ$SC <- summ[, 1]
    summ$lower <- summ[, "2.5 %"]
    summ$upper <- summ[, "97.5 %"]
  }

  summ
}

# Match the coefficient rows belonging to the treatment term.
#
# Exact name match first; a factor exposure expands to one row per
# non-reference level (`<feature><level>`) and is resolved against the
# factor levels recovered from the model frame, never by substring-matching
# coefficient names. Errors if the treatment has no coefficient row,
# instead of silently picking a different term.
.match_treatment_rows <- function(model, treatment_feature) {
  rownm <- rownames(summary(model)$coefficients)
  exact <- rownm == treatment_feature
  if (any(exact)) return(rownm[exact])

  mf <- tryCatch(model.frame(model), error = function(e) NULL)
  if (!is.null(mf) && treatment_feature %in% names(mf) &&
      is.factor(mf[[treatment_feature]])) {
    levels <- levels(mf[[treatment_feature]])
    expanded <- paste0(treatment_feature, levels[-1])
    rows <- rownm[rownm %in% expanded]
    if (length(rows) > 0) return(rows)
  }

  stop("No coefficient row found for treatment feature '", treatment_feature, "'.")
}

#' Explicit Wald confidence interval for a fitted model's coefficients
#'
#' `confint(..., method = "Wald")` is silently ignored by most model classes
#' (`glm`/`lmer` use profile likelihood, `lm` uses t-quantiles, `clogit`/`plm`
#' use profile likelihood), so it does not guarantee a Wald interval. Compute
#' the Wald interval explicitly from `coef +/- qnorm(0.975) * SE`.
#' @examples
#' fit <- glm(outcome_binary ~ exposure + age,
#'            data = example_cohort, family = "binomial")
#' IndepAssoc:::.wald_confint(fit, "exposure")
#' @keywords internal
.wald_confint <- function(model, rows) {
  summ_coeff <- summary(model)$coefficients
  se_col <- grep("Std. Error", colnames(summ_coeff), value = TRUE)
  if (length(se_col) == 0) se_col <- grep("^se", colnames(summ_coeff), value = TRUE)
  est_col <- grep("Estimate", colnames(summ_coeff), value = TRUE)
  if (length(est_col) == 0) est_col <- grep("^coef", colnames(summ_coeff), value = TRUE)
  est <- summ_coeff[rows, est_col[1]]
  se <- as.numeric(summ_coeff[rows, se_col[1]])
  data.frame(
    "2.5 %" = est - stats::qnorm(0.975) * se,
    "97.5 %" = est + stats::qnorm(0.975) * se,
    row.names = rows,
    check.names = FALSE
  )
}

# Conditional logistic regression stratified by matched pair. Shared by
# fit_all_models() ("Conditional logit") and fit_outcome()'s "matching"
# method so the two code paths cannot drift apart. Requires `data` to carry a
# numeric `match_num` column and a numeric 0/1 `outcome`.
.fit_conditional_logit <- function(data, exposure, outcome) {
  form <- stats::as.formula(paste(outcome, "~", exposure, "+ survival::strata(match_num)"))
  survival::clogit(form, data = data)
}

#' Fit All 3 Outcome Models
#'
#' Fits 3 regression models matching the published pipeline:
#' 1. Fully adjusted (on full unmatched data)
#' 2. Conditional (clogit/plm on matched data)
#' 3. Mixed effect (glmer/lmer on matched data)
#'
#' @param ps_model An `IndepPSModel` object.
#' @param matched_data Matched data frame from `match_cohort()`.
#' @param outcome Character; outcome variable name.
#' @param type `"binary"` or `"continuous"`.
#'
#' @return A list of class `"IndepOutcomeModels"` with `$models`, `$summary`, `$summary_w`.
#'
#' @examples
#' data(example_cohort)
#' ps <- build_ps_model(example_cohort, "exposure",
#'                      c("age", "diabetes", "hypertension", "bmi"))
#' matched <- match_cohort(ps)
#' models <- fit_all_models(ps, matched$data, "outcome_binary", type = "binary")
#' models$summary_w
#'
#' @export
fit_all_models <- function(ps_model, matched_data, outcome, type = c("binary", "continuous")) {
  type <- match.arg(type)
  exposure <- ps_model$exposure
  full_data <- ps_model$data
  all_covs <- ps_model$covariates
  pred_features <- c(exposure, all_covs)

  if (!outcome %in% names(full_data)) stop(paste("Outcome", outcome, "not found."))
  matched_data <- .ensure_match_num(matched_data)

  if (type == "binary") {
    full_data$label <- full_data[[outcome]]
    matched_data$label <- matched_data[[outcome]]
  } else {
    full_data$label <- normalize(full_data[[outcome]])
    matched_data$label <- normalize(matched_data[[outcome]])
  }

  if (type == "binary") {
    model_all_form <- as.formula(paste("label ~", paste(pred_features, collapse = " + ")))
    fully_adjusted <- glm(model_all_form, data = full_data, family = "binomial")

    conditional <- .fit_conditional_logit(matched_data, exposure, "label")

    mixed_form <- as.formula(paste("label ~", exposure, "+ (1 | match_num)"))
    # lme4::checkResponse() throws "Response is constant" when the matched
    # cohort's binary outcome has fewer than 2 unique values (a degenerate
    # matched cohort whose outcome is all 0, all 1, or empty). glm() and
    # clogit() tolerate this, so only the mixed-effects model can fail; it is
    # deliberately skipped (NA row) rather than halting the whole pipeline.
    mixed_effect <- tryCatch(
      lme4::glmer(mixed_form, family = stats::binomial, data = matched_data),
      error = function(e) {
        warning("Mixed effect logistic failed to fit: ",
                conditionMessage(e), call. = FALSE)
        NULL
      }
    )

    models <- list(
      "Fully adjusted logistic" = fully_adjusted,
      "Conditional logit" = conditional,
      "Mixed effect logistic" = mixed_effect
    )
  } else {
    model_all_form <- as.formula(paste("label ~", paste(pred_features, collapse = " + ")))
    fully_adjusted <- lm(model_all_form, data = full_data)

    cond_form <- as.formula(paste("label ~", exposure))
    panel_data <- plm::pdata.frame(matched_data, index = "match_num")
    conditional <- plm::plm(cond_form, model = "within", effect = "individual", data = panel_data)

    mixed_form <- as.formula(paste("label ~", exposure, "+ (1 | match_num)"))
    mixed_effect <- tryCatch(
      {
        fit <- lme4::lmer(mixed_form, data = matched_data)
        lmerTest::as_lmerModLmerTest(fit)
      },
      error = function(e) {
        warning("Mixed effect linear regression failed to fit: ",
                conditionMessage(e), call. = FALSE)
        NULL
      }
    )

    models <- list(
      "Fully adjusted linear regression" = fully_adjusted,
      "Conditional linear regression" = conditional,
      "Mixed effect linear regression" = mixed_effect
    )
  }

  model_summaries <- lapply(names(models), function(nn) {
    # summary(model) can still throw on a constant response even when the fit
    # succeeded (e.g. summary.plm() raises "Lapack routine dgesv: system is
    # exactly singular" when every response value is identical); treat the
    # summary failure like a missing model so the NA row below is produced and
    # the pipeline continues.
    res <- if (is.null(models[[nn]])) {
      NULL
    } else {
      tryCatch(
        model_summ(models[[nn]], treatment_feature = exposure, type = type),
        error = function(e) {
          warning("Summary for model '", nn, "' failed to fit: ",
                  conditionMessage(e), ". Returning NA for this model.", call. = FALSE)
          NULL
        }
      )
    }
    if (is.null(res)) {
      if (type == "binary") {
        return(data.frame(
          label = outcome,
          Model = nn,
          OR = NA_real_,
          CI_95 = NA_character_,
          p = NA_real_,
          stringsAsFactors = FALSE
        ))
      }
      return(data.frame(
        label = outcome,
        Model = nn,
        SC = NA_real_,
        CI_95 = NA_character_,
        SC_CI_95 = NA_character_,
        p = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    res$label <- outcome
    res$Model <- nn

    if (type == "binary") {
      res$OR <- round(res$OR, 2)
      res$CI_95 <- paste0(round(res$lower, 2), "-", round(res$upper, 2))
      res$p <- res$`Pr(>|z|)`
      if (is.null(res$p)) res$p <- res$`Pr(>|t|)`
    } else {
      res$SC <- round(res$SC, 4)
      res$CI_95 <- paste0(round(res$lower, 4), "-", round(res$upper, 4))
      res$SC_CI_95 <- paste0(round(res$SC, 3), "(", res$CI_95, ")")
      res$p <- res$`Pr(>|t|)`
      if (is.null(res$p)) res$p <- res$`Pr(>|z|)`
    }
    res
  })

  if (type == "binary") {
    summary_w <- data.frame(
      label = outcome,
      Model = names(models),
      OR = sapply(model_summaries, function(x) x$OR[1]),
      CI_95 = sapply(model_summaries, function(x) x$CI_95[1]),
      p = sapply(model_summaries, function(x) x$p[1]),
      stringsAsFactors = FALSE
    )
  } else {
    summary_w <- data.frame(
      label = outcome,
      Model = names(models),
      SC = sapply(model_summaries, function(x) x$SC[1]),
      CI_95 = sapply(model_summaries, function(x) x$CI_95[1]),
      SC_CI_95 = sapply(model_summaries, function(x) x$SC_CI_95[1]),
      p = sapply(model_summaries, function(x) x$p[1]),
      stringsAsFactors = FALSE
    )
  }

  structure(
    list(models = models, summaries = model_summaries, summary_w = summary_w, type = type),
    class = "IndepOutcomeModels"
  )
}
