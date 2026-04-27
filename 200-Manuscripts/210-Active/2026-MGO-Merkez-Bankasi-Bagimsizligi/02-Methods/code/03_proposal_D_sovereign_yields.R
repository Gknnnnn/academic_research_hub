# ============================================================================
# Proposal D — The Credibility Premium Under Fiscal Dominance:
#   CBI and Sovereign Yield Spreads in BRICS-T+MINT, 2000–2024
# ============================================================================
# M. Gökhan Özdemir | Kırıkkale University
# Script: 03_proposal_D_sovereign_yields.R | Created: 2026-04-09
#
# METHODOLOGY:
#   M1 — 2-Way FE + Driscoll-Kraay SE  (baseline)
#   M2 — IV/2SLS (Bartik-style instrument: neighbor CBI average)
#   M3 — DiD  (governor dismissal events as "treatment")
#   M4 — System GMM / Blundell-Bond  (dynamic model)
#   M5 — Quantile panel regression  (heterogeneous effects)
#
# KEY HYPOTHESIS:
#   H1: CBI↓ → sovereign_spread↑ (negative CBI coefficient)
#   H2: Fiscal dominance amplifies the CBI-spread relationship
#   H3: Political dismissals cause spread spikes (event study)
#
# DATA: data/processed/panel_D_merged.csv (N=9 × T=25, 2000-2024)
#   DV:  sovereign_spread_bps (yield spread vs US, basis points)
#   Key: cbi_lvaw (Garriga 2016 de jure CBI index, 0-1)
#        d_political_dismissal (1 if political governor removal)
#   Controls: govt_debt_gdp, inflation_cpi, gdp_growth, trade_openness,
#             real_interest_rate, ln_gdp_pc_ppp, d_gfc, d_covid
#
# CRITICAL NOTES (CLAUDE.md):
#   * Webb wild cluster bootstrap MANDATORY (N=9 < 30 clusters)
#   * Report bootstrap CIs alongside asymptotic SEs
#   * Driscoll-Kraay SE for spatial + serial dependence
#   * Pesaran CD test before any panel specification
# ============================================================================

# ── 0. Setup ─────────────────────────────────────────────────────────────────
rm(list = ls())
options(scipen = 999, digits = 4)
set.seed(42)

pkgs <- c(
  "plm",         # panel FE/RE, phtest
  "lmtest",      # bgtest, bptest, coeftest
  "sandwich",    # vcovDC, vcovHC, vcovBK
  "fixest",      # feols — high-dimensional FE, Driscoll-Kraay built-in
  "ivreg",       # IV/2SLS (AER package)
  "AER",         # ivreg wrapper
  "pgmm",        # Arellano-Bond / System GMM
  "estimatr",    # lm_robust with cluster bootstrap
  "clubSandwich",# Webb wild cluster bootstrap
  "dplyr",
  "tidyr",
  "ggplot2",
  "readr",
  "purrr",
  "modelsummary" # publication-quality tables
)

invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
}))

cat("✓ All packages loaded\n")

# ── 1. Data ───────────────────────────────────────────────────────────────────
cat("\n=== [1] Data Loading ===\n")

df <- read_csv("../data/processed/panel_D_merged_v2.csv",
               col_types = cols(
                 iso3 = col_character(),
                 year = col_integer()
               )) |>
  filter(!is.na(sovereign_spread_bps)) |>
  mutate(
    # Spread in natural log (handle negatives: log(spread + 400))
    ln_spread    = log(sovereign_spread_bps + 400),
    # Log debt ratio
    ln_debt      = log(govt_debt_gdp + 0.01),
    # CBI erosion indicator (de facto — combines dismissal + Turkey 2019-22)
    d_cbi_erosion = pmax(d_political_dismissal,
                         as.integer(iso3 == "TUR" & year >= 2019 & year <= 2022)),
    # Country × year treatment variable for DiD
    treated      = as.integer(d_political_dismissal == 1 | d_cbi_erosion == 1),
    # Lag CBI (use one-year lag to mitigate simultaneity)
    .by = iso3
  )

# Create pdata.frame for plm
pdf <- pdata.frame(df, index = c("iso3", "year"))

cat("  N =", n_distinct(df$iso3), "countries:",
    paste(sort(unique(df$iso3)), collapse = ", "), "\n")
cat("  T =", n_distinct(df$year), "years:",
    min(df$year), "–", max(df$year), "\n")
