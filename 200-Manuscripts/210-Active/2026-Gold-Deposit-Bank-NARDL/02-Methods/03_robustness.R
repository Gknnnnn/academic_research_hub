# ============================================================
# KG-MGO-02: Gold Deposits, Bank Performance, and Currency Risk
# Script 03: Robustness Checks
# Date: 2026-04-24 | Author: MGO
# ============================================================

library(plm); library(lmtest); library(sandwich)
library(fwildclusterboot); library(tidyverse)

# ---- R1: NIM as dependent variable (already in main table) ----
# ROE as alternative
fe_nardl_roe <- plm(
  roe ~ gold_dep_pos + gold_dep_neg + delta_try_pos + delta_try_neg +
    log_assets + npl_ratio + policy_rate + inflation + crisis_2018 + covid,
  data = pdata_gold, model = "within", effect = "twoways"
)

# ---- R2: State banks vs private banks ----
pdata_state   <- pdata_gold %>% filter(bank_type == "kamu")
pdata_private <- pdata_gold %>% filter(bank_type == "özel")

fe_nardl_state <- plm(
  roa ~ gold_dep_pos + gold_dep_neg + delta_try_pos + delta_try_neg +
    log_assets + npl_ratio + policy_rate,
  data = pdata_state, model = "within", effect = "twoways"
)

fe_nardl_private <- update(fe_nardl_state, data = pdata_private)

cat("=== R2: State vs Private Banks ===\n")
cat("Expected: state banks less sensitive (implicit government guarantee)\n")
cat("Private banks: larger gold deposit channel coefficient\n")

# ---- R3: Participation (Islamic) banks only ----
# Gold deposits are especially prominent in katılım banking
pdata_katilim <- pdata_gold %>% filter(bank_type == "katılım")

fe_nardl_katilim <- update(fe_nardl_state, data = pdata_katilim)

# ---- R4: Controlling for gold price change ----
fe_nardl_goldprice <- plm(
  roa ~ gold_dep_pos + gold_dep_neg + delta_try_pos + delta_try_neg +
    delta_gold_try +  # gold price TRY-denominated change
    log_assets + npl_ratio + policy_rate + inflation + crisis_2018 + covid,
  data = pdata_gold, model = "within", effect = "twoways"
)

# ---- R5: Webb Wild Cluster Bootstrap ----
# Mandatory: N ≈ 20-28 banks (clusters < 30)
set.seed(2024)
webb_gold <- boottest(
  object    = fe_nardl_roa,
  param     = "gold_dep_pos",  # test key coefficient
  B         = 9999,
  clustid   = "bank_id",
  type      = "webb",
  conf_int  = TRUE,
  alpha     = 0.05
)

cat("\n=== R5: Webb Bootstrap — gold_dep_pos ===\n")
cat(sprintf("p-value: %.4f | 95%% CI: [%.4f, %.4f]\n",
            webb_gold$p_val, webb_gold$conf_int[1], webb_gold$conf_int[2]))

# ---- R6: Structural Break — Bai-Perron ----
# Test if gold deposit – ROA relationship shifts after 2018 or 2021
library(strucchange)

# Aggregate time-series test
agg_ts <- pdata_gold %>%
  group_by(date) %>%
  summarise(roa_avg = mean(roa, na.rm = TRUE),
            gold_dep_share_avg = mean(gold_dep_share, na.rm = TRUE),
            delta_try = first(delta_try)) %>%
  arrange(date) %>%
  drop_na()

bp_gold <- breakpoints(roa_avg ~ gold_dep_share_avg + delta_try, data = agg_ts)
cat("\n=== R6: Bai-Perron Structural Breaks ===\n")
summary(bp_gold)
# Expected breaks: 2018Q3 (TRY crisis) and/or 2021Q4 (rate reversal)

# ---- ROBUSTNESS SUMMARY TABLE ----
rob_summary <- modelsummary(
  list(
    "R1: ROE (DV)"      = fe_nardl_roe,
    "R2: State banks"   = fe_nardl_state,
    "R2: Private banks" = fe_nardl_private,
    "R3: Katılım"       = fe_nardl_katilim,
    "R4: Gold price ctrl" = fe_nardl_goldprice
  ),
  vcov   = "DR",   # Driscoll-Kraay shorthand
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c("gold_dep_pos" = "Gold deposit inflow (∂⁺)",
               "gold_dep_neg" = "Gold deposit outflow (∂⁻)",
               "delta_try_pos" = "TRY depreciation (∂⁺)",
               "delta_try_neg" = "TRY appreciation (∂⁻)"),
  title  = "Table 5: Robustness Checks — KG-MGO-02",
  output = "03-Results/table5_robustness.docx"
)

cat("\nRobustness table saved.\n")
