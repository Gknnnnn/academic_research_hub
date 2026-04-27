# =============================================================================
# GPR & Export Diversification in Eurasian Economies
# Script 02: Panel Assembly — HHI + GPR + WUI + WDI Controls
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Target: International Economics (SSCI Q2) / Energy Economics (SSCI Q1)
# Date: 2026-04-24
# =============================================================================
#
# DV:  HHI_dest — Herfindahl-Hirschman Index of export destination concentration
#                  (from BACI HS92, year-by-year computation in 01_baci_hhi.py)
# IVs: GPR       — Geopolitical Risk Index (Caldara-Iacoviello 2022)
#      WUI       — World Uncertainty Index (Ahir et al. 2022) [manual download]
#      ln_gdppc  — log GDP per capita (WDI)
#      trade_open — trade openness % GDP (WDI)
#      fdi        — FDI net inflows % GDP (WDI)
#      res_rents  — resource rents % GDP (WDI)
#      inflation  — CPI % change (WDI)
# =============================================================================

pkgs <- c("dplyr","readr","tidyr","plm","wbstats","ggplot2","scales")
for (p in pkgs) if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos="https://cloud.r-project.org")

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(plm)
  library(wbstats); library(ggplot2); library(scales)
})

DATA_DIR <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-GPR-Export-Diversification-Eurasian/data"
TODAY    <- format(Sys.Date(), "%Y%m%d")

EURASIAN_ISO3 <- c("ARM","AZE","BLR","GEO","KAZ","KGZ","MDA","MNG",
                   "RUS","TJK","TKM","TUR","UKR","UZB")

# =============================================================================
# 1. LOAD HHI (from BACI computation — script 01_baci_hhi.py)
# =============================================================================
cat("=== Loading BACI HHI ===\n")

# Check if HHI file exists
hhi_files <- list.files(DATA_DIR, pattern="baci_hhi_eurasian.*\\.csv", full.names=TRUE)

if (length(hhi_files) > 0) {
  hhi_raw <- read_csv(hhi_files[length(hhi_files)], show_col_types=FALSE)
  cat("HHI raw columns:", paste(names(hhi_raw), collapse=", "), "\n")
  # Harmonize column names (BACI script uses total_exports + n_partners)
  if ("total_exports" %in% names(hhi_raw))
    hhi_raw <- rename(hhi_raw, total_exports_usd = total_exports)
  if ("n_partners" %in% names(hhi_raw))
    hhi_raw <- rename(hhi_raw, n_destinations = n_partners)
  hhi <- hhi_raw |>
    select(iso3c, year, hhi_dest,
           any_of(c("total_exports_usd","n_destinations"))) |>
    arrange(iso3c, year)
  cat("HHI loaded:", nrow(hhi), "rows\n")
  cat("Coverage:", range(hhi$year), "\n")
  cat("Countries:", length(unique(hhi$iso3c)), "\n")
} else {
  cat("⚠️  BACI HHI file not found — BACI computation likely still running.\n")
  cat("    Expected: data/baci_hhi_eurasian_20260424.csv\n")
  cat("    Creating placeholder for now...\n")
  hhi <- expand.grid(iso3c=EURASIAN_ISO3, year=1995:2022) |>
    as_tibble() |>
    mutate(hhi_dest=NA_real_, total_exports_usd=NA_real_, n_destinations=NA_integer_)
}

# =============================================================================
# 2. LOAD GPR INDEX (Caldara-Iacoviello 2022)
# =============================================================================
cat("\n=== Loading GPR Index ===\n")

gpr_files <- list.files(DATA_DIR, pattern="gpr_annual.*\\.csv", full.names=TRUE)
if (length(gpr_files) == 0) {
  # Try shared data folder
  gpr_files <- list.files(
    "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/400-Data/multipolar_basel/clean",
    pattern="gpr_annual", full.names=TRUE
  )
}

