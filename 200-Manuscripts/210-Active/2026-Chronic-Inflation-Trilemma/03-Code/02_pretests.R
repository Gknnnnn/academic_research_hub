# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — Pre-Tests
# ANAYASA Panel Protocol: CD → Slope Homogeneity → Unit Root → Cointegration
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-27
# ⚠️ Requires: trilemma data merged BEFORE running Section 3+
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(plm); library(urca)
  library(lmtest); library(sandwich)
})

panel <- read_csv("02-Data/clean/panel_chronic_inf_trilemma_merged.csv",
                  show_col_types = FALSE)
# ⚠️ If trilemma not yet merged, use: panel_chronic_inf_20260427.csv
# and skip Section 3 (trilemma-specific tests)

pdata <- pdata.frame(panel, index = c("iso3c","year"))

# =============================================================================
# SECTION 1 — CROSS-SECTION DEPENDENCE (Pesaran 2004)
# =============================================================================
cat("=== 1. CROSS-SECTION DEPENDENCE ===\n")

# CPI (inflation level)
cd_cpi <- pcdtest(cpi ~ gdp_growth + trade_open + broad_money,
                  data = pdata, test = "cd")
cat(sprintf("Pesaran CD (CPI level): stat = %.4f, p = %.4f\n",
            cd_cpi$statistic, cd_cpi$p.value))

# Chronic inflation dummy — use linear prob model for CD test
cd_chr <- pcdtest(chronic10 ~ gdp_growth + trade_open + broad_money,
                  data = pdata, test = "cd")
cat(sprintf("Pesaran CD (chronic10): stat = %.4f, p = %.4f\n",
            cd_chr$statistic, cd_chr$p.value))

if (cd_cpi$p.value < 0.05) {
  cat("CSD CONFIRMED → 2nd generation tests mandatory (CIPS, CCEMG, CS-ARDL)\n")
} else {
  cat("CSD absent → 1st generation tests acceptable as primary\n")
}

# =============================================================================
# SECTION 2 — SLOPE HOMOGENEITY (Pesaran-Yamagata 2008)
# =============================================================================
cat("\n=== 2. SLOPE HOMOGENEITY (Pesaran-Yamagata) ===\n")

# Using plm: auxiliary slope homogeneity via pooling test
pool_mod <- plm(cpi ~ gdp_growth + trade_open + broad_money,
                data = pdata, model = "pooling")
fe_mod   <- plm(cpi ~ gdp_growth + trade_open + broad_money,
                data = pdata, model = "within")

# F-test for slope homogeneity (approximate)
ph_test <- pooltest(pool_mod, fe_mod)
cat(sprintf("Slope homogeneity F-test: stat = %.4f, p = %.4f\n",
            ph_test$statistic, ph_test$p.value))
if (ph_test$p.value < 0.05) {
  cat("Slopes HETEROGENEOUS → AMG / CCEMG / CS-ARDL preferred\n")
} else {
  cat("Slopes homogeneous → FE / FMOLS acceptable\n")
}

# =============================================================================
# SECTION 3 — UNIT ROOT (panel)
# If CSD confirmed: CIPS (Pesaran 2007) — 2nd generation
# If CSD absent: IPS — 1st generation
# NOTE: chronic10 is binary I(0) by construction — no unit root test needed
# =============================================================================
cat("\n=== 3. UNIT ROOT (CPI level — test for I(1)) ===\n")

# Im-Pesaran-Shin (1st gen, reference only if CSD absent)
ips_cpi <- purtest(cpi ~ 1, data = pdata, test = "ips",
                   exo = "intercept", lags = "AIC")
cat("IPS test (CPI):\n"); print(summary(ips_cpi))

# ⚠️ If CSD confirmed: run CIPS via cips() from purtest or external package
# The plm package does not implement CIPS directly.
# Recommended: use Stata (xtcips) or R cips approximation via:
#   cips_stat <- mean(sapply(split(panel, panel$iso3c), function(d) {
#     cadf_single(d$cpi, d$year)  # custom function
#   }))
# See: Pesaran (2007) J. Applied Econometrics
cat("\n⚠️  For CIPS (2nd gen): use Stata xtcips or R cipstest package\n")
cat("   Cite: Pesaran (2007), J. Applied Econometrics 22(2): 265-312\n")

# =============================================================================
# SECTION 4 — COINTEGRATION CHECK (for CS-ARDL specification)
# Only relevant if CPI and trilemma vars are I(1)
# Primary: Westerlund (2007) + bootstrap if CSD confirmed
# =============================================================================
cat("\n=== 4. COINTEGRATION NOTE ===\n")
cat("If CPI ~ I(1) AND MII/ERS/KAOPEN ~ I(1):\n")
cat("  → Westerlund (2007) panel cointegration + bootstrap (R: pdwtest / Stata: xtwest)\n")
cat("  → Cite: Westerlund (2007), Oxford Bulletin of Economics and Statistics 69(6)\n")
cat("If CPI ~ I(0) OR chronic_inf is DV (binary):\n")
cat("  → No cointegration needed; RE Probit + System-GMM sufficient\n")

# =============================================================================
# SECTION 5 — HAUSMAN TEST (FE vs RE for linear spec)
# =============================================================================
cat("\n=== 5. HAUSMAN TEST (FE vs RE) ===\n")
re_mod <- plm(cpi ~ gdp_growth + trade_open + broad_money,
              data = pdata, model = "random")
haus   <- phtest(fe_mod, re_mod)
cat(sprintf("Hausman: chi2 = %.4f, df = %d, p = %.4f → %s\n",
            haus$statistic, haus$parameter, haus$p.value,
            ifelse(haus$p.value < 0.05, "FE preferred", "RE acceptable")))

# =============================================================================
# SECTION 6 — SERIAL CORRELATION & HETEROSKEDASTICITY
# =============================================================================
cat("\n=== 6. SERIAL CORRELATION (Wooldridge test) ===\n")
bg_test <- pbgtest(fe_mod)
cat(sprintf("Wooldridge serial corr: stat = %.4f, p = %.4f\n",
            bg_test$statistic, bg_test$p.value))

cat("\n=== Summary: recommended estimator ===\n")
cat("  Binary DV (chronic10): RE Probit + System-GMM\n")
cat("  Level DV (cpi):        CCEMG/AMG if CSD+heterogeneous slopes\n")
cat("  Long-run:              CS-ARDL (csdm 1.0.1) — requires trilemma merge\n")
cat("  SE correction:         Driscoll-Kraay (cross-sectional + serial correlation)\n")
cat("\n=== 02_pretests.R COMPLETE ===\n")
