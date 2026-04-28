# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — IMF WEO Fiscal Balance Supplement
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-28
# Purpose: Fetch GGXCNL_NGDP (general govt net lending/borrowing % GDP) from
#          IMF WEO via the IMF Data API (free, no key required)
#          Merge with panel_chronic_inf_trilemma_merged.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(httr); library(jsonlite)
})

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

PANEL_PATH  <- "../02-Data/clean/panel_chronic_inf_trilemma_merged.csv"
OUT_PATH    <- "../02-Data/raw/imf_weo_fiscal_20260428.csv"
MERGED_PATH <- "../02-Data/clean/panel_chronic_inf_trilemma_v2.csv"

# =============================================================================
# STEP 1 — Fetch IMF WEO GGXCNL_NGDP via imfr / direct API
# =============================================================================
cat("Fetching IMF WEO fiscal balance (GGXCNL_NGDP)...\n")

# IMF DataMapper API — free, no authentication
# Base: https://www.imf.org/external/datamapper/api/v1/
# Indicator: GGXCNL_NGDP (General Govt Net Lending/Borrowing, % GDP)

imf_url <- "https://www.imf.org/external/datamapper/api/v1/GGXCNL_NGDP"

resp <- tryCatch(
  GET(imf_url, timeout(60)),
  error = function(e) { cat(sprintf("HTTP error: %s\n", e$message)); NULL }
)

if (is.null(resp) || status_code(resp) != 200) {
  cat(sprintf("IMF API failed (status %s). Trying WEO bulk download method...\n",
              if (!is.null(resp)) status_code(resp) else "NA"))

  # Fallback: IMF WEO April 2024 bulk CSV
  weo_url  <- "https://www.imf.org/external/pubs/ft/weo/2024/01/weodata/WEOApr2024all.ashx"
  weo_resp <- tryCatch(
    GET(weo_url, timeout(120), write_disk(tempfile(fileext=".csv"))),
    error = function(e) NULL
  )
  if (!is.null(weo_resp) && status_code(weo_resp) == 200) {
    cat("WEO bulk download succeeded.\n")
    weo_raw <- read_tsv(weo_resp$content, col_types=cols(.default="c"))
    cat(sprintf("WEO dimensions: %d rows × %d cols\n", nrow(weo_raw), ncol(weo_raw)))
  } else {
    cat("⚠️  Both IMF API and WEO bulk download failed. Fiscal balance not added.\n")
    cat("Manual download: https://www.imf.org/en/Publications/WEO/weo-database/2024/April\n")
    quit(save="no")
  }
} else {
  cat("IMF DataMapper API succeeded.\n")
  imf_json <- fromJSON(rawToChar(resp$content))

  # Structure: imf_json$values$GGXCNL_NGDP is a list of country code → named numeric vector
  fiscal_list <- imf_json$values$GGXCNL_NGDP

  fiscal_long <- bind_rows(
    lapply(names(fiscal_list), function(cc) {
      v <- fiscal_list[[cc]]
      if (length(v) == 0) return(NULL)
      tibble(
        iso3c        = cc,
        year         = as.integer(names(v)),
        fiscal_bal   = as.numeric(v)
      )
    })
  )

  cat(sprintf("Fiscal balance series: %d obs, %d countries, years %d–%d\n",
              nrow(fiscal_long),
              length(unique(fiscal_long$iso3c)),
              min(fiscal_long$year, na.rm=TRUE),
              max(fiscal_long$year, na.rm=TRUE)))

  write_csv(fiscal_long, OUT_PATH)
  cat(sprintf("✅ Saved raw: %s\n", OUT_PATH))
}

# =============================================================================
# STEP 2 — Merge with panel
# =============================================================================
panel <- read_csv(PANEL_PATH, show_col_types=FALSE)
cat(sprintf("Panel loaded: %d obs, %d countries\n", nrow(panel), length(unique(panel$iso3c))))

if (exists("fiscal_long")) {
  # Filter to panel years
  fiscal_panel <- fiscal_long |>
    filter(year >= 1985, year <= 2020) |>
    rename(fiscal_bal_weo = fiscal_bal)

  panel_v2 <- panel |>
    left_join(fiscal_panel, by=c("iso3c","year"))

  n_fiscal <- sum(!is.na(panel_v2$fiscal_bal_weo))
  cat(sprintf("Fiscal balance matched: %d / %d obs (%.1f%%)\n",
              n_fiscal, nrow(panel_v2),
              100 * n_fiscal / nrow(panel_v2)))

  write_csv(panel_v2, MERGED_PATH)
  cat(sprintf("✅ Saved panel v2: %s\n", MERGED_PATH))

  # Cross-check: compare 5 spot values against known anchors
  cat("\n--- CROSS-CHECK (fiscal_bal_weo vs WDI) ---\n")
  spots <- panel_v2 |>
    filter(iso3c %in% c("TUR","BRA","KEN","MEX","IND"),
           year %in% c(2000, 2005, 2010, 2015)) |>
    select(iso3c, year, fiscal_bal_weo) |>
    arrange(iso3c, year)
  print(spots, n=20)
}

cat("\n=== 04_imf_weo_fiscal.R COMPLETE ===\n")
