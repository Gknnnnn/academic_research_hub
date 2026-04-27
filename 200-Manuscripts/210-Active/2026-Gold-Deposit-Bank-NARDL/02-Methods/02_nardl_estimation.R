# ============================================================
# KG-MGO-02: Gold Deposits, Bank Performance, and Currency Risk
# Script 02: NARDL Asymmetric Estimation (ANA KATKI)
# Date: 2026-04-24 | Author: MGO
# ============================================================

library(ARDL)        # CRAN: ARDL bounds testing + NARDL
library(plm)
library(lmtest)
library(sandwich)
library(modelsummary)
library(tidyverse)

# ============================================================
# APPROACH A: Bank-Level Panel NARDL (primary)
# ============================================================

# ---- A1. Panel FE Baseline (OLS benchmark) ----
# ROA_it = αᵢ + γₜ + β₁·GOLD_DEP_it + β₂·ΔTRY_t + controls + εᵢₜ

fe_baseline_roa <- plm(
  roa ~ gold_dep_share + delta_try + log_assets +
    npl_ratio + inflation + gdp_growth + policy_rate +
    crisis_2018 + crisis_2021 + covid,
  data   = pdata_gold,
  model  = "within",
  effect = "twoways"
)

fe_baseline_nim <- update(fe_baseline_roa, nim ~ .)

# ---- A2. Panel NARDL: Partial Sum Decomposition ----
# ROA_it = αᵢ + γₜ + β⁺·GOLD_DEP⁺_it + β⁻·GOLD_DEP⁻_it
#          + δ⁺·ΔTRY⁺_t + δ⁻·ΔTRY⁻_t + controls + εᵢₜ

fe_nardl_roa <- plm(
  roa ~ gold_dep_pos + gold_dep_neg +     # asymmetric gold deposit
    delta_try_pos + delta_try_neg +       # asymmetric TRY
    log_assets + npl_ratio + inflation +
    gdp_growth + policy_rate +
    crisis_2018 + crisis_2021 + covid,
  data   = pdata_gold,
  model  = "within",
  effect = "twoways"
)

fe_nardl_nim <- update(fe_nardl_roa, nim ~ .)

# ---- A3. Wald Test: Symmetry Restrictions ----
# H0: β⁺ = β⁻ (symmetric gold deposit effect)
# H0: δ⁺ = δ⁻ (symmetric TRY effect)

wald_gold_sym <- linearHypothesis(fe_nardl_roa,
                                   "gold_dep_pos = gold_dep_neg",
                                   vcov. = vcovDC(fe_nardl_roa))
wald_try_sym  <- linearHypothesis(fe_nardl_roa,
                                   "delta_try_pos = delta_try_neg",
                                   vcov. = vcovDC(fe_nardl_roa))

cat("=== WALD TEST: Gold Deposit Symmetry ===\n")
print(wald_gold_sym)
cat("Expected: p < 0.05 → asymmetry confirmed\n")

cat("\n=== WALD TEST: TRY Depreciation Symmetry ===\n")
print(wald_try_sym)

# ---- A4. Interaction Term: Gold Deposit × TRY Depreciation ----
# Tests whether TRY depreciation amplifies the gold deposit channel

fe_interact <- plm(
  roa ~ gold_dep_share + delta_try + gold_try_interact +
    log_assets + npl_ratio + inflation + gdp_growth + policy_rate +
    crisis_2018 + crisis_2021 + covid,
  data   = pdata_gold,
  model  = "within",
  effect = "twoways"
)

cat("\n=== INTERACTION: Gold Deposit × TRY ===\n")
coeftest(fe_interact, vcov = vcovDC(fe_interact))
# Expected: gold_try_interact coefficient < 0
# Interpretation: TRY depreciation magnifies the negative gold-deposit ROA effect

# ============================================================
# APPROACH B: Time-Series NARDL (single aggregate series)
# ============================================================
# Useful for system-level interpretation if bank panel is thin