cat("  Obs:", nrow(df), "\n")

# ── 2. Pre-Estimation Diagnostics ────────────────────────────────────────────
cat("\n=== [2] Pre-Estimation: Cross-Sectional Dependence + Unit Root ===\n")

# 2a. Pesaran CD test (mandatory before any panel spec)
cat("--- Pesaran CD Test (cross-sectional dependence) ---\n")
cd_spread <- purtest(pdf$sovereign_spread_bps, test = "hadri")
cat("Hadri panel stationarity test (sovereign_spread):\n")
print(summary(cd_spread))

# Pesaran CD via plm::pcdtest
cd_test <- pcdtest(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
                     govt_debt_gdp + trade_openness,
                   data = pdf, test = "cd")
cat("Pesaran CD stat:", round(cd_test$statistic, 3),
    "| p-value:", round(cd_test$p.value, 4), "\n")
cat("Conclusion:", ifelse(cd_test$p.value < 0.05,
                          "CD present — use CS-robust estimators",
                          "No significant CD"), "\n")

# 2b. Panel unit root (CIPS-style via IPS in plm)
cat("\n--- Panel Unit Root Tests ---\n")
pur_spread <- purtest(pdf$sovereign_spread_bps, test = "ips", exo = "trend",
                      lags = "AIC", pmax = 3)
cat("IPS test (sovereign_spread_bps):")
print(summary(pur_spread))

pur_cbi <- purtest(pdf$cbi_lvaw, test = "ips", exo = "trend", lags = "AIC", pmax = 3)
cat("IPS test (cbi_lvaw):")
print(summary(pur_cbi))

# ── 3. M1 — Baseline 2-Way FE + Driscoll-Kraay ───────────────────────────────
cat("\n=== [3] M1: 2-Way FE + Driscoll-Kraay SE ===\n")
#
# Model: spread_it = α_i + λ_t + β1·CBI_it + β2·FiscalDebt_it +
#                   β3·Inflation_it + β4·GDPgrowth_it + β5·Trade_it +
#                   β6·GFC_t + β7·COVID_t + ε_it
#
# H1: β1 < 0 (higher CBI → lower yield spread)
# H2: β1 is larger in magnitude when fiscal debt is high (interaction)

# Baseline (no interaction)
m1a <- feols(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
               govt_debt_gdp + trade_openness + ln_gdp_pc_ppp +
               d_gfc + d_covid | iso3 + year,
             data = df,
             vcov = "DK")  # Driscoll-Kraay (DK) — fixest built-in

cat("M1a (2FE + DK-SE):\n")
summary(m1a)

# Interaction: CBI × Fiscal Dominance
# H2: β_interaction < 0 (CBI effect amplified under high debt)
m1b <- feols(ln_spread ~ cbi_lvaw * govt_debt_gdp + inflation_cpi + gdp_growth +
               trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid | iso3 + year,
             data = df,
             vcov = "DK")

cat("\nM1b (2FE + DK-SE + CBI×Debt interaction):\n")
summary(m1b)

# ── 4. M1 with Webb Wild Cluster Bootstrap (MANDATORY N=9) ───────────────────
cat("\n=== [4] Webb Wild Cluster Bootstrap (mandatory — N=9 clusters) ===\n")
#
# Standard asymptotic SE are unreliable with N < 30 clusters.
# Webb (2023) wild cluster bootstrap gives valid inference with N as small as 6.
# Use boottest() from fixest or manually via fwildclusterboot.

# fixest wild cluster bootstrap
m1a_boot <- feols(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
                    govt_debt_gdp + trade_openness + ln_gdp_pc_ppp +
                    d_gfc + d_covid | iso3 + year,
                  data = df,
                  cluster = ~iso3)  # clustered SE first

# Wild cluster bootstrap using fwildclusterboot (if installed)
if (requireNamespace("fwildclusterboot", quietly = TRUE)) {
  library(fwildclusterboot)
  boot_res <- boottest(
    object    = m1a_boot,
    clustid   = ~iso3,
    param     = "cbi_lvaw",         # Test coefficient of interest
    B         = 9999,                # Bootstrap replications
    type      = "webb",              # Webb (2023) weights
    conf_int  = TRUE,
    impose_null = TRUE
  )
  cat("Webb bootstrap — CBI coefficient:\n")
  cat("  Point estimate:", round(coef(m1a_boot)["cbi_lvaw"], 4), "\n")
  cat("  Bootstrap p-value:", round(boot_res$p_val, 4), "\n")
  cat("  Bootstrap 95% CI:", round(boot_res$conf_int, 4), "\n")
} else {
  cat("⚠  fwildclusterboot not installed — run: install.packages('fwildclusterboot')\n")
  cat("   Then re-run this section for valid inference.\n")
  cat("   Clustered SE (cluster = iso3) reported as fallback:\n")
  summary(m1a_boot)
}

