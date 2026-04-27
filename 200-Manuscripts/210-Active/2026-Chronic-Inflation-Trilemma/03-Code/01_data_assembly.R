# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — Data Assembly
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Kırıkkale University, Department of Economics
# Date: 2026-04-27
# ANAYASA: Cross-check every value. No unverified data enters analysis.
# =============================================================================

library(WDI)
library(tidyverse)
library(haven)

# --- PATHS -------------------------------------------------------------------
RAW_DIR   <- here::here("02-Data/raw")
CLEAN_DIR <- here::here("02-Data/clean")
DATE_TAG  <- format(Sys.Date(), "%Y%m%d")

# =============================================================================
# 1. WORLD BANK WDI — Inflation + Controls
# =============================================================================
cat("Fetching WDI data...\n")

wdi_raw <- WDI(
  country   = "all",
  indicator = c(
    cpi         = "FP.CPI.TOTL.ZG",   # CPI inflation, annual %
    gdp_growth  = "NY.GDP.MKTP.KD.ZG", # GDP growth, annual %
    trade_open  = "NE.TRD.GNFS.ZS",    # Trade (% GDP)
    broad_money = "FM.LBL.BMNY.GD.ZS", # Broad money (% GDP)
    fdi         = "BX.KLT.DINV.WD.GD.ZS", # FDI net inflows (% GDP)
    fiscal_bal  = "GC.BAL.CASH.GD.ZS", # Cash surplus/deficit (% GDP)
    tot         = "TT.PRI.MRCH.XD.WD"  # Terms of trade index
  ),
  start = 1980,
  end   = 2023,
  extra = TRUE   # region, income, iso3c
)

cat(sprintf("WDI raw: %d obs, %d countries\n",
            nrow(wdi_raw), n_distinct(wdi_raw$iso3c)))

# Save raw — ANAYASA: raw/ is never modified
write_csv(wdi_raw, file.path(RAW_DIR,
          paste0("wdi_raw_", DATE_TAG, ".csv")))
cat("✅ WDI raw saved\n")

# =============================================================================
# 2. CROSS-CHECK — Inflation validation (ANAYASA protocol)
# Manual spot-check: compare WDI vs IMF IFS for 5 countries
# =============================================================================
CHECK_COUNTRIES <- c("TUR", "BRA", "ARG", "GHA", "ZMB")
CHECK_YEARS     <- c(2015, 2018, 2020, 2022)

cat("\n⚠️  CROSS-CHECK REQUIRED — Inflation spot-check:\n")
cat("Compare these values against IMF IFS / Trading Economics before proceeding\n\n")

wdi_raw %>%
  filter(iso3c %in% CHECK_COUNTRIES,
         year  %in% CHECK_YEARS,
         !is.na(cpi)) %>%
  select(country, iso3c, year, cpi) %>%
  arrange(iso3c, year) %>%
  print(n = 40)

# =============================================================================
# 3. TRILEMMA INDICES — Aizenman-Chinn-Ito
# ⚠️  MANUAL DOWNLOAD REQUIRED before this block runs:
#     1. Go to: https://web.pdx.edu/~ito/trilemma_indexes.htm
#     2. Download: trilemma_indexes_update2020.dta
#     3. Save to: 02-Data/raw/trilemma_indexes_update2020.dta
#
# Cite: Aizenman, Chinn & Ito (2010) JIMF Vol.29 No.4
#       Aizenman, Chinn & Ito (2013) RIE 21(3):447-458
# =============================================================================
TRILEMMA_FILE <- file.path(RAW_DIR, "trilemma_indexes_update2020.dta")

if (!file.exists(TRILEMMA_FILE)) {
  stop(paste0(
    "\n❌ BLOCKER: Trilemma index file not found.\n",
    "   Download from: https://web.pdx.edu/~ito/trilemma_indexes.htm\n",
    "   Save to: ", TRILEMMA_FILE, "\n"
  ))
}

trilemma_raw <- read_dta(TRILEMMA_FILE)

cat("\nTrilemma dataset dimensions:", dim(trilemma_raw), "\n")
cat("Variables:", names(trilemma_raw), "\n")
cat("Year range:", range(trilemma_raw$year, na.rm = TRUE), "\n")

