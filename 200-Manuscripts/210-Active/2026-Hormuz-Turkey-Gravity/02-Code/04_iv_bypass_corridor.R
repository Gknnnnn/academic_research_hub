# ============================================================
# 04_iv_bypass_corridor.R
# IV-PPML: Control Function Approach — Bypass Corridor Instruments
#
# Endogeneity concern (İKB critique):
#   gpr_tur × hormuz may be endogenous: Turkey's corridor-promotion
#   activities during Hormuz crises generate news → raises GPRC_TUR
#   → upward bias in β_GPR×Hormuz.
#
# IV Strategy:
#   Instruments = GPRC_SAU × hormuz, GPRC_CHN × hormuz
#   Exclusion restriction:
#     - Saudi/China GPR levels are driven by their own geopolitical
#       dynamics (Saudi-Iran tensions, China's South China Sea/Taiwan
#       concerns) — exogenous to Turkey's bilateral exports.
#     - During Hormuz crises, both Saudi and Chinese GPR correlate
#       with Turkish GPR (common Persian Gulf shock), providing
#       instrument relevance.
#     - Saudi/Chinese GPR do not directly affect, e.g., Turkey-Germany
#       or Turkey-South Korea bilateral trade flows except through
#       Turkey's own corridor-activation response (exclusion holds
#       conditional on partner FE and year trend).
#
# Approach: Wooldridge (2015) Control Function (CF) for PPML
#   Step 1: OLS first stage — regress (gpr_tur × hormuz) on IVs + controls
#   Step 2: Add first-stage residuals (v_hat) to PPML second stage
#   Step 3: Bootstrap SEs (B=499, cluster by pair_id) for CF inference
#   Step 4: Report Hausman-type test: compare M3 to CF-corrected M3
#
# MGO | 2026-04-28
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(fixest)
  library(modelsummary)
  library(broom)
})

DATA_DIR   <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Hormuz-Turkey-Gravity/01-Data"
OUTPUT_DIR <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Hormuz-Turkey-Gravity/03-Output"
dir.create(OUTPUT_DIR, showWarnings = FALSE)

# ── 1. LOAD DATA (mirrors 03_merge_and_estimate.R) ──────────
cat("Loading data...\n")

baci <- read_csv(file.path(DATA_DIR, "baci_turkey_20260423.csv"),
                 show_col_types = FALSE) |>
  rename(trade = trade_value_usd) |>
  mutate(
    iso_o = "TUR",
    iso_d = countrycode::countrycode(iso_d_num, "iso3n", "iso3c", warn = FALSE),
    year  = as.integer(year)
  ) |>
  filter(!is.na(iso_d))

gpr_file <- list.files(DATA_DIR, pattern = "gpr_annual_.*\\.csv", full.names = TRUE)[1]
gpr <- read_csv(gpr_file, show_col_types = FALSE)
if ("yr" %in% names(gpr)) gpr <- gpr |> rename(year = yr)

wdi <- read_csv(
  list.files(DATA_DIR, pattern = "wdi_gdp_.*\\.csv", full.names = TRUE)[1],
  show_col_types = FALSE
)

geodist <- read_csv(
  list.files(DATA_DIR, pattern = "geodist_tur.*\\.csv", full.names = TRUE)[1],
  show_col_types = FALSE
)

hormuz_years <- c(2011L, 2012L, 2019L, 2020L, 2024L)

bri_iso3 <- c(
  "CHN","PAK","BGD","LKA","MDV","NPL","BTN",
  "KAZ","KGZ","TJK","TKM","UZB","MNG",
  "RUS","BLR","UKR","GEO","AZE","ARM",
  "IRN","IRQ","SAU","ARE","QAT","KWT","OMN",
  "EGY","ETH","KEN","TZA","MOZ","ZMB","AGO",
  "IDN","MYS","THA","PHL","VNM","MMR","KHM",
  "GRC","HUN","POL","CZE","SVK","ROU","BGR"
)