# Aggregate series: total system gold deposits + avg ROA
# agg_data <- panel_gold %>%
#   group_by(date) %>%
#   summarise(
#     roa_avg         = mean(roa, na.rm = TRUE),
#     nim_avg         = mean(nim, na.rm = TRUE),
#     gold_dep_total  = sum(gold_deposit_tl, na.rm = TRUE),
#     tryusd          = first(tryusd),
#     gold_price_try  = first(gold_price_try),
#     policy_rate     = first(policy_rate)
#   )

# library(ARDL)
# # Bounds test for cointegration
# bounds_model <- auto_ardl(roa_avg ~ gold_dep_total + tryusd + gold_price_try,
#                            data   = agg_data,
#                            max_order = 4)
# bounds_test <- bounds_test(bounds_model$best_model, alpha = 0.05)
# cat("Bounds test F-stat:", bounds_test$tab[1, "F"])

# NARDL (Shin et al. 2014)
# nardl_model <- auto_ardl(
#   roa_avg ~ L(gold_dep_pos) + L(gold_dep_neg) + tryusd + gold_price_try,
#   data      = agg_data,
#   max_order = 4,
#   selection = "AIC"
# )

# ============================================================
# APPROACH C: Heterogeneous Panel (PMG/AMG)
# ============================================================
# PMG: long-run homogeneous, short-run heterogeneous

library(plm)

# PMG (Pesaran, Shin, Smith 1999)
pmg_roa <- pmg(
  roa ~ gold_dep_share + delta_try + log_assets + npl_ratio,
  data  = pdata_gold,
  model = "pmg"
)

# AMG (Bond & Eberhardt 2013) — robust to cross-sectional dependence
# Requires: xtmg package (Stata) or manual R implementation
# As approximation, use CCEMG:
ccemg_roa <- pmg(
  roa ~ gold_dep_share + delta_try + log_assets + npl_ratio,
  data  = pdata_gold,
  model = "mg"  # Mean Group as baseline; full CCEMG needs augmentation
)

# ============================================================
# RESULTS TABLE
# ============================================================

nardl_table <- modelsummary(
  list(
    "M1: FE OLS (ROA)"     = fe_baseline_roa,
    "M2: FE OLS (NIM)"     = fe_baseline_nim,
    "M3: NARDL (ROA)"      = fe_nardl_roa,
    "M4: NARDL (NIM)"      = fe_nardl_nim,
    "M5: Interaction (ROA)" = fe_interact
  ),
  vcov  = list(
    vcovDC(fe_baseline_roa), vcovDC(fe_baseline_nim),
    vcovDC(fe_nardl_roa),    vcovDC(fe_nardl_nim),
    vcovDC(fe_interact)
  ),
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c(
    "gold_dep_share"  = "Gold deposit share (%)",
    "gold_dep_pos"    = "Gold deposit inflow (∂⁺)",
    "gold_dep_neg"    = "Gold deposit outflow (∂⁻)",
    "delta_try"       = "ΔTRY (depreciation)",
    "delta_try_pos"   = "TRY depreciation (∂⁺)",
    "delta_try_neg"   = "TRY appreciation (∂⁻)",
    "gold_try_interact" = "Gold deposit × ΔTRY",
    "log_assets"      = "Log total assets",
    "npl_ratio"       = "NPL ratio (%)",
    "policy_rate"     = "Policy rate (%)"
  ),
  title  = "Table 3: NARDL Panel Estimates — Gold Deposits and Bank Performance",
  output = "03-Results/table3_nardl_main.docx"
)

cat("NARDL results table saved.\n")
cat("\nKey economic interpretation:\n")
cat("β⁺ > 0 → gold inflows hurt ROA (margin compression hypothesis)\n")
cat("β⁺ < β⁻ → asymmetry: inflows hurt more than outflows help\n")
cat("gold_try_interact < 0 → TRY stress amplifies the gold deposit channel\n")