# Standardise country identifier — trilemma uses 'wbcode' or 'iso2'
# Inspect and rename as needed:
trilemma <- trilemma_raw %>%
  rename_with(tolower) %>%
  # Typical variable names in ACI dataset:
  # mi  = monetary independence index
  # ers = exchange rate stability
  # ka  = KAOPEN (capital account openness, normalised 0-1)
  # Rename to project convention:
  rename(
    iso3c = any_of(c("wbcode", "iso3c", "country_code")),
    MII   = any_of(c("mi", "mi_index", "mi2")),
    ERS   = any_of(c("ers", "ers_index")),
    KAOPEN = any_of(c("ka", "kaopen", "fi"))
  ) %>%
  select(iso3c, year, MII, ERS, KAOPEN) %>%
  filter(!is.na(MII))

cat(sprintf("Trilemma clean: %d obs, %d countries, years %d–%d\n",
            nrow(trilemma),
            n_distinct(trilemma$iso3c),
            min(trilemma$year), max(trilemma$year)))

# Save raw trilemma (standardised)
write_csv(trilemma, file.path(RAW_DIR,
          paste0("trilemma_standardised_", DATE_TAG, ".csv")))

# =============================================================================
# 4. SAMPLE SELECTION — Developing + Emerging economies, 1985–2020
# =============================================================================
INCOME_GROUPS <- c("Lower middle income", "Upper middle income", "Low income")

panel_base <- wdi_raw %>%
  filter(
    income %in% INCOME_GROUPS,
    year >= 1985,
    year <= 2020,
    !is.na(iso3c),
    iso3c != "USA"   # Nth country — ACI 2013
  ) %>%
  select(iso3c, country, year, region, income,
         cpi, gdp_growth, trade_open, broad_money, fdi, fiscal_bal, tot)

cat(sprintf("\nBase sample: %d obs, %d countries\n",
            nrow(panel_base), n_distinct(panel_base$iso3c)))

# =============================================================================
# 5. MERGE — WDI × Trilemma
# =============================================================================
panel <- panel_base %>%
  left_join(trilemma, by = c("iso3c", "year"))

# Merge diagnostics
merged_countries <- panel %>% filter(!is.na(MII)) %>% pull(iso3c) %>% n_distinct()
cat(sprintf("After merge: %d countries with trilemma data\n", merged_countries))

# =============================================================================
# 6. CONSTRUCT CHRONIC INFLATION DUMMY
# Primary definition: CPI > 10% for ≥ 3 consecutive years
# Robustness variants: threshold = 7%, 15%; window = 2, 5 years
# =============================================================================
construct_chronic <- function(df, threshold = 10, k = 3) {
  df %>%
    group_by(iso3c) %>%
    arrange(year) %>%
    mutate(
      hi_inf      = as.integer(!is.na(cpi) & cpi > threshold),
      # Count consecutive years above threshold
      run_id      = cumsum(hi_inf != lag(hi_inf, default = 0)),
      run_len     = ave(hi_inf, run_id, FUN = cumsum),
      chronic_inf = as.integer(hi_inf == 1 & run_len >= k)
    ) %>%
    ungroup() %>%
    select(-run_id, -run_len, -hi_inf)
}

# Primary
panel <- construct_chronic(panel, threshold = 10, k = 3)

# Robustness variants
panel <- panel %>%
  left_join(
    construct_chronic(panel %>% select(iso3c, year, cpi),
                      threshold = 7, k = 3) %>%
      rename(chronic_inf_7  = chronic_inf),
    by = c("iso3c", "year")
  ) %>%
  left_join(
    construct_chronic(panel %>% select(iso3c, year, cpi),
                      threshold = 15, k = 3) %>%
      rename(chronic_inf_15 = chronic_inf),
    by = c("iso3c", "year")
  )

# Descriptive check
cat("\nChronic inflation incidence (primary: CPI>10%, 3yr):\n")
panel %>%
  group_by(year) %>%
  summarise(
    n_countries  = n_distinct(iso3c[!is.na(chronic_inf)]),
    n_chronic    = sum(chronic_inf, na.rm = TRUE),
    pct_chronic  = round(100 * n_chronic / n_countries, 1)
  ) %>%
  filter(year %in% c(1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020)) %>%
  print()

