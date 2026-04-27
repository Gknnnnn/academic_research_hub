# =============================================================================
# Automation, Economic Complexity & Labor Share in Eurasian Economies
# Script 01: Data Download & Panel Assembly
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-24
# =============================================================================

# install.packages(c("pwt10", "ilostat", "WDI", "dplyr", "tidyr", "readr"))

library(WDI)
library(dplyr)
library(tidyr)
library(readr)

# -----------------------------------------------------------------------------
# 0. PATHS
# -----------------------------------------------------------------------------
data_dir <- here::here("data")
dir.create(data_dir, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. COUNTRY LIST — Eurasian Panel (N=14)
# -----------------------------------------------------------------------------
eurasian_iso <- c(
  "ARM", "AZE", "BLR", "GEO", "KAZ", "KGZ",
  "MDA", "MNG", "RUS", "TJK", "TKM", "TUR", "UKR", "UZB"
)

country_names <- c(
  "Armenia", "Azerbaijan", "Belarus", "Georgia",
  "Kazakhstan", "Kyrgyzstan", "Moldova", "Mongolia",
  "Russia", "Tajikistan", "Turkmenistan", "Türkiye",
  "Ukraine", "Uzbekistan"
)

years <- 1995:2022

# -----------------------------------------------------------------------------
# 2. LABOR SHARE — ILO ILOSTAT
# -----------------------------------------------------------------------------
# ilostat package: labor share = compensation of employees / GDP
# Indicator: LAP_2GDP_NOC_RT (Labour income share as a percent of GDP)

if (!requireNamespace("ilostat", quietly = TRUE)) install.packages("ilostat")
library(ilostat)

message("Downloading ILO labor share data...")
ilo_ls <- get_ilostat(
  id = "LAP_2GDP_NOC_RT",
  filters = list(
    ref_area = eurasian_iso,
    time = as.character(years)
  )
) |>
  filter(classif1 == "ECO_AGGREGATE_TOTAL") |>
  select(iso3c = ref_area, year = time, labor_share = obs_value) |>
  mutate(year = as.integer(year))

message("ILO: ", nrow(ilo_ls), " rows | Countries: ", n_distinct(ilo_ls$iso3c))
write_csv(ilo_ls, file.path(data_dir, "ilo_laborshare_eurasian_20260424.csv"))

# -----------------------------------------------------------------------------
# 3. PENN WORLD TABLES 10.01 — TFP, ICT Capital, Human Capital
# -----------------------------------------------------------------------------
if (!requireNamespace("pwt10", quietly = TRUE)) install.packages("pwt10")
library(pwt10)

data("pwt10.01")

pwt_eurasian <- pwt10.01 |>
  filter(isocode %in% eurasian_iso, year %in% years) |>
  select(
    iso3c   = isocode,
    year,
    tfp     = rtfpna,   # TFP at national prices (index, 2017=1)
    hc      = hc,       # Human capital index
    ck      = ck,       # Capital services (mil 2017 USD)
    emp     = emp,      # Employment (millions)
    labsh   = labsh,    # Labor share (PWT own measure — cross-check with ILO)
    rgdpna  = rgdpna    # Real GDP (mil 2017 USD)
  ) |>
  mutate(
    ln_tfp    = log(tfp),
    ln_hc     = log(hc),
    capital_intensity = log(ck / (emp * 1e6))  # log(capital per worker)
  )

message("PWT: ", nrow(pwt_eurasian), " rows")
write_csv(pwt_eurasian, file.path(data_dir, "pwt1001_eurasian_20260424.csv"))

# -----------------------------------------------------------------------------
# 4. ECONOMIC COMPLEXITY INDEX (ECI) — OEC Atlas
# -----------------------------------------------------------------------------
# Download: https://oec.world/en/resources/bulk-download
# File: OEC_ECI_country_year.csv (manual download needed — place in data/raw/)
# Columns: iso3c, year, eci

eci_path <- file.path(data_dir, "raw", "oec_eci_country_year.csv")

if (file.exists(eci_path)) {
  eci_raw <- read_csv(eci_path, show_col_types = FALSE)
  # Standardize column names (OEC format varies)
  if ("Country Code" %in% names(eci_raw)) {
    eci_raw <- eci_raw |> rename(iso3c = `Country Code`, year = Year, eci = ECI)
  }
  eci_eurasian <- eci_raw |>
    filter(iso3c %in% eurasian_iso, year %in% years) |>
    select(iso3c, year, eci)
  message("ECI: ", nrow(eci_eurasian), " rows")
  write_csv(eci_eurasian, file.path(data_dir, "eci_eurasian_20260424.csv"))
} else {
  message("⚠️  ECI file not found at: ", eci_path)
  message("    Download from: https://oec.world/en/resources/bulk-download")
  message("    Place as: data/raw/oec_eci_country_year.csv")
  # Create placeholder
  eci_eurasian <- tibble(iso3c = character(), year = integer(), eci = numeric())
}

# -----------------------------------------------------------------------------
# 5. WDI CONTROLS
# -----------------------------------------------------------------------------
wdi_indicators <- c(
  trade_open  = "NE.TRD.GNFS.ZS",    # Trade openness (% GDP)
  fdi         = "BX.KLT.DINV.WD.GD.ZS", # FDI inflows (% GDP)
  gdppc       = "NY.GDP.PCAP.KD",     # GDP per capita (2015 USD)
  industry_va = "NV.IND.TOTL.ZS",    # Industry value added (% GDP)
  services_va = "NV.SRV.TOTL.ZS",    # Services value added (% GDP)
  ict_import  = "TM.VAL.ICTG.ZS.UN", # ICT goods imports (% total goods imports)
  rnd_gdp     = "GB.XPD.RSDV.GD.ZS"  # R&D expenditure (% GDP)
)

message("Downloading WDI controls...")
wdi_raw <- WDI(
  country   = eurasian_iso,
  indicator = wdi_indicators,
  start     = min(years),
  end       = max(years),
  extra     = FALSE
)

wdi_eurasian <- wdi_raw |>
  rename(iso3c = iso2c) |>
  mutate(iso3c = countrycode::countrycode(iso3c, "iso2c", "iso3c")) |>
  filter(iso3c %in% eurasian_iso) |>
  select(iso3c, year, all_of(names(wdi_indicators))) |>
  mutate(
    ln_gdppc   = log(gdppc),
    ln_fdi     = log(pmax(fdi, 0.01))
  )

message("WDI: ", nrow(wdi_eurasian), " rows")
write_csv(wdi_eurasian, file.path(data_dir, "wdi_controls_eurasian_20260424.csv"))

# -----------------------------------------------------------------------------
# 6. MERGE — MASTER PANEL
# -----------------------------------------------------------------------------
message("Assembling master panel...")

# Base: all country-year combinations
base_panel <- expand.grid(
  iso3c = eurasian_iso,
  year  = years,
  stringsAsFactors = FALSE
) |> as_tibble()

panel_master <- base_panel |>
  left_join(ilo_ls,      by = c("iso3c", "year")) |>
  left_join(pwt_eurasian |> select(iso3c, year, tfp, ln_tfp, hc, ln_hc,
                                    capital_intensity, labsh, rgdpna),
            by = c("iso3c", "year")) |>
  left_join(eci_eurasian, by = c("iso3c", "year")) |>
  left_join(wdi_eurasian,  by = c("iso3c", "year")) |>
  mutate(
    country = countrycode::countrycode(iso3c, "iso3c", "country.name"),
    country = if_else(iso3c == "TUR", "Türkiye", country)
  ) |>
  arrange(iso3c, year)

# Coverage report
coverage <- panel_master |>
  summarise(across(
    c(labor_share, ln_tfp, eci, trade_open, ln_gdppc),
    ~ mean(!is.na(.)) * 100,
    .names = "{.col}_pct"
  ))

message("\n=== COVERAGE REPORT ===")
print(coverage)

message("\nPanel dimensions: ", nrow(panel_master), " obs | ",
        n_distinct(panel_master$iso3c), " countries | ",
        n_distinct(panel_master$year), " years")

# Save master panel
outfile <- file.path(data_dir, paste0("panel_automation_eurasian_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_csv(panel_master, outfile)
message("✅ Saved: ", outfile)

# -----------------------------------------------------------------------------
# 7. QUICK EDA — Missing data heatmap
# -----------------------------------------------------------------------------
library(ggplot2)

missing_map <- panel_master |>
  select(iso3c, year, labor_share, ln_tfp, eci, trade_open) |>
  pivot_longer(-c(iso3c, year), names_to = "variable", values_to = "value") |>
  mutate(missing = is.na(value))

p_missing <- ggplot(missing_map, aes(x = year, y = iso3c, fill = missing)) +
  geom_tile(color = "white") +
  facet_wrap(~variable, ncol = 2) +
  scale_fill_manual(values = c("FALSE" = "#2196F3", "TRUE" = "#EF5350"),
                    labels = c("Available", "Missing")) +
  labs(title = "Data Coverage — Eurasian Automation-LaborShare Panel",
       x = "Year", y = "Country", fill = "Status") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(data_dir, "fig_missing_heatmap.png"), p_missing,
       width = 10, height = 6, dpi = 300)
message("✅ Missing data heatmap saved.")

# =============================================================================
# NEXT: Run 02_csd_unitroot.R
# =============================================================================