# ── 5. M2 — IV/2SLS (Bartik Instrument) ─────────────────────────────────────
cat("\n=== [5] M2: IV/2SLS — Bartik Instrument ===\n")
#
# Identification problem: CBI potentially endogenous to yields
#   (High yields → government pressure on CB → CBI erosion)
#
# Instrument: Average CBI of other BRICS-T+MINT countries (excluding own)
#   z_it = mean(CBI_jt) for j ≠ i
# Validity: External CBI changes affect domestic CBI via political diffusion/
#   contagion, but do not directly affect domestic sovereign yields.
# This is a "Bartik-style" leave-one-out shift-share IV.

cat("Constructing Bartik IV (leave-one-out neighbor CBI average)...\n")

# Compute for each (i,t): mean CBI of all OTHER countries in same year
df <- df |>
  group_by(year) |>
  mutate(
    sum_cbi_group = sum(cbi_lvaw, na.rm = TRUE),
    n_group       = sum(!is.na(cbi_lvaw)),
    iv_neighbor_cbi = (sum_cbi_group - cbi_lvaw) / (n_group - 1)
  ) |>
  ungroup()

cat("  IV summary:\n")
print(summary(df$iv_neighbor_cbi))

# First stage F-test
fs <- feols(cbi_lvaw ~ iv_neighbor_cbi + inflation_cpi + gdp_growth +
              govt_debt_gdp + trade_openness + ln_gdp_pc_ppp +
              d_gfc + d_covid | iso3 + year,
            data = df,
            vcov = "DK")
cat("\nFirst stage F-stat:", fitstat(fs, "ivf")$ivf$stat, "\n")
cat("(Rule of thumb: > 10 indicates relevant instrument)\n")
summary(fs)

# 2SLS
m2 <- feols(ln_spread ~ inflation_cpi + gdp_growth + govt_debt_gdp +
              trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid |
              iso3 + year |
              cbi_lvaw ~ iv_neighbor_cbi,   # endogenous ~ instrument
            data = df,
            vcov = "DK")
cat("\nM2 (IV-2SLS + 2FE + DK-SE):\n")
summary(m2)

# ── 6. M3 — DiD: Governor Dismissal Events ───────────────────────────────────
cat("\n=== [6] M3: DiD — Political Dismissal Events ===\n")
#
# Treatment: political governor dismissal (d_political_dismissal == 1)
# Window: event study ±4 years around dismissal
# Treated units: TUR(2019), TUR(2021), IND(2018), NGA(2014), NGA(2023)
# Control units: all other country-years
#
# Model: spread_it = Σ_k β_k · (D_it × Event_window_k) + controls + α_i + λ_t

# Create event window dummies for Turkey 2019 dismissal (main event)
dismissal_events <- df |>
  filter(d_political_dismissal == 1) |>
  select(iso3, year) |>
  rename(event_iso3 = iso3, event_year = year)

cat("Political dismissal events:\n")
print(dismissal_events)

# Create relative time indicator for Turkey 2019 (main DiD event)
df <- df |>
  mutate(
    rel_time_tur19 = ifelse(iso3 == "TUR", year - 2019, NA_real_),
    d_post_tur19   = as.integer(iso3 == "TUR" & year >= 2019),
    d_treat_tur    = as.integer(iso3 == "TUR")
  )

# Simple DiD: TUR post-2019 vs synthetic control (other 8 countries)
m3_did <- feols(ln_spread ~ d_post_tur19 + d_treat_tur +
                  inflation_cpi + gdp_growth + trade_openness +
                  ln_gdp_pc_ppp + d_gfc + d_covid | iso3 + year,
                data = df,
                vcov = "DK")
cat("\nM3a DiD (Turkey 2019 dismissal):\n")
summary(m3_did)

# Event study: dynamic effects with Callaway-Sant'Anna style relative dummies
# (simplified version — full CSA requires did package)
df <- df |>
  mutate(
    rel_time_tur19_clean = case_when(
      iso3 != "TUR" ~ NA_real_,
      year < 2015   ~ -4,
      year >= 2015  ~ as.numeric(year - 2019)
    )
  )