# ── 2. BUILD PANEL WITH IV VARIABLES ─────────────────────────
panel <- baci |>
  left_join(
    gpr |> select(year,
                  gpr_tur  = GPRC_TUR,
                  gpr_sau  = GPRC_SAU,
                  gpr_chn  = GPRC_CHN,
                  gpr_global = GPR),
    by = "year"
  ) |>
  left_join(
    wdi |> transmute(iso_d = iso3c, year, gdp_d = gdp_usd),
    by = c("iso_d", "year")
  ) |>
  left_join(
    wdi |> filter(iso3c == "TUR") |>
      transmute(year, gdp_tur = gdp_usd),
    by = "year"
  ) |>
  left_join(
    geodist |> select(iso_d, dist, contig),
    by = "iso_d"
  ) |>
  mutate(
    hormuz    = as.integer(year %in% hormuz_years),
    bri_d     = as.integer(iso_d %in% bri_iso3),
    ln_gdp_d  = log(gdp_d),
    yr_trend  = year - 2010L,
    pair_id   = paste(iso_o, iso_d, sep = "_"),
    # Endogenous: Turkey GPR × Hormuz (the interaction)
    gpr_x_hor = gpr_tur * hormuz,
    hor_bri   = hormuz * bri_d,
    # Bypass instruments (China and Saudi GPR × Hormuz)
    iv_chn    = gpr_chn * hormuz,   # China corridor bypass IV
    iv_sau    = gpr_sau * hormuz    # Saudi bypass IV
  ) |>
  filter(year >= 2010, year <= 2024,
         !is.na(trade), !is.na(gdp_d), !is.na(dist), !is.na(gpr_tur))

cat("Panel:", nrow(panel), "obs |", n_distinct(panel$iso_d), "partners |",
    n_distinct(panel$year), "years\n\n")

# ── 3. FIRST STAGE: OLS relevance test ───────────────────────
cat("=== FIRST STAGE: IV Relevance ===\n")

# Collapse to year-level for first stage (gpr_x_hor varies only by year)
year_level <- panel |>
  distinct(year, gpr_x_hor, iv_chn, iv_sau, gpr_tur, hormuz, yr_trend)

fs1 <- lm(gpr_x_hor ~ iv_chn + iv_sau + yr_trend, data = year_level)
fs_sum <- summary(fs1)

cat("First Stage (gpr_tur × hormuz ~ iv_chn + iv_sau):\n")
print(fs_sum$coefficients)
cat(sprintf("R² = %.4f | F = %.2f (p=%.4f)\n\n",
            fs_sum$r.squared,
            fs_sum$fstatistic[1],
            pf(fs_sum$fstatistic[1], fs_sum$fstatistic[2],
               fs_sum$fstatistic[3], lower.tail = FALSE)))

# First stage: China IV alone
fs_chn <- lm(gpr_x_hor ~ iv_chn + yr_trend, data = year_level)
cat("First Stage (China IV only): β_iv_chn =",
    round(coef(fs_chn)["iv_chn"], 4),
    "| t =", round(summary(fs_chn)$coefficients["iv_chn","t value"], 2), "\n")

# First stage: Saudi IV alone
fs_sau <- lm(gpr_x_hor ~ iv_sau + yr_trend, data = year_level)
cat("First Stage (Saudi IV only): β_iv_sau =",
    round(coef(fs_sau)["iv_sau"], 4),
    "| t =", round(summary(fs_sau)$coefficients["iv_sau","t value"], 2), "\n\n")

# ── 4. CONTROL FUNCTION APPROACH ─────────────────────────────
# Wooldridge (2015) CF for nonlinear models:
# 1. Get residuals from first stage
# 2. Include residuals in second-stage PPML
# 3. Test significance of residuals (endogeneity test)
cat("=== CONTROL FUNCTION APPROACH ===\n")

# First-stage residuals (merged back to panel)
panel <- panel |>
  left_join(
    year_level |>
      mutate(v_hat = residuals(fs1)) |>
      select(year, v_hat),
    by = "year"
  )

# M3 (baseline — no CF)
m3 <- feglm(
  trade ~ ln_gdp_d + yr_trend + gpr_tur + hormuz + gpr_x_hor + hor_bri | iso_d,
  data   = panel,
  family = poisson(),
  cluster = ~pair_id
)

# M3-CF: M3 + first-stage residuals (endogeneity correction)
m3_cf <- feglm(
  trade ~ ln_gdp_d + yr_trend + gpr_tur + hormuz + gpr_x_hor + hor_bri + v_hat | iso_d,
  data   = panel,
  family = poisson(),
  cluster = ~pair_id
)

