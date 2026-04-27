# ============================================================
# CIVETS Unemployment Project — Data Fetch
# Script: 01_fetch_wdi_wgi_20260426.R
# Author: MGO
# Date: 2026-04-26
# Sources: World Bank WDI + WGI (all free APIs, no key required)
# ============================================================

library(tidyverse)
library(wbstats)   # WB API wrapper

# ── Countries ──────────────────────────────────────────────
civets <- c("COL", "IDN", "VNM", "EGY", "TUR", "ZAF")
years  <- 2000:2023

# ── WDI Indicators ─────────────────────────────────────────
wdi_indicators <- c(
  unemp        = "SL.UEM.TOTL.ZS",   # Unemployment, total (% labour force)
  gdp_growth   = "NY.GDP.MKTP.KD.ZG",# GDP growth (annual %)
  gdp_pc       = "NY.GDP.PCAP.KD",   # GDP per capita (const. 2015 USD)
  inflation    = "FP.CPI.TOTL.ZG",   # Inflation, CPI (annual %)
  trade        = "NE.TRD.GNFS.ZS",   # Trade openness (% of GDP)
  fdi          = "BX.KLT.DINV.WD.GD.ZS", # FDI net inflows (% of GDP)
  gov_exp      = "GC.XPN.TOTL.GD.ZS",# Gov. expenditure (% of GDP)
  internet     = "IT.NET.USER.ZS",   # Internet users (% of population)
  lfp          = "SL.TLF.ACTI.ZS",   # Labour force participation (%)
  pop          = "SP.POP.TOTL"        # Population (for weighting)
)

cat("Fetching WDI data...\n")
wdi_raw <- wb_data(
  indicator  = wdi_indicators,
  country    = civets,
  start_date = min(years),
  end_date   = max(years),
  return_wide = TRUE
)

# Clean
wdi_clean <- wdi_raw %>%
  select(iso3c, country, date, all_of(names(wdi_indicators))) %>%
  rename(year = date) %>%
  arrange(iso3c, year)

cat(sprintf("WDI: %d rows × %d cols\n", nrow(wdi_clean), ncol(wdi_clean)))
cat("Countries:", paste(unique(wdi_clean$iso3c), collapse = ", "), "\n")
cat("Years: ", min(wdi_clean$year), "–", max(wdi_clean$year), "\n")

# ── WGI Indicators ─────────────────────────────────────────
wgi_indicators <- c(
  goveff   = "GE.EST",   # Government Effectiveness
  rulelaw  = "RL.EST",   # Rule of Law
  corrupt  = "CC.EST",   # Control of Corruption
  polstab  = "PV.EST",   # Political Stability / No Violence
  voice    = "VA.EST"    # Voice and Accountability
)

cat("Fetching WGI data...\n")
wgi_raw <- wb_data(
  indicator  = wgi_indicators,
  country    = civets,
  start_date = 1996,
  end_date   = 2023,
  return_wide = TRUE
)

wgi_clean <- wgi_raw %>%
  select(iso3c, country, date, all_of(names(wgi_indicators))) %>%
  rename(year = date) %>%
  arrange(iso3c, year)

cat(sprintf("WGI: %d rows × %d cols\n", nrow(wgi_clean), ncol(wgi_clean)))

# ── Merge ───────────────────────────────────────────────────
panel <- wdi_clean %>%
  left_join(wgi_clean %>% select(-country), by = c("iso3c", "year")) %>%
  filter(year >= 2000) %>%
  arrange(iso3c, year)

cat(sprintf("Merged panel: %d rows × %d cols\n", nrow(panel), ncol(panel)))

# ── Save ────────────────────────────────────────────────────
out_dir <- here::here("01-Data", "raw")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

readr::write_csv(wdi_clean, file.path(out_dir, "civets_wdi_raw_20260426.csv"))
readr::write_csv(wgi_clean, file.path(out_dir, "civets_wgi_raw_20260426.csv"))
readr::write_csv(panel,     file.path(out_dir, "civets_panel_merged_20260426.csv"))

cat("✅ Saved:\n")
cat("  → civets_wdi_raw_20260426.csv\n")
cat("  → civets_wgi_raw_20260426.csv\n")
cat("  → civets_panel_merged_20260426.csv\n")

# ── Missing value audit ─────────────────────────────────────
cat("\n── Missing value audit ──\n")
panel %>%
  select(-iso3c, -country, -year) %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  mutate(pct_missing = round(n_missing / nrow(panel) * 100, 1)) %>%
  arrange(desc(n_missing)) %>%
  print(n = 30)

# ── Cross-check: unemployment spot values ──────────────────
cat("\n── Unemployment spot check (latest available) ──\n")
panel %>%
  group_by(iso3c) %>%
  filter(!is.na(unemp)) %>%
  slice_max(year) %>%
  select(iso3c, year, unemp) %>%
  print()