# =============================================================================
# 7. INFLATION PERSISTENCE — AR(1) rolling window (20 years)
# Alternative dependent variable
# =============================================================================
panel <- panel %>%
  group_by(iso3c) %>%
  arrange(year) %>%
  mutate(
    inf_persist = slider::slide_dbl(
      cpi,
      .f = function(x) {
        x_clean <- x[!is.na(x)]
        if (length(x_clean) < 10) return(NA_real_)
        tryCatch(
          coef(lm(x_clean[-1] ~ x_clean[-length(x_clean)]))[2],
          error = function(e) NA_real_
        )
      },
      .before = 19, .after = 0, .complete = TRUE
    )
  ) %>%
  ungroup()

# =============================================================================
# 8. TRILEMMA CONSTRAINT TEST
# Following ACI (2013): MII + ERS + KAOPEN ≈ constant
# =============================================================================
cat("\nTrilemma constraint test (cross-section means):\n")
trilemma_constraint <- panel %>%
  filter(!is.na(MII), !is.na(ERS), !is.na(KAOPEN)) %>%
  group_by(iso3c) %>%
  summarise(
    MII_mean    = mean(MII, na.rm = TRUE),
    ERS_mean    = mean(ERS, na.rm = TRUE),
    KAOPEN_norm = mean((KAOPEN - min(KAOPEN, na.rm = TRUE)) /
                       (max(KAOPEN, na.rm = TRUE) - min(KAOPEN, na.rm = TRUE)),
                       na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(trilemma_sum = MII_mean + ERS_mean + KAOPEN_norm)

cat(sprintf("Trilemma sum: mean = %.3f, SD = %.3f (expect ~1.5-2.0 if binds)\n",
            mean(trilemma_constraint$trilemma_sum, na.rm = TRUE),
            sd(trilemma_constraint$trilemma_sum, na.rm = TRUE)))

# =============================================================================
# 9. FINAL PANEL — Save
# =============================================================================
# Filter to balanced-ish: require ≥15 years of CPI and trilemma data
panel_final <- panel %>%
  group_by(iso3c) %>%
  filter(
    sum(!is.na(cpi))   >= 15,
    sum(!is.na(MII))   >= 10
  ) %>%
  ungroup()

N_final <- n_distinct(panel_final$iso3c)
T_range <- range(panel_final$year)

cat(sprintf("\n✅ Final panel: N = %d countries, T = %d–%d\n",
            N_final, T_range[1], T_range[2]))

OUTFILE <- file.path(CLEAN_DIR,
           paste0("panel_chronic_inf_trilemma_", DATE_TAG, ".csv"))

write_csv(panel_final, OUTFILE)
cat(sprintf("✅ Saved: %s\n", OUTFILE))

# =============================================================================
# 10. SUMMARY TABLE — for Section 3 of manuscript
# =============================================================================
cat("\n--- DESCRIPTIVE STATISTICS (Table 1 draft) ---\n")
panel_final %>%
  select(cpi, chronic_inf, MII, ERS, KAOPEN,
         gdp_growth, trade_open, broad_money, fdi, fiscal_bal) %>%
  summarise(across(everything(),
    list(
      mean = ~round(mean(., na.rm = TRUE), 3),
      sd   = ~round(sd(., na.rm = TRUE), 3),
      min  = ~round(min(., na.rm = TRUE), 3),
      max  = ~round(max(., na.rm = TRUE), 3),
      n    = ~sum(!is.na(.))
    ),
    .names = "{.col}__{.fn}"
  )) %>%
  pivot_longer(everything(),
               names_to  = c("variable", "stat"),
               names_sep = "__") %>%
  pivot_wider(names_from = stat, values_from = value) %>%
  print(n = 30)

cat("\n=== 01_data_assembly.R COMPLETE ===\n")
cat(sprintf("Output: %s\n", OUTFILE))
cat("Next: run 02_pretests.R\n")