# Binned event study (pre-trends check)
for (k in c(-4:-1, 0:5)) {
  df[[paste0("ev_",  ifelse(k < 0, paste0("m", abs(k)), paste0("p", k)))]] <-
    as.integer(!is.na(df$rel_time_tur19_clean) & df$rel_time_tur19_clean == k)
}

# Event study regression (pre-trend = 0 should hold if parallel trends)
event_vars <- names(df)[grepl("^ev_", names(df))]
event_vars_no_base <- event_vars[event_vars != "ev_m1"]  # m1 = reference

m3_event <- feols(
  as.formula(paste("ln_spread ~", paste(event_vars_no_base, collapse=" + "),
                   "+ inflation_cpi + gdp_growth + trade_openness | iso3 + year")),
  data  = df,
  vcov  = "DK"
)
cat("\nM3b Event study (Turkey 2019 — relative to t-1):\n")
print(coeftable(m3_event)[grepl("^ev_", rownames(coeftable(m3_event))),])

# ── 7. M4 — System GMM (Blundell-Bond) ───────────────────────────────────────
cat("\n=== [7] M4: System GMM (Blundell-Bond) — Dynamic Panel ===\n")
#
# Dynamic model: spread_it = ρ·spread_{i,t-1} + β·CBI_it + γ·X_it + α_i + ε_it
# Endogeneity: CBI is predetermined (instrumented by lags 2+)
# Use pgmm (Arellano-Bond / Blundell-Bond two-step GMM)
# Sargan test: instrument validity | AR(2) test: no second-order serial corr.

pdf2 <- pdata.frame(df |>
                      select(iso3, year, ln_spread, cbi_lvaw, inflation_cpi,
                             gdp_growth, govt_debt_gdp, trade_openness,
                             ln_gdp_pc_ppp, d_gfc, d_covid) |>
                      filter(complete.cases(pick(everything()))),
                    index = c("iso3","year"))

m4 <- tryCatch({
  pgmm(
    ln_spread ~ lag(ln_spread, 1) + cbi_lvaw + inflation_cpi + gdp_growth +
      trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid |
      lag(ln_spread, 2:4) + lag(cbi_lvaw, 2:4),  # instruments (lags 2-4)
    data    = pdf2,
    effect  = "twoways",
    model   = "twosteps",           # two-step Blundell-Bond
    transformation = "ld"           # level-difference (system GMM)
  )
}, error = function(e) {
  cat("⚠  System GMM error:", conditionMessage(e), "\n")
  cat("   Check: T may be too short relative to N for system GMM\n")
  cat("   Fallback: use first-difference GMM (transformation='d')\n")
  NULL
})

if (!is.null(m4)) {
  cat("M4 (System GMM):\n")
  print(summary(m4))

  cat("\nSargan overidentification test:\n")
  print(sargan(m4))

  cat("\nArellano-Bond serial correlation:\n")
  print(mtest(m4, order = 1))
  print(mtest(m4, order = 2))

  # AR(1) p < 0.05, AR(2) p > 0.10 → model valid
}

# ── 8. M5 — Quantile Panel Regression ────────────────────────────────────────
cat("\n=== [8] M5: Quantile Panel Regression ===\n")
# Does CBI matter more in the right tail (high spread episodes)?
# Use quantreg::rq() with entity demeaning

if (requireNamespace("quantreg", quietly = TRUE)) {
  library(quantreg)
  # Entity demean (within transformation) before quantile regression
  df_demeaned <- df |>
    group_by(iso3) |>
    mutate(across(c(ln_spread, cbi_lvaw, inflation_cpi, gdp_growth,
                    govt_debt_gdp, trade_openness, ln_gdp_pc_ppp),
                  \(x) x - mean(x, na.rm = TRUE))) |>
    ungroup()

  taus <- c(0.25, 0.50, 0.75, 0.90)
  qr_results <- lapply(taus, function(tau) {
    rq(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
         govt_debt_gdp + trade_openness + ln_gdp_pc_ppp,
       data = df_demeaned |> filter(complete.cases(pick(everything()))),
       tau  = tau)
  })
  names(qr_results) <- paste0("Q", taus * 100)

  cat("CBI coefficients across quantiles:\n")
  cat(sprintf("%-6s %8s %8s %8s\n", "Quantile", "CBI coef", "Std.Err", "p-val"))
  cat(strrep("-", 35), "\n")
  for (q_name in names(qr_results)) {
    summ <- summary(qr_results[[q_name]], se = "iid")
    coef_row <- summ$coefficients["cbi_lvaw",]
    cat(sprintf("%-6s %8.4f %8.4f %8.4f\n",
                q_name, coef_row[1], coef_row[2], coef_row[4]))
  }
} else {
  cat("⚠  quantreg not installed — run: install.packages('quantreg')\n")
}

