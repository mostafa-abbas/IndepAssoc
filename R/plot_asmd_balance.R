# Normalize a matching result object into unadjusted/matched ASMD tables.
#
# Accepts find_matching_data_summary() output (match_summ$all/$matched),
# run_pipeline() output (balance_pre/balance_post), or a check_balance()
# IndepBalance object (pre/post). Returns a list with 'unadjusted' and
# 'matched' data frames, each with 'Variable' (from row names) and 'ASMD'
# (numeric, absolute).
.asmd_tables <- function(matching_res) {
  if (!is.list(matching_res)) {
    stop("Invalid matching result object provided.")
  }

  all_df <- NULL
  matched_df <- NULL

  if (is.list(matching_res$match_summ)) {
    all_df <- matching_res$match_summ$all
    matched_df <- matching_res$match_summ$matched
  } else if (!is.null(matching_res$balance_pre) &&
             !is.null(matching_res$balance_post)) {
    all_df <- matching_res$balance_pre
    matched_df <- matching_res$balance_post
  } else if (!is.null(matching_res$pre) && !is.null(matching_res$post)) {
    all_df <- matching_res$pre$Balance
    matched_df <- matching_res$post$Balance
  }

  if (is.null(all_df) || is.null(matched_df)) {
    stop("Invalid matching result object provided.")
  }

  list(
    unadjusted = .asmd_table(all_df, stage = "unadjusted"),
    matched = .asmd_table(matched_df, stage = "matched")
  )
}

.asmd_table <- function(df, stage) {
  df_df <- as.data.frame(df)
  col <- .asmd_column(df_df, stage)
  data.frame(
    Variable = rownames(df_df),
    ASMD = abs(as.numeric(df_df[[col]])),
    stringsAsFactors = FALSE
  )
}

.asmd_column <- function(df, stage) {
  if ("ASMD" %in% names(df)) return("ASMD")
  if ("Std. Mean Diff." %in% names(df)) return("Std. Mean Diff.")
  if (stage == "unadjusted" && "Diff.Un" %in% names(df)) return("Diff.Un")
  if (stage == "matched" && "Diff.Adj" %in% names(df)) return("Diff.Adj")
  num_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  if (length(num_cols) > 0) return(num_cols[1])
  stop("Invalid matching result object provided.")
}