if (length(gpr_files) > 0) {
  gpr_raw <- read_csv(gpr_files[length(gpr_files)], show_col_types=FALSE)
  cat("GPR file columns:", names(gpr_raw), "\n")
  cat("GPR rows:", nrow(gpr_raw), "| years:", range(gpr_raw$year), "\n")

  # Global GPR + country-specific for Eurasian subset
  gpr <- gpr_raw |>
    select(year, GPR, any_of(c("GPRC_RUS","GPRC_TUR","GPRC_CHN","GPRC_USA","GPRC_IND"))) |>
    filter(year >= 1995, year <= 2022) |>
    mutate(ln_gpr = log(pmax(GPR, 1)))

  cat("GPR loaded:", nrow(gpr), "rows\n")
} else {
  cat("⚠️  GPR file not found — creating placeholder\n")
  gpr <- tibble(year=1995:2022, GPR=NA_real_, ln_gpr=NA_real_)
}

# =============================================================================
# 3. LOAD WUI (manual download required)
# =============================================================================
cat("\n=== Loading WUI ===\n")

wui_path <- file.path(DATA_DIR, "raw/WUI_Data_Public.xlsx")
wui_csv  <- file.path(DATA_DIR, "raw/wui_country_annual.csv")

if (file.exists(wui_csv)) {
  wui_raw <- read_csv(wui_csv, show_col_types=FALSE)
  cat("WUI loaded from CSV:", nrow(wui_raw), "rows\n")
} else if (file.exists(wui_path)) {
  library(readxl)
  wui_raw <- read_excel(wui_path) |>
    pivot_longer(cols=-c(1), names_to="year", values_to="WUI") |>
    rename(country=1) |>
    mutate(year=as.integer(year)) |>
    filter(!is.na(WUI))
  cat("WUI loaded from XLSX\n")
} else {
  cat("⚠️  WUI not found.\n")
  cat("    Manual download: https://worlduncertaintyindex.com/data/\n")
  cat("    → 'WUI Data' → Country-Level annual data\n")
  cat("    Save as: data/raw/wui_country_annual.csv (cols: iso2c, year, WUI)\n")
  wui_raw <- NULL
}

# =============================================================================
# 4. DOWNLOAD WDI CONTROLS
# =============================================================================
cat("\n=== Downloading WDI Controls ===\n")

wdi_indicators <- c(
  "NY.GDP.PCAP.PP.KD",  # GDP per capita PPP 2017 USD
  "NE.TRD.GNFS.ZS",    # Trade % GDP
  "BX.KLT.DINV.WD.GD.ZS", # FDI net inflows % GDP
  "NY.GDP.TOTL.RT.ZS",  # Total natural resource rents % GDP
  "FP.CPI.TOTL.ZG",    # Inflation CPI %
  "EG.USE.PCAP.KG.OE"  # Energy use per capita (kg oil equiv)
)

cat("Fetching WDI for", length(EURASIAN_ISO3), "Eurasian countries (1995-2022)...\n")

tryCatch({
  wdi_raw <- wb_data(
    indicator = wdi_indicators,
    country   = EURASIAN_ISO3,
    start_date= 1995,
    end_date  = 2022,
    return_wide = TRUE
  ) |>
    rename(
      iso3c      = iso3c,
      year       = date,
      gdppc_ppp  = NY.GDP.PCAP.PP.KD,
      trade_open = NE.TRD.GNFS.ZS,
      fdi        = BX.KLT.DINV.WD.GD.ZS,
      res_rents  = NY.GDP.TOTL.RT.ZS,
      inflation  = FP.CPI.TOTL.ZG,
      energy_use = EG.USE.PCAP.KG.OE
    ) |>
    mutate(ln_gdppc = log(pmax(gdppc_ppp, 1))) |>
    select(iso3c, year, ln_gdppc, trade_open, fdi, res_rents, inflation, energy_use) |>
    arrange(iso3c, year)

  cat("WDI downloaded:", nrow(wdi_raw), "rows | coverage:\n")
  print(sapply(wdi_raw, function(x) round(mean(!is.na(x))*100,1)))
  write_csv(wdi_raw, file.path(DATA_DIR, paste0("wdi_controls_gpr_",TODAY,".csv")))

}, error=function(e) {
  cat("WDI download error:", e$message, "\n")
  cat("Falling back to previously downloaded WDI from Automation project...\n")
  wdi_fallback <- file.path(
    "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma",
    "200-Manuscripts/210-Active/2026-Automation-LaborShare-Eurasian/data",
    "wdi_controls_eurasian_20260424.csv"
  )
  if (file.exists(wdi_fallback)) {
    wdi_raw <<- read_csv(wdi_fallback, show_col_types=FALSE) |>
      filter(iso3c %in% EURASIAN_ISO3)
    cat("WDI fallback loaded:", nrow(wdi_raw), "rows\n")
  } else {
    wdi_raw <<- NULL
  }
})

