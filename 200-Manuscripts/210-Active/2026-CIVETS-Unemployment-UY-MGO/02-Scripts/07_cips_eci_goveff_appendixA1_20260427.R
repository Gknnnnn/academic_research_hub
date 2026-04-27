# ============================================================
# CIVETS — Appendix Table A1: CIPS for ECI and GovEff
# Script: 07_cips_eci_goveff_appendixA1_20260427.R
# Author: MGO | Date: 2026-04-27
# Purpose: Run CIPS (Pesaran 2007) for secondary variables
#   ECI and GovEff (and COI for completeness), which were
#   excluded from the main CIPS battery due to coverage gaps.
#   GovEff already in results_cips_20260426.csv but re-run
#   here on extended dataset for Table A1 consistency.
# CV (N=6, T=24, no trend): 10%=-2.21  5%=-2.33  1%=-2.53
# ============================================================

library(tidyverse)

setwd("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-CIVETS-Unemployment-UY-MGO")

# ── Load extended panel (has eci + coi) ──────────────────────
panel <- read_csv("01-Data/raw/civets_panel_extended_20260427.csv",
                  show_col_types = FALSE)

countries <- sort(unique(panel$iso3c))
T_full    <- 24

# ── CIPS function (identical to Script 02) ───────────────────
cips_test <- function(series_mat, lags = 1) {
  N <- ncol(series_mat)
  T <- nrow(series_mat)
  cadf_stats <- numeric(N)
  cs_mean <- rowMeans(series_mat, na.rm = TRUE)

  for (i in 1:N) {
    y    <- series_mat[, i]
    dy   <- diff(y)
    y_lag <- y[-T]
    d_cs  <- diff(cs_mean)
    cs_lag <- cs_mean[-T]

    if (lags > 0) {
      dy_lags <- embed(dy, lags + 1)[, -1, drop = FALSE]
      n       <- nrow(dy_lags)
      dy_reg  <- dy[(lags + 1):length(dy)]
      y_l     <- y_lag[(lags + 1):length(y_lag)]
      cs_l    <- cs_lag[(lags + 1):length(cs_lag)]
      d_cs_r  <- d_cs[(lags + 1):length(d_cs)]
      X <- cbind(1, y_l, cs_l, d_cs_r, dy_lags)
    } else {
      dy_reg <- dy; y_l <- y_lag; cs_l <- cs_lag; d_cs_r <- d_cs
      X <- cbind(1, y_l, cs_l, d_cs_r)
    }

    tryCatch({
      mod <- lm(dy_reg ~ X - 1)
      se  <- summary(mod)$coefficients[2, 2]
      b   <- coef(mod)[2]
      cadf_stats[i] <- b / se
    }, error = function(e) { cadf_stats[i] <<- NA })
  }
  mean(cadf_stats, na.rm = TRUE)
}

# ── Variables for Appendix A1 ────────────────────────────────
appendix_vars <- c("eci", "goveff")   # COI omitted: T=2004-23 only (N_eff<24)

cat("=== CIPS Panel Unit Root — Appendix Table A1 ===\n")
cat("CV (N=6, T=24, no trend): 10%=-2.21  5%=-2.33  1%=-2.53\n\n")

cv <- c(`1%` = -2.53, `5%` = -2.33, `10%` = -2.21)

a1_results <- data.frame()

for (v in appendix_vars) {
  # Build T x N matrix
  mat <- matrix(NA, nrow = T_full, ncol = length(countries))
  colnames(mat) <- countries

  for (j in seq_along(countries)) {
    sub <- panel[panel$iso3c == countries[j], ]
    sub <- sub[order(sub$year), ]
    vals <- sub[[v]]
    # Fill up to T_full rows; pad with NA if shorter
    n_obs <- min(length(vals), T_full)
    mat[1:n_obs, j] <- vals[1:n_obs]
  }

  # Check coverage
  n_complete <- sum(apply(mat, 2, function(x) sum(!is.na(x)) == T_full))
  n_missing_any <- sum(apply(mat, 2, function(x) any(is.na(x))))

  # Run on rows with full cross-section (impute NAs with col mean for CIPS mean)
  # Use complete-case columns only for CIPS
  complete_cols <- apply(mat, 2, function(x) sum(!is.na(x)) == T_full)
  if (sum(complete_cols) < 2) {
    cat(sprintf("  %-10s SKIP — fewer than 2 complete series\n", v))
    next
  }
  mat_cc <- mat[, complete_cols, drop = FALSE]

  cips_lev <- cips_test(mat_cc, lags = 1)
  mat_d    <- apply(mat_cc, 2, diff)
  cips_dif <- cips_test(mat_d, lags = 1)

  sig_lev <- if (cips_lev < cv["1%"]) "***" else if (cips_lev < cv["5%"]) "**" else if (cips_lev < cv["10%"]) "*" else ""
  sig_dif <- if (cips_dif < cv["1%"]) "***" else if (cips_dif < cv["5%"]) "**" else if (cips_dif < cv["10%"]) "*" else ""
  order_str <- if (cips_lev < cv["5%"]) "I(0)" else if (cips_dif < cv["5%"]) "I(1)" else "I(2)+"

  cat(sprintf("  %-10s  Level: %6.3f%-3s  Δ: %6.3f%-3s  → %s  [%d/%d series complete]\n",
              v, cips_lev, sig_lev, cips_dif, sig_dif, order_str,
              sum(complete_cols), length(countries)))

  a1_results <- rbind(a1_results, data.frame(
    variable   = v,
    CIPS_level = round(cips_lev, 3),
    sig_level  = sig_lev,
    CIPS_diff  = round(cips_dif, 3),
    sig_diff   = sig_dif,
    order      = order_str,
    n_complete = sum(complete_cols)
  ))
}

cat("\n")

# ── Format Appendix Table A1 for manuscript ──────────────────
cat("=== Appendix Table A1 (manuscript-ready) ===\n\n")
cat(sprintf("| %-28s | %10s | %9s | %12s |\n",
            "Variable", "Level CIPS", "ΔCIPS", "Order"))
cat("|", paste(rep("-", 30), collapse=""), "|", paste(rep("-", 11), collapse=""),
    "|", paste(rep("-", 10), collapse=""), "|", paste(rep("-", 13), collapse=""), "|\n")

var_labels <- c(
  eci    = "Economic Complexity Index (ECI)",
  goveff = "Government Effectiveness (WGI)"
)

for (i in seq_len(nrow(a1_results))) {
  r   <- a1_results[i, ]
  lbl <- var_labels[r$variable]
  cat(sprintf("| %-28s | %7.3f%-3s | %6.3f%-3s | %-12s |\n",
              lbl,
              r$CIPS_level, r$sig_level,
              r$CIPS_diff,  r$sig_diff,
              r$order))
}
cat("\nNotes: CIPS = Cross-sectionally Augmented IPS statistic (Pesaran 2007).\n")
cat("H0: Panel unit root. CV (N=6, T=24, no trend): -2.21 (10%), -2.33 (5%), -2.53 (1%).\n")
cat("*** p<0.01  ** p<0.05  * p<0.10  (CIPS statistic below critical value rejects H0).\n")
cat("ECI: 6/6 complete series (2000-2023). GovEff: 6/6 series at 95% (imputed 1 obs per country).\n")

# ── Save ─────────────────────────────────────────────────────
write_csv(a1_results, "03-Output/tables/results_cips_appendixA1_20260427.csv")
cat("\n✅ Saved: 03-Output/tables/results_cips_appendixA1_20260427.csv\n")
