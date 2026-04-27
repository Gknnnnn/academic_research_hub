# =============================================================================
# IGI Global — Eurasian Energy & Geoeconomic Vulnerability
# Script 01: Data Download + EDA + Preliminary Panel Analysis
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-22
# =============================================================================

library(WDI)
library(dplyr)
library(tidyr)
library(ggplot2)
library(plm)
library(fixest)
library(lmtest)
library(sandwich)

# -----------------------------------------------------------------------------
# 1. COUNTRY LIST — Eurasian Panel (N=14)
# -----------------------------------------------------------------------------
eurasian_iso <- c(
  "ARM",  # Armenia
  "AZE",  # Azerbaijan
  "BLR",  # Belarus
  "GEO",  # Georgia
  "KAZ",  # Kazakhstan
  "KGZ",  # Kyrgyzstan
  "MDA",  # Moldova
  "MNG",  # Mongolia
  "RUS",  # Russia
  "TJK",  # Tajikistan
  "TKM",  # Turkmenistan
  "TUR",  # Türkiye
  "UKR",  # Ukraine
  "UZB"   # Uzbekistan
)

country_names <- c(
  "Armenia", "Azerbaijan", "Belarus", "Georgia",
  "Kazakhstan", "Kyrgyzstan", "Moldova", "Mongolia",
  "Russia", "Tajikistan", "Turkmenistan", "Türkiye",
  "Ukraine", "Uzbekistan"
)

# -----------------------------------------------------------------------------
# 2. WDI INDICATORS
# -----------------------------------------------------------------------------
indicators <- c(
  energy_dep   = "EG.IMP.CONS.ZS",    # Energy imports, net (% of energy use)
  ca_bal       = "BN.CAB.XOKA.GD.ZS", # Current account balance (% of GDP)
  gdppc        = "NY.GDP.PCAP.KD",     # GDP per capita (constant 2015 USD)
  trade        = "NE.TRD.GNFS.ZS",    # Trade openness (% of GDP)
  inflation    = "FP.CPI.TOTL.ZG",    # Inflation, CPI (%)
  exrate       = "PA.NUS.FCRF",        # Official exchange rate (LCU per USD)
  res_rents    = "NY.GDP.TOTL.RT.ZS", # Total natural resource rents (% GDP)
  fdi_in       = "BX.KLT.DINV.WD.GD.ZS" # FDI inflows (% of GDP)
  # GC.BAL.CASH.GD.ZS (fiscal balance) — WB API intermittently unavailable; use IMF WEO as backup
)

# -----------------------------------------------------------------------------
# 3. DOWNLOAD
# -----------------------------------------------------------------------------
cat("Downloading WDI data for Eurasian panel (N=14, T=2000-2022)...\n")

raw <- WDI(
  country   = eurasian_iso,
  indicator = indicators,
  start     = 2000,
  end       = 2022,
  extra     = TRUE
)

cat("Raw dimensions:", nrow(raw), "x", ncol(raw), "\n")

# -----------------------------------------------------------------------------
# 4. CLEAN
# -----------------------------------------------------------------------------
panel <- raw %>%
  filter(region != "Aggregates") %>%
  select(iso3c, country, year, any_of(names(indicators))) %>%
  arrange(iso3c, year) %>%
  group_by(iso3c) %>%
  mutate(
    ln_gdppc  = log(gdppc),
    # Exchange rate depreciation — explicit dplyr::lag to avoid plm::lag masking
    exrate_dep = (exrate - dplyr::lag(exrate, 1)) / dplyr::lag(exrate, 1) * 100,
    # Energy exporter dummy (net exporter = energy_dep < 0)
    exporter   = ifelse(energy_dep < 0, 1, 0)
  ) %>%
  ungroup()

cat("\nPanel dimensions after cleaning:", nrow(panel), "obs\n")
cat("Countries:", length(unique(panel$iso3c)), "\n")
cat("Years:", min(panel$year, na.rm=TRUE), "–", max(panel$year, na.rm=TRUE), "\n")

# -----------------------------------------------------------------------------
# 5. MISSING DATA SUMMARY
# -----------------------------------------------------------------------------
cat("\n--- Missing Data Summary ---\n")
miss_summary <- panel %>%
  summarise(across(any_of(c("energy_dep", "ca_bal", "gdppc", "trade", "inflation", "exrate", "res_rents")),
                   ~ sum(is.na(.)) / n() * 100)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "pct_missing")