# =============================================================================
# 5. MERGE MASTER PANEL
# =============================================================================
cat("\n=== Building master panel ===\n")

# Base: HHI panel
panel_base <- expand.grid(iso3c=EURASIAN_ISO3, year=1995:2022) |>
  as_tibble()

master <- panel_base |>
  left_join(hhi,     by=c("iso3c","year")) |>
  left_join(gpr |> select(year, GPR, ln_gpr), by="year")

if (!is.null(wdi_raw)) {
  master <- master |> left_join(wdi_raw, by=c("iso3c","year"))
}

if (!is.null(wui_raw)) {
  # WUI may need ISO2 → ISO3 mapping
  # Check column names
  if ("iso2c" %in% names(wui_raw)) {
    wui_map <- tibble(
      iso2c = c("AM","AZ","BY","GE","KZ","KG","MD","MN","RU","TJ","TM","TR","UA","UZ"),
      iso3c = EURASIAN_ISO3
    )
    wui_eu <- wui_raw |> inner_join(wui_map, by="iso2c") |>
      select(iso3c, year, WUI) |> filter(!is.na(WUI))
    master <- master |> left_join(wui_eu, by=c("iso3c","year"))
  }
} else {
  master$WUI <- NA_real_
}

master <- master |>
  arrange(iso3c, year) |>
  mutate(
    ln_hhi   = log(pmax(hhi_dest, 0.001)),
    ln_gpr   = log(pmax(GPR, 1)),
    # Partial sums for NARDL
    d_gpr    = c(NA, diff(GPR)),
    pos_gpr  = NA_real_,  # will fill per country
    neg_gpr  = NA_real_
  )

# Compute partial sums by country
master <- master |>
  group_by(iso3c) |>
  arrange(year) |>
  mutate(
    d_gpr_local = c(NA, diff(GPR)),
    pos_gpr = cumsum(ifelse(!is.na(d_gpr_local) & d_gpr_local > 0, d_gpr_local, 0)),
    neg_gpr = cumsum(ifelse(!is.na(d_gpr_local) & d_gpr_local < 0, d_gpr_local, 0))
  ) |>
  ungroup()

cat("Master panel: N =", length(unique(master$iso3c)), "countries,",
    "obs =", nrow(master), "\n")
cat("Coverage:\n")
print(sapply(master |> select(-iso3c,-year), function(x) round(mean(!is.na(x))*100,1)))

write_csv(master, file.path(DATA_DIR, paste0("panel_gpr_hhi_",TODAY,".csv")))
cat("\nMaster panel saved:", paste0("panel_gpr_hhi_",TODAY,".csv"), "\n")

# =============================================================================
# 6. DESCRIPTIVE — HHI by Country
# =============================================================================
cat("\n=== HHI Descriptive Statistics by Country ===\n")

hhi_desc <- master |>
  filter(!is.na(hhi_dest)) |>
  group_by(iso3c) |>
  summarise(
    n    = n(),
    mean_hhi = round(mean(hhi_dest, na.rm=TRUE),4),
    sd_hhi   = round(sd(hhi_dest, na.rm=TRUE),4),
    min_hhi  = round(min(hhi_dest, na.rm=TRUE),4),
    max_hhi  = round(max(hhi_dest, na.rm=TRUE),4),
    .groups="drop"
  )
print(hhi_desc)
write_csv(hhi_desc, file.path(DATA_DIR, paste0("desc_hhi_by_country_",TODAY,".csv")))

cat("\n✅ Script 02 complete.\n")
cat("Next: scripts/03_nardl_panel.R (NARDL/PNARDL estimation)\n")
cat("⚠️  Still needed: WUI (manual) + BACI HHI (background job)\n")
