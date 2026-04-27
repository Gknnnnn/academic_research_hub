# ============================================================
# 06_fmols_ccr.R
# LCF Turkey Bootstrap ARDL — Long-Run Robustness
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Özbek-Naimoğlu standard robustness duo:
#   1. FMOLS (Fully Modified OLS — Phillips & Hansen 1990)
#   2. CCR  (Canonical Cointegrating Regression — Park 1992)
#   3. DOLS (Dynamic OLS — Stock & Watson 1993) — optional
# All three should be consistent with Bootstrap ARDL LR estimates
# ============================================================

library(tidyverse)
library(cointReg)   # cointRegFM(), cointRegCCR(), cointRegD()

# ============================================================
# LOAD DATA
# ============================================================
panel_file <- list.files("data", pattern = "turkey_lcf_panel_", full.names = TRUE) |>
  sort() |> tail(1)
panel <- read_csv(panel_file, show_col_types = FALSE)

df <- panel |>
  select(year, lnLCF, lnGDP, lnGDP2, lnREN, lnTrade) |>
  drop_na() |>
  arrange(year)

cat("Robustness sample:", min(df$year), "–", max(df$year), "| T =", nrow(df), "\n\n")

y <- df$lnLCF
X <- as.matrix(df |> select(lnGDP, lnGDP2, lnREN, lnTrade))

# ============================================================
# 1. FULLY MODIFIED OLS (FMOLS)
# ============================================================
cat("=== FMOLS (Phillips & Hansen 1990) ===\n")

tryCatch({
  fmols <- cointRegFM(
    x          = X,
    y          = y,
    kernel     = "ba",         # Bartlett kernel
    bandwidth  = "and",        # Andrews (1991) automatic bandwidth
    demeaning  = FALSE
  )

  cat("FMOLS Long-Run Coefficients:\n")
  fmols_coef <- cbind(
    Coefficient = round(fmols$theta, 4),
    Std_Error   = round(fmols$sd.theta, 4),
    t_stat      = round(fmols$t.theta, 4),
    p_value     = round(2 * pt(abs(fmols$t.theta), df = nrow(df) - 5, lower.tail = FALSE), 4)
  )
  rownames(fmols_coef) <- c("lnGDP", "lnGDP2", "lnREN", "lnTrade", "(Intercept)")
  print(fmols_coef)

  # EKC turning point from FMOLS
  b_gdp  <- fmols$theta[1]   # coefficient on lnGDP
  b_gdp2 <- fmols$theta[2]   # coefficient on lnGDP2

  if (!is.na(b_gdp2) && b_gdp2 != 0) {
    tp_fmols    <- exp(-b_gdp / (2 * b_gdp2))
    cat("\nFMOLS EKC turning point: USD", round(tp_fmols, 0), "per capita\n")
    cat("Shape:", ifelse(b_gdp2 > 0, "U-shaped (emission trap ↑ at high income)",
                         "Inverted-U (EKC ↓ at high income)"), "\n")
  }

}, error = function(e) {
  cat("⚠️ FMOLS failed:", conditionMessage(e), "\n")
  cat("Install cointReg: install.packages('cointReg')\n")
})

# ============================================================
# 2. CANONICAL COINTEGRATING REGRESSION (CCR)
# ============================================================
cat("\n=== CCR (Park 1992) ===\n")

tryCatch({
  ccr <- cointRegCCR(
    x          = X,
    y          = y,
    kernel     = "ba",
    bandwidth  = "and",
    demeaning  = FALSE
  )

  cat("CCR Long-Run Coefficients:\n")
  ccr_coef <- cbind(
    Coefficient = round(ccr$theta, 4),
    Std_Error   = round(ccr$sd.theta, 4),
    t_stat      = round(ccr$t.theta, 4),
    p_value     = round(2 * pt(abs(ccr$t.theta), df = nrow(df) - 5, lower.tail = FALSE), 4)
  )
  rownames(ccr_coef) <- c("lnGDP", "lnGDP2", "lnREN", "lnTrade", "(Intercept)")
  print(ccr_coef)

  b_gdp2_ccr <- ccr$theta[2]
  if (!is.na(b_gdp2_ccr) && b_gdp2_ccr != 0) {
    tp_ccr <- exp(-ccr$theta[1] / (2 * b_gdp2_ccr))
    cat("\nCCR EKC turning point: USD", round(tp_ccr, 0), "per capita\n")
  }

}, error = function(e) {
  cat("⚠️ CCR failed:", conditionMessage(e), "\n")
})

# ============================================================
# 3. DYNAMIC OLS (DOLS) — Optional Robustness
# ============================================================
cat("\n=== DOLS (Stock & Watson 1993) ===\n")

tryCatch({
  dols <- cointRegD(
    x          = X,
    y          = y,
    kernel     = "ba",
    bandwidth  = "and",
    demeaning  = FALSE,
    n.leads    = 1,
    n.lags     = 1
  )

  cat("DOLS Long-Run Coefficients:\n")
  dols_coef <- cbind(
    Coefficient = round(dols$theta, 4),
    Std_Error   = round(dols$sd.theta, 4),
    t_stat      = round(dols$t.theta, 4),
    p_value     = round(2 * pt(abs(dols$t.theta), df = nrow(df) - 5, lower.tail = FALSE), 4)
  )
  print(dols_coef)

}, error = function(e) {
  cat("⚠️ DOLS failed:", conditionMessage(e), "\n")
})

# ============================================================
# 4. SUMMARY TABLE — FMOLS / CCR / DOLS COMPARISON
# ============================================================
cat("\n=== ROBUSTNESS SUMMARY TABLE ===\n")
cat("Compare coefficients across FMOLS, CCR, DOLS.\n")
cat("Consistency check: same sign and similar magnitude → robust.\n\n")

# This table feeds directly into Table 3/4 of the manuscript
cat("Variable | FMOLS | CCR | DOLS\n")
cat("---------|-------|-----|-----\n")
cat("lnGDP    | [FMOLS β1] | [CCR β1] | [DOLS β1]\n")
cat("lnGDP2   | [FMOLS β2] | [CCR β2] | [DOLS β2]\n")
cat("lnREN    | [FMOLS β3] | [CCR β3] | [DOLS β3]\n")
cat("lnTrade  | [FMOLS β4] | [CCR β4] | [DOLS β4]\n")
cat("TP (USD) | [FMOLS TP] | [CCR TP] | [DOLS TP]\n")

cat("\n⚠️ LISSACK L1: All coefficients must be reported with SE + p-value.\n")
cat("⚠️ LISSACK L3: If CI spans zero, state 'not statistically confirmed at 95%'.\n")
cat("⚠️ ANAYASA: EKC shape must be described as:\n")
cat("   'consistent with U-shaped pattern' NOT 'proves EKC'.\n")

cat("\n=== 06_fmols_ccr.R COMPLETE ===\n")
cat("Next step: Run 07_causality.R for Toda-Yamamoto test.\n")
