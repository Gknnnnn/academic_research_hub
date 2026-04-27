# ============================================================
# 01_data_download.R
# LCF Turkey Bootstrap ARDL — Data Assembly
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Data sources:
#   1. World Bank WDI: GDP per capita, renewable energy, trade, FDI
#   2. Global Footprint Network (GFN): biocapacity, ecological footprint → LCF
# ============================================================

library(WDI)
library(tidyverse)
library(readr)

# ============================================================
# 1. WORLD BANK WDI DATA
# ============================================================

wb_indicators <- c(
  gdp_pc      = "NY.GDP.PCAP.KD",    # GDP per capita (const. 2015 USD)
  ren_share   = "EG.FEC.RNEW.ZS",    # Renewable energy (% total final energy)
  trade       = "NE.TRD.GNFS.ZS",    # Trade openness (% GDP)
  fdi         = "BX.KLT.DINV.WD.GD.ZS" # FDI net inflow (% GDP)
)

cat("Downloading World Bank WDI data for Türkiye...\n")

wb_raw <- WDI(
  country   = "TR",
  indicator = wb_indicators,
  start     = 1960,
  end       = 2023,
  extra     = FALSE
)

# Clean and rename
wb_clean <- wb_raw |>
  select(year, gdp_pc, ren_share, trade, fdi) |>
  arrange(year) |>
  filter(!is.na(gdp_pc))  # keep rows with at least GDP

cat("WDI rows downloaded:", nrow(wb_clean), "\n")
cat("WDI year range:", range(wb_clean$year, na.rm = TRUE), "\n")
cat("NA summary:\n")
print(colSums(is.na(wb_clean)))

# Save raw WB data
write_csv(wb_clean, paste0("data/raw/wb_turkey_", format(Sys.Date(), "%Y%m%d"), ".csv"))
cat("✅ WB data saved: data/raw/wb_turkey_", format(Sys.Date(), "%Y%m%d"), ".csv\n")

# ============================================================
# 2. GLOBAL FOOTPRINT NETWORK (GFN) — LCF DATA
# ============================================================
# GFN provides open data at: data.footprintnetwork.org
# Direct API: https://api.footprintnetwork.org/v1/data/TR/all/EFCpc
# No API key needed for basic country data
# Variables needed:
#   - EFCpc: Ecological Footprint of Consumption (gha per capita)
#   - BCpc:  Biocapacity (gha per capita)
#   - LCF = BCpc / EFCpc
# ============================================================

cat("\nDownloading GFN data for Türkiye...\n")

# GFN open data API endpoints (no auth required for public data)
gfn_ef_url  <- "https://api.footprintnetwork.org/v1/data/TR/all/EFCpc"
gfn_bc_url  <- "https://api.footprintnetwork.org/v1/data/TR/all/BCpc"

tryCatch({
  gfn_ef_raw <- jsonlite::fromJSON(gfn_ef_url)
  gfn_bc_raw <- jsonlite::fromJSON(gfn_bc_url)

  gfn_ef <- as_tibble(gfn_ef_raw) |>
    select(year, value) |>
    rename(ef_pc = value) |>
    mutate(year = as.integer(year), ef_pc = as.numeric(ef_pc))

  gfn_bc <- as_tibble(gfn_bc_raw) |>
    select(year, value) |>
    rename(bc_pc = value) |>
    mutate(year = as.integer(year), bc_pc = as.numeric(bc_pc))

  gfn_clean <- inner_join(gfn_ef, gfn_bc, by = "year") |>
    arrange(year) |>
    mutate(lcf = bc_pc / ef_pc)  # Load Capacity Factor = BC / EF

  cat("GFN rows:", nrow(gfn_clean), "\n")
  cat("GFN year range:", range(gfn_clean$year, na.rm = TRUE), "\n")
  cat("LCF range:", round(range(gfn_clean$lcf, na.rm = TRUE), 3), "\n")

  write_csv(gfn_clean, paste0("data/raw/gfn_turkey_lcf_", format(Sys.Date(), "%Y%m%d"), ".csv"))
  cat("✅ GFN data saved\n")

}, error = function(e) {
  cat("⚠️ GFN API failed:", conditionMessage(e), "\n")
  cat("Manual download instructions:\n")
  cat("  1. Go to: https://data.footprintnetwork.org\n")
  cat("  2. Download Turkey country data (Biocapacity + EF per capita)\n")
  cat("  3. Save as: data/raw/gfn_turkey_manual_YYYYMMDD.csv\n")
  cat("  4. Columns needed: year, ef_pc, bc_pc\n")
  cat("  Then re-run this script after manual download.\n")
})

# ============================================================
# 3. MERGE AND BUILD PANEL DATASET
# ============================================================

cat("\nMerging datasets...\n")

# Check if GFN data loaded
if (exists("gfn_clean")) {
  panel <- wb_clean |>
    inner_join(gfn_clean, by = "year") |>
    arrange(year) |>
    mutate(
      # Log transforms
      lnLCF   = log(lcf),
      lnGDP   = log(gdp_pc),
      lnGDP2  = log(gdp_pc)^2,
      lnREN   = log(ren_share + 0.001),  # +0.001 to avoid log(0) in early years
      lnTrade = log(trade),
      # FDI can be negative — use level or abs() check
      lnFDI   = ifelse(fdi > 0, log(fdi), NA_real_)
    ) |>
    filter(!is.na(lnLCF), !is.na(lnGDP))

  cat("Final panel rows:", nrow(panel), "\n")
  cat("Year range:", range(panel$year), "\n")
  cat("NA summary (log variables):\n")
  print(colSums(is.na(panel |> select(starts_with("ln")))))

  # Save merged panel with date stamp
  write_csv(panel, paste0("data/turkey_lcf_panel_", format(Sys.Date(), "%Y%m%d"), ".csv"))
  cat("✅ Panel saved: data/turkey_lcf_panel_", format(Sys.Date(), "%Y%m%d"), ".csv\n")

  # Quick diagnostic plot
  cat("\n--- CROSS-CHECK: LCF trend ---\n")
  panel |>
    select(year, lcf, lnLCF) |>
    slice_head(n = 10) |>
    print()
  cat("...\n")
  panel |>
    select(year, lcf, lnLCF) |>
    slice_tail(n = 10) |>
    print()

} else {
  cat("⚠️ GFN data not available — panel merge skipped. Download GFN manually and re-run.\n")
}

cat("\n=== 01_data_download.R COMPLETE ===\n")
