# ============================================================
# 04_bootstrap_ardl.R
# LCF Turkey Bootstrap ARDL — Main Estimation (Naimoğlu method)
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Bootstrap ARDL cointegration (Özen & Shahbaz 2021, Energy Reports)
# R implementation via bootCT package + ARDL package
# bootCT: McNair, Gunby & Sollis (2021) bootstrap cointegration
# Reference: bootstrap critical values via 10,000 replications
# ============================================================

library(tidyverse)
library(ARDL)      # ardl(), bounds_f_test(), bounds_t_test()
library(bootCT)    # boot.ardl() bootstrap cointegration
library(dynlm)     # alternative ARDL via dynlm

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

cat("Bootstrap ARDL sample:", min(df$year), "–", max(df$year),
    "| T =", nrow(df), "\n\n")

# Convert to time series
df_ts <- ts(df |> select(-year), start = min(df$year), frequency = 1)

# ============================================================
# 1. ARDL MODEL SELECTION (AIC/BIC)
# ============================================================
cat("=== ARDL LAG ORDER SELECTION ===\n")

# Use ARDL package to search optimal lags (max 3 for small T=27)
best_ardl <- tryCatch({
  ardl_auto <- auto_ardl(
    lnLCF ~ lnGDP + lnGDP2 + lnREN + lnTrade,
    data      = df,
    max_order = c(3, 3, 3, 3, 3)  # named vector for ARDL package
  )
  cat("Optimal ARDL order (AIC):", paste(ardl_auto$top_orders[1, 1:5], collapse=","), "\n")
  cat("AIC:", round(ardl_auto$top_orders$AIC[1], 4), "\n\n")
  ardl_auto$best_model
}, error = function(e) {
  cat("⚠️ auto_ardl failed:", conditionMessage(e), "\n")
  cat("Fitting ARDL(1,1,1,1,1) as fallback...\n")
  ardl(lnLCF ~ lnGDP + lnGDP2 + lnREN + lnTrade,
       data = df, order = c(1, 1, 1, 1, 1))
})
cat("ARDL model summary:\n")
print(summary(best_ardl))

# ============================================================
# 2. STANDARD BOUNDS TEST (PSS 2001)
# ============================================================
cat("\n=== PESARAN-SHIN-SMITH (2001) BOUNDS TEST ===\n")
tryCatch({
  bounds_f <- bounds_f_test(best_ardl, case = 3)  # case 3: unrestricted intercept, no trend
  bounds_t <- bounds_t_test(best_ardl, case = 3)

  cat("F-statistic:", round(bounds_f$statistic, 4), "\n")
  cat("t-statistic:", round(bounds_t$statistic, 4), "\n")
  cat("\nPSS (2001) Critical Values (k=4 regressors):\n")
  print(bounds_f$tab)

}, error = function(e) {
  cat("⚠️ Bounds test failed:", conditionMessage(e), "\n")
})

# ============================================================
# 3. BOOTSTRAP ARDL (McNair et al. 2021 — bootCT package)
# ============================================================
cat("\n=== BOOTSTRAP ARDL COINTEGRATION TEST ===\n")
cat("Method: bootCT (McNair, Gunby & Sollis 2021)\n")
cat("Bootstrap replications: 10,000\n\n")

set.seed(20260426)  # reproducibility