cat("M3 (baseline) — β_GPR×Hormuz:\n")
cat(sprintf("  β = %.4f | SE = %.4f | p = %.4f\n",
    coef(m3)["gpr_x_hor"],
    sqrt(diag(vcov(m3)))["gpr_x_hor"],
    2 * pnorm(-abs(coef(m3)["gpr_x_hor"] /
                   sqrt(diag(vcov(m3)))["gpr_x_hor"]))))

cat("\nM3-CF (control function) — β_GPR×Hormuz:\n")
cat(sprintf("  β = %.4f | SE = %.4f | p = %.4f\n",
    coef(m3_cf)["gpr_x_hor"],
    sqrt(diag(vcov(m3_cf)))["gpr_x_hor"],
    2 * pnorm(-abs(coef(m3_cf)["gpr_x_hor"] /
                   sqrt(diag(vcov(m3_cf)))["gpr_x_hor"]))))

cat("\nEndogeneity test (CF residual coefficient):\n")
cat(sprintf("  β_v_hat = %.4f | SE = %.4f | p = %.4f\n",
    coef(m3_cf)["v_hat"],
    sqrt(diag(vcov(m3_cf)))["v_hat"],
    2 * pnorm(-abs(coef(m3_cf)["v_hat"] /
                   sqrt(diag(vcov(m3_cf)))["v_hat"]))))
cat("  (H0: gpr_x_hor exogenous; reject if p < 0.10)\n\n")

# ── 5. COMPARISON TABLE ───────────────────────────────────────
cat("=== COMPARISON TABLE ===\n")

models_iv <- list(
  "M3: Baseline PPML"       = m3,
  "M3-CF: Control Function" = m3_cf
)

coef_map_iv <- c(
  "ln_gdp_d"   = "ln GDP (Partner)",
  "yr_trend"   = "Year Trend",
  "gpr_tur"    = "GPR (Türkiye)",
  "hormuz"     = "Hormuz Crisis",
  "gpr_x_hor"  = "GPR × Hormuz [key]",
  "hor_bri"    = "Hormuz × BRI",
  "v_hat"      = "First-stage residual (CF)"
)

modelsummary(
  models_iv,
  stars    = c("*"=0.10, "**"=0.05, "***"=0.01),
  coef_map = coef_map_iv,
  gof_map  = c("nobs"),
  title    = "IV-PPML Robustness: Control Function — Bypass Corridor Instruments"
)

# Save table
library(flextable)
ft_iv <- modelsummary(
  models_iv,
  stars    = c("*"=0.10, "**"=0.05, "***"=0.01),
  coef_map = coef_map_iv,
  gof_map  = c("nobs"),
  title    = "Table A2: IV-PPML Control Function Robustness (Bypass Corridor Instruments)",
  notes    = list(
    "Instruments: GPRC_SAU × Hormuz, GPRC_CHN × Hormuz (Caldara & Iacoviello 2022).",
    "First-stage F-statistic reported in text. Cluster SEs (pair_id).",
    "CF residual significance = endogeneity test (H0: gpr_x_hor exogenous)."
  ),
  output = "flextable"
)
save_as_docx(ft_iv, path = file.path(OUTPUT_DIR, "tableA2_iv_cf_bypass.docx"))

# ── 6. NET EFFECT COMPARISON ─────────────────────────────────
cat("\n=== NET EFFECT: M3 vs M3-CF ===\n")
mean_gpr <- mean(panel$gpr_tur, na.rm = TRUE)

for (nm in c("M3", "M3-CF")) {
  m <- if (nm == "M3") m3 else m3_cf
  beta_hor  <- coef(m)["hormuz"]
  beta_int  <- coef(m)["gpr_x_hor"]
  net       <- beta_hor + beta_int * mean_gpr
  pct       <- (exp(net) - 1) * 100
  cat(sprintf("%s: β_Hormuz=%.4f | β_GPR×Hor=%.4f | net at mean GPR: %+.2f%%\n",
              nm, beta_hor, beta_int, pct))
}

cat("\nScript complete. Output:", OUTPUT_DIR, "\n")
