# ============================================================
# 03_cointegration.R
# LCF Turkey Bootstrap ARDL — Structural Break Cointegration
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Tests:
#   1. Engle-Granger (1987) — baseline residual-based
#   2. Gregory-Hansen (1996) — structural break cointegration
#      Models: C (level shift), C/T (level shift + trend), C/S (regime shift)
#   3. Hatemi-J (2008) — two structural breaks [optional upgrade]
# ============================================================

library(tidyverse)
library(tsDyn)       # GHtest (Gregory-Hansen)
library(urca)        # cointegration
library(tseries)     # adf.test for residual-based

# ============================================================
# LOAD DATA
# ============================================================
panel_file <- list.files("data", pattern = "turkey_lcf_panel_", full.names = TRUE) |>
  sort() |> tail(1)

panel <- read_csv(panel_file, show_col_types = FALSE)
cat("Loaded:", panel_file, "| Rows:", nrow(panel), "\n")

# Working sample: drop NAs in key variables
# Main model: lnLCF ~ lnGDP + lnGDP2 + lnREN + lnTrade
model_vars <- c("lnLCF", "lnGDP", "lnGDP2", "lnREN", "lnTrade")

df <- panel |>
  select(year, all_of(model_vars)) |>
  drop_na()

cat("Cointegration sample:", min(df$year), "–", max(df$year),
    "| T =", nrow(df), "\n")

y <- df$lnLCF
X <- as.matrix(df |> select(lnGDP, lnGDP2, lnREN, lnTrade))

# ============================================================
# 1. BASELINE: OLS + ADF ON RESIDUALS (Engle-Granger)
# ============================================================
cat("\n=== ENGLE-GRANGER (baseline) ===\n")

eg_model <- lm(lnLCF ~ lnGDP + lnGDP2 + lnREN + lnTrade, data = df)
eg_resid  <- residuals(eg_model)
eg_adf    <- adf.test(eg_resid)

cat("EG ADF on residuals:", round(eg_adf$statistic, 4),
    "| p-value:", round(eg_adf$p.value, 4), "\n")
cat("Decision:", ifelse(eg_adf$p.value < 0.05,
    "REJECT unit root in residuals → cointegration supported",
    "Cannot reject → no cointegration"), "\n")

# ============================================================
# 2. GREGORY-HANSEN (1996) — Structural Break Cointegration
# ============================================================
cat("\n=== GREGORY-HANSEN (1996) ===\n")
cat("Testing three models: C (level shift), C/T (level+trend), C/S (regime shift)\n\n")

# tsDyn::GHtest — Gregory-Hansen cointegration with structural break
# Arguments: x (regressand), z (regressors matrix), model c("C","CT","CS")

tryCatch({
  # Model C: level shift
  gh_c  <- GHtest(y = y, x = X, model = "C",  lags = 1)
  # Model C/T: level shift with trend
  gh_ct <- GHtest(y = y, x = X, model = "CT", lags = 1)
  # Model C/S: regime shift (all coefficients shift)
  gh_cs <- GHtest(y = y, x = X, model = "CS", lags = 1)

  cat("Model C  (level shift):  ADF* =", round(gh_c$ADF,  4),
      "| Break year:", df$year[gh_c$breakpoint], "\n")
  cat("Model C/T (trend+shift): ADF* =", round(gh_ct$ADF, 4),
      "| Break year:", df$year[gh_ct$breakpoint], "\n")
  cat("Model C/S (regime):      ADF* =", round(gh_cs$ADF, 4),
      "| Break year:", df$year[gh_cs$breakpoint], "\n\n")

  # Gregory-Hansen 5% CVs: C=-4.61, C/T=-4.99, C/S=-4.95
  gh_cv5 <- c(C = -4.61, CT = -4.99, CS = -4.95)

  cat("Critical values (5%): C =", gh_cv5["C"],
      "| C/T =", gh_cv5["CT"],
      "| C/S =", gh_cv5["CS"], "\n")

  decisions <- c(
    C  = ifelse(gh_c$ADF  < gh_cv5["C"],  "Cointegration ✅", "No cointegration ❌"),
    CT = ifelse(gh_ct$ADF < gh_cv5["CT"], "Cointegration ✅", "No cointegration ❌"),
    CS = ifelse(gh_cs$ADF < gh_cv5["CS"], "Cointegration ✅", "No cointegration ❌")
  )
  cat("Decisions:\n")
  print(decisions)

  # Save Gregory-Hansen results
  gh_table <- tibble(
    Model       = c("C (level shift)", "C/T (level+trend)", "C/S (regime)"),
    ADF_star    = round(c(gh_c$ADF, gh_ct$ADF, gh_cs$ADF), 4),
    CV_5pct     = c(gh_cv5["C"], gh_cv5["CT"], gh_cv5["CS"]),
    Break_Year  = c(df$year[gh_c$breakpoint],
                    df$year[gh_ct$breakpoint],
                    df$year[gh_cs$breakpoint]),
    Decision    = unname(decisions)
  )

  write_csv(gh_table, paste0("data/gh_results_", format(Sys.Date(), "%Y%m%d"), ".csv"))
  cat("\n✅ Gregory-Hansen results saved.\n")

}, error = function(e) {
  cat("⚠️ GHtest failed:", conditionMessage(e), "\n")
  cat("Alternative: use EViews built-in Gregory-Hansen test.\n")
  cat("In EViews: Quick → Cointegration Test → Gregory-Hansen\n")
})

# ============================================================
# 3. HATEMI-J (2008) — Two Structural Breaks (optional upgrade)
# ============================================================
cat("\n=== HATEMI-J (2008) — Two Breaks [manual approach] ===\n")
cat("Full Hatemi-J test requires GAUSS or manual R implementation.\n")
cat("Approximation: search two break points that minimize ADF on residuals.\n\n")

# Grid search over two break points
min_stat  <- Inf
best_bp   <- c(NA, NA)
n         <- nrow(df)
trim      <- floor(0.15 * n)   # 15% trimming each end

for (i in (trim + 1):(n - trim - 1)) {
  for (j in (i + trim):(n - trim)) {
    d1 <- as.integer(1:n > i)
    d2 <- as.integer(1:n > j)
    fit_tmp <- lm(df$lnLCF ~ df$lnGDP + df$lnGDP2 + df$lnREN + df$lnTrade + d1 + d2)
    res_tmp <- residuals(fit_tmp)
    adf_tmp <- suppressWarnings(adf.test(res_tmp)$statistic)
    if (adf_tmp < min_stat) {
      min_stat <- adf_tmp
      best_bp  <- c(i, j)
    }
  }
}

cat("Hatemi-J approximation:\n")
cat("  Break 1:", df$year[best_bp[1]], "\n")
cat("  Break 2:", df$year[best_bp[2]], "\n")
cat("  Min ADF stat:", round(min_stat, 4), "\n")
cat("  Hatemi-J (2008) 5% CV ≈ -5.29 (Table 1, ADF* two-break)\n")
cat("  Decision:",
    ifelse(min_stat < -5.29, "Cointegration with two breaks ✅",
           "No cointegration ❌"), "\n")
cat("\n⚠️ VERIFY with EViews or GAUSS for exact Hatemi-J critical values.\n")

cat("\n=== 03_cointegration.R COMPLETE ===\n")