tryCatch({
  boot_result <- boot.ardl(
    obj    = best_ardl,
    B      = 10000,    # bootstrap replications
    case   = 3,        # unrestricted intercept, no trend
    seed   = 20260426
  )

  cat("Bootstrap F-statistic:", round(boot_result$F.stat, 4), "\n")
  cat("Bootstrap p-value (F):", round(boot_result$p.value.F, 4), "\n")
  cat("Bootstrap t-statistic:", round(boot_result$t.stat, 4), "\n")
  cat("Bootstrap p-value (t):", round(boot_result$p.value.t, 4), "\n\n")

  cat("Bootstrap Critical Values:\n")
  cat("  F: 10% =", round(boot_result$cv.F[1], 3),
      "| 5% =", round(boot_result$cv.F[2], 3),
      "| 1% =", round(boot_result$cv.F[3], 3), "\n")
  cat("  t: 10% =", round(boot_result$cv.t[1], 3),
      "| 5% =", round(boot_result$cv.t[2], 3),
      "| 1% =", round(boot_result$cv.t[3], 3), "\n\n")

  f_decision <- ifelse(boot_result$p.value.F < 0.05,
    "REJECT H0 → Bootstrap ARDL confirms cointegration ✅",
    "Cannot reject H0 → No cointegration ❌")
  cat("F decision:", f_decision, "\n")

  # Save bootstrap results
  boot_table <- tibble(
    Statistic     = c("F-stat", "t-stat"),
    Value         = c(round(boot_result$F.stat, 4), round(boot_result$t.stat, 4)),
    p_value       = c(round(boot_result$p.value.F, 4), round(boot_result$p.value.t, 4)),
    CV_10pct      = c(round(boot_result$cv.F[1], 4), round(boot_result$cv.t[1], 4)),
    CV_5pct       = c(round(boot_result$cv.F[2], 4), round(boot_result$cv.t[2], 4)),
    CV_1pct       = c(round(boot_result$cv.F[3], 4), round(boot_result$cv.t[3], 4)),
    Decision      = c(f_decision, "—")
  )
  write_csv(boot_table, paste0("data/bootstrap_ardl_results_", format(Sys.Date(), "%Y%m%d"), ".csv"))
  cat("✅ Bootstrap ARDL results saved.\n")

}, error = function(e) {
  cat("⚠️ bootCT failed:", conditionMessage(e), "\n")
  cat("Install via: install.packages('bootCT')\n")
  cat("Or: remotes::install_github('Reckziegel/bootCT')\n")
})

# ============================================================
# 4. ARDL LONG-RUN COEFFICIENTS (from UECM)
# ============================================================
cat("\n=== LONG-RUN ARDL COEFFICIENTS (UECM) ===\n")

tryCatch({
  uecm_model <- uecm(best_ardl)  # Unrestricted ECM
  cat("UECM summary:\n")
  print(summary(uecm_model))

  lr_coef <- multipliers(best_ardl)
  cat("\nLong-run multipliers:\n")
  print(lr_coef)

  # ECT coefficient (speed of adjustment)
  recm_model <- recm(best_ardl, case = 3)  # Restricted ECM
  ect_coef   <- coef(recm_model)["ect"]
  cat("\nECT (speed of adjustment):", round(ect_coef, 4), "\n")
  cat("Expected: negative and significant (−0.2 to −0.9)\n")

}, error = function(e) {
  cat("⚠️ Long-run coefficients failed:", conditionMessage(e), "\n")
})

# ============================================================
# 5. DIAGNOSTIC TESTS
# ============================================================
cat("\n=== ARDL DIAGNOSTIC TESTS ===\n")

tryCatch({
  # Serial correlation: Breusch-Godfrey LM test
  library(lmtest)
  bg_test <- bgtest(best_ardl, order = 2)
  cat("Breusch-Godfrey LM (serial correlation):",
      round(bg_test$statistic, 4), "| p:", round(bg_test$p.value, 4), "\n")

  # Heteroskedasticity: ARCH test
  arch_test <- Box.test(residuals(best_ardl)^2, lag = 2, type = "Ljung-Box")
  cat("ARCH LM test:", round(arch_test$statistic, 4),
      "| p:", round(arch_test$p.value, 4), "\n")

  # Normality: Jarque-Bera
  jb_test <- jarque.bera.test(residuals(best_ardl))
  cat("Jarque-Bera normality:", round(jb_test$statistic, 4),
      "| p:", round(jb_test$p.value, 4), "\n")

  # CUSUM stability
  library(strucchange)
  cusum_test <- efp(lnLCF ~ lnGDP + lnGDP2 + lnREN + lnTrade,
                    data = df, type = "OLS-CUSUM")
  cusum_stable <- sctest(cusum_test)
  cat("CUSUM stability:", round(cusum_stable$statistic, 4),
      "| p:", round(cusum_stable$p.value, 4), "\n")

}, error = function(e) {
  cat("⚠️ Diagnostics failed:", conditionMessage(e), "\n")
})

cat("\n=== 04_bootstrap_ardl.R COMPLETE ===\n")
cat("Next step: Run 05_nardl.R for asymmetric estimation.\n")
