#' Normalize a numeric vector (min-max)
#' @keywords internal
normalize <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (rng[2] == rng[1]) return(rep(0, length(x)))
  (x - rng[1]) / (rng[2] - rng[1])
}

#' Summarize a glm/lm/clogit model for the treatment effect
#' @keywords internal
model_summ <- function(model, treatment_feature, type = c("binary", "continuous")) {
  type <- match.arg(type)
  summ_coeff <- as.data.frame(summary(model)$coefficients)
  row_treat <- grep(treatment_feature, rownames(summ_coeff), value = TRUE)
  if (length(row_treat) == 0) row_treat <- rownames(summ_coeff)[2]
  summ_coeff <- summ_coeff[row_treat, , drop = FALSE]

  summ_confint <- as.data.frame(confint(model, method = "Wald"))
  summ_confint <- summ_confint[rownames(summ_coeff), , drop = FALSE]

  summ <- cbind(summ_coeff, summ_confint)

  if (type == "binary") {
    summ$OR <- exp(summ[, 1])
    summ$lower <- exp(summ[, ncol(summ) - 1])
    summ$upper <- exp(summ[, ncol(summ)])
  } else {
    summ$SC <- summ[, 1]
    summ$lower <- summ[, ncol(summ) - 1]
    summ$upper <- summ[, ncol(summ)]
  }

  summ
}

#' Fit All 4 Outcome Models
#'
#' Fits 4 regression models matching the published pipeline:
#' 1. Fully adjusted (on full unmatched data)
#' 2. Conditional (clogit/plm on matched data)
#' 3. Doubly robust (glm/lm on matched data with all covariates)
#' 4. Mixed effect (glmer/lmer on matched data)
#'
#' @param ps_model An `IndepPSModel` object.
#' @param matched_data Matched data frame from `match_cohort()`.
#' @param outcome Character; outcome variable name.
#' @param type `"binary"` or `"continuous"`.
#' @param covariates Character vector of covariate names.
#' @param normalize_continuous Logical; normalize continuous outcome (default TRUE).
#'
#' @return A list of class `"IndepOutcomeModels"` with `$models`, `$summary`, `$summary_w`.
#'
#' @export
fit_all_models <- function(ps_model, matched_data, outcome, type = c("binary", "continuous"),
                           covariates = NULL, normalize_continuous = TRUE) {
  type <- match.arg(type)
  exposure <- ps_model$exposure
  full_data <- ps_model$data
  all_covs <- ps_model$covariates
  pred_features <- c(exposure, all_covs)

  if (!outcome %in% names(full_data)) stop(paste("Outcome", outcome, "not found."))
  if (!"match_num" %in% names(matched_data)) {
    if ("strata" %in% names(matched_data)) {
      matched_data$match_num <- as.numeric(matched_data$strata)
    } else {
      stop("matched_data must contain 'match_num' or 'strata' column.")
    }
  }

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
    doubly_robust <- glm(model_all_form, data = matched_data, family = "binomial")

    cond_form <- as.formula(paste("label ~", exposure, "+ survival::strata(match_num)"))
    conditional <- survival::clogit(cond_form, data = matched_data)

    mixed_form <- as.formula(paste("label ~", exposure, "+ (1 | match_num)"))
    mixed_effect <- lme4::glmer(mixed_form, family = binomial, data = matched_data)

    models <- list(
      "Fully adjusted logistic" = fully_adjusted,
      "Conditional logit" = conditional,
      "Doubly robust logistic" = doubly_robust,
      "Mixed effect logistic" = mixed_effect
    )
  } else {
    model_all_form <- as.formula(paste("label ~", paste(pred_features, collapse = " + ")))
    fully_adjusted <- lm(model_all_form, data = full_data)
    doubly_robust <- lm(model_all_form, data = matched_data)

    cond_form <- as.formula(paste("label ~", exposure))
    panel_data <- plm::pdata.frame(matched_data, index = "match_num")
    conditional <- plm::plm(cond_form, model = "within", effect = "individual", data = panel_data)

    mixed_form <- as.formula(paste("label ~", exposure, "+ (1 | match_num)"))
    mixed_effect <- lme4::lmer(mixed_form, data = matched_data)
    mixed_effect <- lmerTest::as_lmerModLmerTest(mixed_effect)

    models <- list(
      "Fully adjusted linear regression" = fully_adjusted,
      "Conditional linear regression" = conditional,
      "Doubly robust linear regression" = doubly_robust,
      "Mixed effect linear regression" = mixed_effect
    )
  }

  model_summaries <- lapply(names(models), function(nn) {
    res <- model_summ(models[[nn]], treatment_feature = exposure, type = type)
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