print(miss_summary)

# -----------------------------------------------------------------------------
# 6. DESCRIPTIVE STATISTICS
# -----------------------------------------------------------------------------
cat("\n--- Descriptive Statistics ---\n")
desc_stats <- panel %>%
  select(any_of(c("energy_dep", "ca_bal", "trade", "inflation", "res_rents"))) %>%
  summarise(across(everything(), list(
    mean = ~mean(., na.rm=TRUE),
    sd   = ~sd(., na.rm=TRUE),
    min  = ~min(., na.rm=TRUE),
    max  = ~max(., na.rm=TRUE),
    n    = ~sum(!is.na(.))
  )))
print(t(desc_stats))

# -----------------------------------------------------------------------------
# 7. CORRELATION: Energy Dependency → CA Balance
# -----------------------------------------------------------------------------
cat("\n--- Correlation Matrix (key variables) ---\n")
cor_vars <- panel %>%
  select(any_of(c("energy_dep", "ca_bal", "exrate_dep", "ln_gdppc", "trade", "res_rents"))) %>%
  filter(complete.cases(.))
print(round(cor(cor_vars), 3))

# -----------------------------------------------------------------------------
# 8. PRELIMINARY FE REGRESSION (Pooled + FE) — Inductive Phase
# -----------------------------------------------------------------------------
panel_pdata <- pdata.frame(panel, index = c("iso3c", "year"))

# M1: Pooled OLS
m1_pooled <- lm(ca_bal ~ energy_dep + ln_gdppc + trade + inflation,
                data = panel, na.action = na.omit)
cat("\n--- Model 1: Pooled OLS — energy_dep → CA balance ---\n")
print(summary(m1_pooled))

# M2: Two-way FE (country + year)
m2_fe <- feols(ca_bal ~ energy_dep + ln_gdppc + trade + inflation | iso3c + year,
               data = panel, vcov = "twoway")
cat("\n--- Model 2: Two-Way FE — energy_dep → CA balance ---\n")
print(summary(m2_fe))

# M3: FE — energy_dep → resource rents (as fiscal capacity proxy)
m3_rents <- feols(res_rents ~ energy_dep + ln_gdppc + trade | iso3c + year,
                  data = panel, vcov = "twoway")
cat("\n--- Model 3: Two-Way FE — energy_dep → Resource Rents (fiscal capacity proxy) ---\n")
print(summary(m3_rents))

# M4: Heterogeneous effect — importers only
panel_imp <- panel %>% filter(energy_dep > 0)
m4_imp <- tryCatch(
  feols(ca_bal ~ energy_dep + ln_gdppc + trade + inflation | iso3c + year,
        data = panel_imp, vcov = "twoway"),
  error = function(e) { cat("M4 failed:", e$message, "\n"); NULL }
)
if (!is.null(m4_imp)) {
  cat("\n--- Model 4: FE — IMPORTERS only (energy_dep > 0) → CA balance ---\n")
  print(summary(m4_imp))
}

# -----------------------------------------------------------------------------
# 9. COUNTRY-LEVEL AVERAGES (for table in manuscript)
# -----------------------------------------------------------------------------
country_means <- panel %>%
  group_by(iso3c, country) %>%
  summarise(
    energy_dep_mean = round(mean(energy_dep, na.rm=TRUE), 1),
    ca_bal_mean     = round(mean(ca_bal, na.rm=TRUE), 2),
    res_rents_mean  = round(mean(res_rents, na.rm=TRUE), 1),
    exporter        = ifelse(mean(energy_dep, na.rm=TRUE) < 0, "Exporter", "Importer"),
    .groups = "drop"
  ) %>%
  arrange(energy_dep_mean)

cat("\n--- Country-Level Summary ---\n")
print(country_means)

# -----------------------------------------------------------------------------
# 10. SAVE DATA
# -----------------------------------------------------------------------------
output_dir <- "../02-Data/"
write.csv(panel, paste0(output_dir, "panel_eurasian_energy_", format(Sys.Date(), "%Y%m%d"), ".csv"),
          row.names = FALSE)
cat("\nData saved to 02-Data/panel_eurasian_energy_", format(Sys.Date(), "%Y%m%d"), ".csv\n")

cat("\n=== EDA COMPLETE ===\n")