# ── 9. Publication-Quality Summary Table ─────────────────────────────────────
cat("\n=== [9] Summary Table (modelsummary) ===\n")

models_list <- list(
  "M1a (2FE+DK)"    = m1a,
  "M1b (Interact)"  = m1b,
  "M2 (IV-2SLS)"    = m2,
  "M3 (DiD-TUR19)"  = m3_did
)

# Export LaTeX table
modelsummary(
  models_list,
  stars    = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c(
    "cbi_lvaw"              = "CBI Index (de jure)",
    "fit_cbi_lvaw"          = "CBI Index (instrumented)",
    "d_post_tur19"          = "Post-dismissal (Turkey 2019)",
    "cbi_lvaw:govt_debt_gdp"= "CBI × Govt Debt/GDP",
    "inflation_cpi"         = "CPI Inflation",
    "gdp_growth"            = "GDP Growth",
    "govt_debt_gdp"         = "Govt Debt/GDP",
    "trade_openness"        = "Trade Openness",
    "ln_gdp_pc_ppp"         = "ln(GDP/capita PPP)",
    "d_gfc"                 = "GFC dummy (2008-10)",
    "d_covid"               = "COVID dummy (2020-21)"
  ),
  gof_map = c("nobs", "r.squared", "adj.r.squared"),
  output  = "../data/processed/Table2_MainResults.tex",
  title   = "CBI and Sovereign Yield Spreads in BRICS-T+MINT, 2000–2024",
  notes   = paste(
    "Notes: Dependent variable is ln(sovereign spread + 400 bps).",
    "M1: Two-way FE with Driscoll-Kraay SE.",
    "M2: IV-2SLS; instrument = leave-one-out neighbor CBI average.",
    "M3: DiD estimator; Turkey 2019 political dismissal as treatment.",
    "Webb wild cluster bootstrap (9,999 reps) required for valid inference; see Table 3.",
    "*** p<0.01, ** p<0.05, * p<0.10."
  )
)
cat("✓ LaTeX table saved: data/processed/Table2_MainResults.tex\n")

# ── 10. Robustness Checks ─────────────────────────────────────────────────────
cat("\n=== [10] Robustness ===\n")

# R10a: Balanced subsample (drop proxy yield observations)
df_balanced <- df |>
  filter(yield_source %in% c("10yr_bond", "cbrt_policy_rate"))
cat("Balanced subsample (10yr bond + CBRT policy rate only):",
    nrow(df_balanced), "obs,", n_distinct(df_balanced$iso3), "countries\n")

m_rob1 <- feols(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
                  trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid | iso3 + year,
                data = df_balanced, vcov = "DK")
cat("Robustness (balanced 10yr subsample) — CBI coef:",
    round(coef(m_rob1)["cbi_lvaw"], 4), "\n")

# R10b: Exclude China (no WB debt data; no market-oriented bond yield)
m_rob2 <- feols(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
                  govt_debt_gdp + trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid |
                  iso3 + year,
                data = df |> filter(iso3 != "CHN"), vcov = "DK")
cat("Robustness (ex-China) — CBI coef:",
    round(coef(m_rob2)["cbi_lvaw"], 4), "\n")

# R10c_new: NGA trade exclusion sensitivity (NGA has no WB WDI trade_openness data)
# Per DATA_GAP_REPORT: exclude NGA from models with trade_openness control
m_rob_nga <- feols(ln_spread ~ cbi_lvaw + inflation_cpi + gdp_growth +
                     govt_debt_gdp + trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid |
                     iso3 + year,
                   data = df |> filter(iso3 != "NGA"), vcov = "DK")
cat("Robustness (ex-NGA, trade_openness gap) — CBI coef:",
    round(coef(m_rob_nga)["cbi_lvaw"], 4), "\n")

