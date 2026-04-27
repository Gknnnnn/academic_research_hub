###############################################################################
# Appendix A4 — Semi-log ARDL with mean-centred temperature anomaly
# Purpose: robustness check responding to log-temperature functional-form concern
# Inputs : data/turkey_climate_agri_1970_2021.xlsx (already cleaned)
# Outputs: results/appendix_A4_semi_log.tex, results/appendix_A4_semi_log.csv
# Note   : Run from project root of 2026-MGO-Climate-Agriculture-Turkey-ARDL
###############################################################################

library(readxl)
library(ARDL)        # Natsiopoulos & Tzeremes (2022), v>=0.2.0
library(lmtest)
library(sandwich)

DATA_PATH <- "data/turkey_climate_agri_1970_2021.xlsx"
raw <- read_excel(DATA_PATH, sheet = "Sayfa1")
names(raw) <- c("year","alan_raw","ava","co2_raw","tsso_raw","tsa","pr")

# Transformations — semi-log for temperature:
df <- data.frame(
  lnAVA     = log(raw$ava),
  lnPR      = log(raw$pr),
  TSA_anom  = raw$tsa - mean(raw$tsa, na.rm = TRUE),   # °C-level anomaly
  lnTSSO    = log(raw$tsso_raw),
  lnALAN    = log(raw$alan_raw / 10),
  lnCO2_pc  = log(raw$co2_raw)
)
df <- ts(df, start = 1970, end = 2021, frequency = 1)

# Auto-select ARDL (max_order = 4 per variable, AIC)
fit <- auto_ardl(
  lnAVA ~ lnPR + TSA_anom + lnTSSO + lnALAN + lnCO2_pc,
  data = df, max_order = 4, selection = "AIC"
)
best <- fit$best_model
cat("Selected ARDL order:\n"); print(fit$best_order)

# Bounds F-test
b <- bounds_f_test(best, case = 3)  # restricted intercept, no trend
cat("\nBounds F-statistic:", round(b$statistic, 3),
    "  p-value:", signif(b$p.value, 4), "\n")

# Long-run elasticities via multiplier recovery
mult <- multipliers(best, type = "lr")
print(mult)

# Diagnostics
res <- residuals(best)
cat("\nBG LM(2)      :", round(bgtest(best, order = 2)$p.value, 3),
    "\nRESET (F)     :", round(resettest(best, power = 2:3)$p.value, 3),
    "\nJarque-Bera p :", round(tseries::jarque.bera.test(res)$p.value, 3),
    "\nBPG           :", round(bptest(best)$p.value, 3), "\n")

# Write results
dir.create("results", showWarnings = FALSE)
write.csv(mult, "results/appendix_A4_semi_log.csv", row.names = FALSE)
cat("\n✔ Appendix A4 semi-log results written to results/appendix_A4_semi_log.csv\n")
cat("  Compare coefficients with Table 2 Panel B (log-log spec) for §5.4 robustness.\n")
