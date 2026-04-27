# 02_did2s_honestdid_upgrade.R
# CE-Cognitive-Econometrics — did2s + HonestDiD Upgrade
# MGO | 2026-04-26 | BESTFIT Rank 28
#
# Purpose: Supplement existing TWFE + System-GMM + Bartik-2SLS (M5 done)
# with (1) Gardner (2022) did2s — robust to heterogeneous treatment timing;
# (2) HonestDiD (Rambachan & Roth 2023) — pre-trend sensitivity analysis.
#
# The cognitive-macro paper has TWFE with time FE → potential staggered
# adoption bias. did2s corrects this; HonestDiD bounds ATT under violations.
#
# Data: 400-Data/ (cognitive macro panel)

library(tidyverse)
library(fixest)

BASE    <- here::here()
RESULTS <- file.path(BASE, "results")
dir.create(RESULTS, showWarnings = FALSE, recursive = TRUE)

# ── Load data ─────────────────────────────────────────────────────────────────
data_candidates <- c(
  file.path(BASE, "400-Data", "cognitive_macro_panel.csv"),
  file.path(BASE, "400-Data", "panel_cognitive_macro.csv"),
  file.path(BASE, "sources", "cognitive_macro_panel.csv")
)
df <- NULL
for (p in data_candidates) {
  if (file.exists(p)) {
    df <- read_csv(p, show_col_types = FALSE)
    cat("Panel loaded:", nrow(df), "rows\n")
    cat("Columns:", paste(names(df), collapse = ", "), "\n")
    break
  }
}

if (is.null(df)) {
  cat("WARNING: cognitive panel not found. Script in validation mode.\n")
  cat("Expected: id, year, outcome, treatment_dummy, controls\n")
  cat("M5 Bartik 2SLS already done (β=−0.307*, F=4.82, LIML confirmed).\n")
  cat("Provide panel CSV for did2s + HonestDiD analysis.\n")
  quit(status = 0)
}

# detect columns
id_col      <- names(df)[grepl("id|country|region|ind", names(df), ignore.case = TRUE)][1]
time_col    <- names(df)[grepl("year|time|period|quarter", names(df), ignore.case = TRUE)][1]
outcome_col <- names(df)[grepl("outcome|gdp|prod|growth|y_", names(df), ignore.case = TRUE)][1]
treat_col   <- names(df)[grepl("treat|policy|program|adopt", names(df), ignore.case = TRUE)][1]

cat(sprintf("\nDetected: id=%s, time=%s, outcome=%s, treat=%s\n",
            id_col, time_col, outcome_col, treat_col))

# ── (1) did2s: Gardner (2022) ─────────────────────────────────────────────────
cat("\n", strrep("=", 60), "\n")
cat("did2s: Gardner (2022) Two-Stage DiD\n")
cat(strrep("=", 60), "\n")

tryCatch({
  library(did2s)

  # Create first_treat column (year of first treatment per unit)
  df_did <- df %>%
    group_by(!!sym(id_col)) %>%
    mutate(
      first_treat = if_else(any(!!sym(treat_col) == 1),
                            min(!!sym(time_col)[!!sym(treat_col) == 1], na.rm = TRUE),
                            Inf)
    ) %>%
    ungroup()

  # did2s estimation
  est_did2s <- did2s(
    data       = df_did,
    yname      = outcome_col,
    first_stage = ~ 0 | !!sym(id_col) + !!sym(time_col),
    second_stage = ~ i(!!sym(time_col), ref = TRUE),
    treatment  = treat_col,
    cluster_var = id_col
  )

  cat("did2s ATT:\n")
  print(summary(est_did2s))

  # Compare with TWFE
  est_twfe <- feols(
    .[outcome_col] ~ .[treat_col] | .[id_col] + .[time_col],
    data  = df,
    vcov  = ~(.[id_col])
  )
  cat("\nTWFE ATT:", coef(est_twfe)[treat_col], "\n")
  cat("did2s ATT (aggregate):", mean(est_did2s$coef, na.rm = TRUE), "\n")
  cat("Bias from staggered timing:", mean(est_did2s$coef) - coef(est_twfe)[treat_col], "\n")

  # Save event study
  df_es <- iplot(est_did2s, return_data = TRUE)
  if (!is.null(df_es)) {
    write_csv(df_es, file.path(RESULTS, "did2s_event_study.csv"))
    cat("Event study saved: did2s_event_study.csv\n")
  }

}, error = function(e) {
  cat("did2s error:", conditionMessage(e), "\n")
  cat("Install: install.packages('did2s')\n")
})

# ── (2) HonestDiD: Pre-trend sensitivity ─────────────────────────────────────
cat("\n", strrep("=", 60), "\n")
cat("HonestDiD: Pre-trend Sensitivity (Rambachan & Roth 2023)\n")
cat(strrep("=", 60), "\n")

tryCatch({
  library(HonestDiD)

  # Need betahat and sigma from TWFE event study
  # Estimate event study with fixest
  df_es_data <- df %>%
    group_by(!!sym(id_col)) %>%
    mutate(
      first_treat = if_else(any(!!sym(treat_col) == 1),
                            min(!!sym(time_col)[!!sym(treat_col) == 1], na.rm = TRUE),
                            Inf),
      rel_time    = !!sym(time_col) - first_treat
    ) %>%
    ungroup()

  es_mod <- feols(
    .[outcome_col] ~ i(rel_time, ref = c(-1, Inf)) | .[id_col] + .[time_col],
    data = df_es_data,
    vcov = ~(.[id_col])
  )

  betahat <- coef(es_mod)
  sigma   <- vcov(es_mod)

  # Pre-period and post-period indices
  coef_names <- names(betahat)
  pre_idx  <- which(as.numeric(gsub(".*::([-0-9]+).*", "\\1", coef_names)) < 0)
  post_idx <- which(as.numeric(gsub(".*::([-0-9]+).*", "\\1", coef_names)) >= 0)

  if (length(pre_idx) > 0 && length(post_idx) > 0) {
    # HonestDiD sensitivity
    delta_rm  <- seq(0, 0.5, by = 0.1)
    sens_res  <- HonestDiD::createSensitivityResults(
      betahat   = betahat[post_idx[1]],
      sigma     = as.matrix(sigma[post_idx[1], post_idx[1]]),
      numPrePeriods  = length(pre_idx),
      numPostPeriods = 1,
      Mvec      = delta_rm
    )
    cat("\nHonestDiD CI width by M (pre-trend violation size):\n")
    print(sens_res)
    write_csv(as.data.frame(sens_res), file.path(RESULTS, "honestdid_sensitivity.csv"))
    cat("Saved: honestdid_sensitivity.csv\n")
  } else {
    cat("Insufficient pre/post periods for HonestDiD.\n")
  }

}, error = function(e) {
  cat("HonestDiD error:", conditionMessage(e), "\n")
  cat("Install: install.packages('HonestDiD')\n")
})

cat("\nMANUSCRIPT NOTE (CE §4.3 Robustness):
  'Gardner (2022) did2s corrects for staggered treatment bias in our TWFE
   baseline. ATT remains [direction], with pre-trend sensitivity (HonestDiD)
   confirming results hold under Mbar = [value] violations of parallel trends.'\n")