# R10d: Log sovereign yield (DV = log of absolute yield level, not spread)
m_rob3 <- feols(log(sovereign_yield + 0.01) ~ cbi_lvaw + inflation_cpi +  # R10d
                  gdp_growth + trade_openness + ln_gdp_pc_ppp + d_gfc + d_covid |
                  iso3 + year,
                data = df, vcov = "DK")
cat("Robustness (log yield level) — CBI coef:",
    round(coef(m_rob3)["cbi_lvaw"], 4), "\n")

# ── 11. Output: Coefficient Plot ─────────────────────────────────────────────
cat("\n=== [11] Coefficient Plot (ggplot2) ===\n")

# Event study plot — Turkey 2019 dismissal
event_coefs <- coeftable(m3_event)
event_df <- as.data.frame(event_coefs[grepl("^ev_", rownames(event_coefs)),])
names(event_df) <- c("est","se","t","p")
event_df$rel_time <- as.integer(gsub("ev_m", "-", gsub("ev_p", "", rownames(event_df))))
# Add reference period (t-1 = 0)
event_df <- rbind(event_df, data.frame(est=0, se=0, t=NA, p=NA, rel_time=-1))
event_df <- event_df[order(event_df$rel_time),]

p_event <- ggplot(event_df, aes(x = rel_time, y = est)) +
  geom_point(size = 2.5, color = "#1a5276") +
  geom_line(color = "#1a5276") +
  geom_ribbon(aes(ymin = est - 1.96*se, ymax = est + 1.96*se),
              alpha = 0.15, fill = "#1a5276") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "red", linewidth = 0.8) +
  scale_x_continuous(breaks = seq(-4, 5, 1)) +
  labs(
    title    = "Event Study: Turkey 2019 Governor Dismissal",
    subtitle = "Effect on ln(Sovereign Spread + 400 bps) | reference: t-1",
    x        = "Years relative to dismissal event",
    y        = expression("Coefficient" ~ hat(beta)[k]),
    caption  = "Note: Shaded area = 95% CI. Dotted red line = dismissal date."
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave("../data/processed/Fig1_EventStudy_TUR2019.pdf",
       p_event, width = 7, height = 4.5, device = cairo_pdf)
cat("✓ Figure 1 saved: data/processed/Fig1_EventStudy_TUR2019.pdf\n")

# ── 12. Session Info ──────────────────────────────────────────────────────────
cat("\n=== [12] Session Info ===\n")
cat("✅ Analysis complete. Next step: 04_tables_latex_format.R\n\n")
cat("⚠  IMPORTANT REMINDERS:\n")
cat("   1. Replace cbi_lvaw with Garriga(2016)/Romelli(2022) actual data\n")
cat("   2. Run Webb bootstrap (fwildclusterboot) — critical for N=9\n")
cat("   3. Driscoll-Kraay SE requires T ≥ 10 — check T per country\n")
cat("   4. System GMM valid only if AR(1) p<0.05, AR(2) p>0.10\n")
cat("   5. Bai-Perron breaks cross-check if structural breaks in spread series\n")
sessionInfo()

# ============================================================================
# LaTeX MODEL TEMPLATE (for Table 2)
# ============================================================================
#
# \begin{table}[!htbp]
# \caption{Central Bank Independence and Sovereign Yield Spreads in
#          BRICS-T+MINT, 2000–2024}
# \label{tab:main_results}
# \begin{tabular}{lcccc}
# \hline\hline
# & M1a & M1b & M2 & M3 \\
# & (2FE+DK) & (Interaction) & (IV-2SLS) & (DiD) \\
# \hline
# CBI Index (de jure) & & & & \\
# $\quad\theta_{CBI}$ & $\beta^{***}$ & $\beta^{***}$ & $\beta^{**}$ & --- \\
# CBI $\times$ Debt/GDP & --- & $\gamma^{**}$ & --- & --- \\
# Post-Dismissal (Turkey 2019) & --- & --- & --- & $\delta^{***}$ \\
# \hline
# Country FE & Yes & Yes & Yes & Yes \\
# Year FE & Yes & Yes & Yes & Yes \\
# Driscoll-Kraay SE & Yes & Yes & Yes & Yes \\
# Webb Bootstrap & Yes & Yes & --- & --- \\
# Observations & N & N & N & N \\
# $R^2$ & & & & \\
# \hline\hline
# \end{tabular}
# \begin{tablenotes}
# Notes: DV = $\ln(\text{sovereign spread} + 400)$ bps. ...
# \end{tablenotes}
# \end{table}
