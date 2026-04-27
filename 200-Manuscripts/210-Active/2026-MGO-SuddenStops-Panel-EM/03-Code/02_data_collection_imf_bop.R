# =============================================================================
# Data Collection: Capital Flows Panel — Working Endpoints (verified 2026-04-28)
# Paper: Global Uncertainty, Domestic Credit, and Sudden Stops
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# =============================================================================
# API STATUS (tested 2026-04-28):
#   FRED key API      ✅  api.stlouisfed.org — key in .env
#   FRED CSV (no key) ✅  fred.stlouisfed.org/graph/fredgraph.csv
#   IMF DataMapper    ✅  imf.org/external/datamapper/api/v1/  (annual)
#   World Bank WDI    ✅  api.worldbank.org/v2/  (annual)
#   IMF BOP SDMX      ⚠️  sdmxcentral.imf.org — returns XML, not JSON
#                         → BOP quarterly gross flows: MANUAL DOWNLOAD required
#                         → URL: https://data.imf.org/?sk=7A51304B-6426-40C0-83DD-CA473CA1FD52
# =============================================================================

library(httr)
library(jsonlite)
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)

# FRED API key (from .env)
FRED_KEY <- Sys.getenv("FRED_API_KEY",
  unset = readLines("~/Documents/Playground/research_ops_ui_v1_deploy/.env") |>
    grep("FRED_API_KEY", x = _, value = TRUE) |>
    sub(".*=", "", x = _) |>
    trimws()
)

# =============================================================================
# SECTION 1: GLOBAL PUSH FACTORS (FRED — QUARTERLY, EXECUTABLE NOW)
# =============================================================================

fetch_fred_quarterly <- function(series_id, start = "1990-01-01",
                                  agg = "avg", label = series_id) {
  url <- sprintf(
    paste0("https://api.stlouisfed.org/fred/series/observations",
           "?series_id=%s&observation_start=%s&frequency=q",
           "&aggregation_method=%s&api_key=%s&file_type=json"),
    series_id, start, agg, FRED_KEY
  )
  tryCatch({
    resp <- GET(url, timeout(20))
    if (status_code(resp) != 200) stop("HTTP ", status_code(resp))
    obs  <- fromJSON(content(resp, "text", encoding = "UTF-8"))$observations
    data.frame(
      date  = as.Date(obs$date),
      value = as.numeric(obs$value),
      var   = label,
      stringsAsFactors = FALSE
    ) |> filter(!is.na(value))
  }, error = function(e) {
    message("FRED error (", series_id, "): ", e$message); NULL
  })
}

download_push_factors <- function(outdir = "02-Data/raw/") {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  message("Downloading global push factors from FRED...")

  series <- list(
    vix          = list(id = "VIXCLS",             agg = "avg"),
    ffr          = list(id = "FEDFUNDS",            agg = "avg"),
    us_gdp_gr    = list(id = "A191RL1Q225SBEA",     agg = "avg"),
    us_10y_yield = list(id = "GS10",                agg = "avg"),
    ted_spread   = list(id = "TEDRATE",             agg = "avg"),
    gpr_global   = list(id = "GPRCHINASQ",          agg = "avg")  # placeholder
  )

  # Note: GPR Global index not on FRED — download manually:
  # https://www.matteoiacoviello.com/gpr_files/data_gpr_export.xls
  # Rename to: 02-Data/raw/gpr_global_quarterly.csv (cols: date, gpr)

  df_list <- lapply(names(series), function(nm) {
    fetch_fred_quarterly(series[[nm]]$id, agg = series[[nm]]$agg, label = nm)
  })

  df_push <- bind_rows(df_list[!sapply(df_list, is.null)]) |>
    pivot_wider(names_from = var, values_from = value)

  # Cross-check: VIX 2010Q1 should be ~20 (GFC recovery)
  vix_2010q1 <- df_push |> filter(date == "2010-01-01") |> pull(vix)
  cat(sprintf("Cross-check VIX 2010Q1: %.2f (expected ~20) %s\n",
              vix_2010q1,
              ifelse(abs(vix_2010q1 - 20) < 5, "✅", "⚠️ CHECK")))

  # Cross-check: FFR 2009Q1 should be ~0.25 (ZLB)
  ffr_2009q1 <- df_push |> filter(date == "2009-01-01") |> pull(ffr)
  cat(sprintf("Cross-check FFR 2009Q1: %.2f (expected ~0.25) %s\n",
              ffr_2009q1,
              ifelse(ffr_2009q1 < 0.5, "✅", "⚠️ CHECK")))

  outfile <- paste0(outdir, "push_factors_quarterly_",
                    format(Sys.Date(), "%Y%m%d"), ".csv")
  write_csv(df_push, outfile)
  message("Saved: ", outfile)
  invisible(df_push)
}

# =============================================================================
# SECTION 2: DOMESTIC PULL FACTORS (IMF DataMapper — ANNUAL, EXECUTABLE NOW)
# =============================================================================

TARGET_COUNTRIES <- c(
  # G20 Emerging
  "ARG","BRA","CHN","IND","IDN","MEX","RUS","SAU","ZAF","TUR",
  # Eurasian/CIS (MGO novelty — underrepresented in existing literature)
  "KAZ","UKR","AZE","GEO","ARM","BLR","MDA","KGZ","TJK","UZB",
  # Eastern Europe
  "POL","HUN","CZE","ROU","BGR","HRV","SRB","ALB",
  # Latin America
  "CHL","COL","PER","URY","ECU","BOL","PRY",
  # Asia
  "KOR","THA","MYS","PHL","VNM","BGD","PAK","LKA",
  # MENA
  "EGY","MAR","TUN","JOR",
  # Sub-Saharan Africa
  "NGA","GHA","KEN","ETH","TZA",
  # Advanced (comparison group)
  "USA","GBR","DEU","FRA","JPN","AUS","CAN","SWE","NOR","CHE"
)

IMF_DATAMAPPER_VARS <- list(
  ca_pct_gdp     = "BCA_NGDPD",    # Current account % GDP (WEO)
  gdp_growth     = "NGDP_RPCH",    # Real GDP growth (WEO)
  inflation      = "PCPIPCH",      # Inflation, avg consumer prices
  reserves_months= "AIP_IX"        # Reserves months of imports
)

fetch_imf_datamapper <- function(indicator, countries = TARGET_COUNTRIES,
                                  start = 1990, end = 2024) {
  ctry_str <- paste(countries, collapse = "/")
  url <- sprintf(
    "https://www.imf.org/external/datamapper/api/v1/%s/%s",
    indicator, ctry_str
  )
  tryCatch({
    resp <- GET(url, timeout(30))
    if (status_code(resp) != 200) stop("HTTP ", status_code(resp))
    raw  <- fromJSON(content(resp, "text", encoding = "UTF-8"))
    vals <- raw$values[[indicator]]

    df <- lapply(names(vals), function(iso3) {
      yr_vals <- vals[[iso3]]
      data.frame(
        iso3     = iso3,
        year     = as.integer(names(yr_vals)),
        value    = as.numeric(unlist(yr_vals)),
        variable = indicator,
        stringsAsFactors = FALSE
      )
    }) |> bind_rows()

    df |> filter(year >= start, year <= end, !is.na(value))
  }, error = function(e) {
    message("IMF DataMapper error (", indicator, "): ", e$message); NULL
  })
}

download_pull_factors <- function(outdir = "02-Data/raw/") {
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  message("Downloading domestic pull factors from IMF DataMapper...")

  df_list <- lapply(names(IMF_DATAMAPPER_VARS), function(nm) {
    message("  Fetching: ", nm)
    df <- fetch_imf_datamapper(IMF_DATAMAPPER_VARS[[nm]])
    if (!is.null(df)) df$var_label <- nm
    Sys.sleep(0.5)
    df
  })

  df_pull <- bind_rows(df_list[!sapply(df_list, is.null)])

  # Cross-check: Türkiye CA/GDP 2011 ≈ -8.8% (verified manually 2026-04-28)
  tur_ca_2011 <- df_pull |>
    filter(iso3 == "TUR", year == 2011, variable == "BCA_NGDPD") |>
    pull(value)
  cat(sprintf("Cross-check TUR CA/GDP 2011: %.1f%% (expected ≈ -8.8) %s\n",
              tur_ca_2011,
              ifelse(abs(tur_ca_2011 - (-8.8)) < 1, "✅", "⚠️ CHECK")))

  outfile <- paste0(outdir, "imf_datamapper_annual_",
                    format(Sys.Date(), "%Y%m%d"), ".csv")
  write_csv(df_pull, outfile)
  message("Saved: ", outfile)
  invisible(df_pull)
}

# =============================================================================
# SECTION 3: WORLD BANK WDI — CREDIT / TRADE / RESERVES (ANNUAL)
# =============================================================================

WDI_VARS <- c(
  credit_pct_gdp = "FS.AST.PRVT.GD.ZS",
  trade_open     = "NE.TRD.GNFS.ZS",
  reserves_gdp   = "BN.RES.INCL.CD"     # total reserves USD — divide by GDP
)

fetch_wdi <- function(indicator, countries = TARGET_COUNTRIES,
                       start = 1990, end = 2024) {
  ctry_str <- paste(countries, collapse = ";")
  url <- sprintf(
    paste0("https://api.worldbank.org/v2/country/%s/indicator/%s",
           "?date=%d:%d&format=json&per_page=20000"),
    ctry_str, indicator, start, end
  )
  tryCatch({
    resp <- GET(url, timeout(60))
    if (status_code(resp) != 200) stop("HTTP ", status_code(resp))
    raw  <- fromJSON(content(resp, "text", encoding = "UTF-8"),
                     simplifyDataFrame = TRUE)
    raw[[2]] |>
      transmute(
        iso3     = countryiso3code,
        year     = as.integer(date),
        value    = as.numeric(value),
        variable = indicator
      ) |>
      filter(!is.na(iso3), iso3 != "", !is.na(value))
  }, error = function(e) {
    message("WDI error (", indicator, "): ", e$message); NULL
  })
}

# =============================================================================
# SECTION 4: TRILEMMA DATA (ALREADY AVAILABLE — shared with Chronic Inf paper)
# =============================================================================
# File exists: ../2026-Chronic-Inflation-Trilemma/02-Data/raw/trilemma_indexes_update2020.dta
# Cols: cn (numeric), year, ers (exchange rate stability),
#       mi (monetary independence), ka_open (capital account openness), country_name
# Coverage: 1960-2020, ~180 countries
# Source: Aizenman, Chinn & Ito — web.pdx.edu/~ito/

TRILEMMA_PATH <- file.path(
  dirname(dirname(getwd())),
  "2026-Chronic-Inflation-Trilemma/02-Data/raw/trilemma_indexes_update2020.dta"
)

load_trilemma <- function(path = TRILEMMA_PATH) {
  if (!file.exists(path)) {
    message("Trilemma file not found at: ", path)
    message("Download from: http://web.pdx.edu/~ito/trilemma_indexes.htm")
    return(NULL)
  }
  df <- haven::read_dta(path) |>
    select(cn, year, ers, mi, ka_open, country_name)
  message("Trilemma data loaded: ", nrow(df), " rows, years ",
          min(df$year), "-", max(df$year))
  df
}

# Note: cn is numeric (IMF country code), not ISO3 — need crosswalk
# Crosswalk file: 02-Data/raw/imf_iso3_crosswalk.csv
# Create with: countrycode::countrycode(cn, "imf", "iso3c") in R

build_iso3_crosswalk <- function(df_trilemma) {
  if (!requireNamespace("countrycode", quietly = TRUE)) {
    message("Install: install.packages('countrycode')")
    return(NULL)
  }
  df_trilemma |>
    distinct(cn, country_name) |>
    mutate(iso3 = countrycode::countrycode(cn, "imf", "iso3c",
                                            warn = FALSE)) |>
    filter(!is.na(iso3))
}

# =============================================================================
# SECTION 5: BOP QUARTERLY GROSS FLOWS — MANUAL DOWNLOAD REQUIRED
# =============================================================================
# The IMF BOP SDMX API endpoint has changed and requires XML parsing.
# MANUAL STEPS (one-time):
#
# Option A (recommended): IMF Data Portal direct download
#   1. Go to: https://data.imf.org/?sk=7A51304B-6426-40C0-83DD-CA473CA1FD52
#   2. Select: Balance of Payments → Quarterly
#   3. Countries: all target countries
#   4. Indicators: BFD_BP6_USD, BFP_BP6_USD, BFO_BP6_USD (FDI/Portfolio/Other liab)
#   5. Download as CSV → save to: 02-Data/raw/imf_bop_gross_quarterly_YYYYMMDD.csv
#
# Option B: IMF SDMX XML parsing (automated but complex)
#   endpoint: https://sdmxcentral.imf.org/ws/public/sdmxapi/rest/data/IMF,BOP_2017M06,1.0/
#   Returns XML — parse with xml2::read_xml() → xml2::xml_find_all()
#
# Option C: World Bank QEDS (Quarterly External Debt Statistics) as proxy
#   api.worldbank.org/v2/country/all/indicator/DT.DOD.DECT.CD?...
#   (annual only — insufficient for quarterly identification)

# =============================================================================
# SECTION 6: FULL PIPELINE — RUN IN ORDER
# =============================================================================

run_data_pipeline <- function() {
  message("\n=== SUDDEN STOPS DATA PIPELINE ===\n")
  message("Step 1/5: Global push factors (FRED)...")
  df_push <- download_push_factors()

  message("\nStep 2/5: Domestic pull factors (IMF DataMapper)...")
  df_pull <- download_pull_factors()

  message("\nStep 3/5: WDI controls (World Bank)...")
  df_wdi <- lapply(names(WDI_VARS), function(nm) {
    fetch_wdi(WDI_VARS[nm])
  }) |> bind_rows()
  write_csv(df_wdi, paste0("02-Data/raw/wdi_controls_annual_",
                            format(Sys.Date(), "%Y%m%d"), ".csv"))

  message("\nStep 4/5: Trilemma indexes (local file)...")
  df_trilemma <- load_trilemma()
  if (!is.null(df_trilemma)) {
    xwalk <- build_iso3_crosswalk(df_trilemma)
    if (!is.null(xwalk)) {
      df_trilemma <- df_trilemma |> left_join(xwalk, by = "cn")
      write_csv(df_trilemma,
                paste0("02-Data/raw/trilemma_aci_",
                       format(Sys.Date(), "%Y%m%d"), ".csv"))
    }
  }

  message("\nStep 5/5: BOP quarterly gross flows — MANUAL DOWNLOAD REQUIRED")
  message("  See Section 5 above for instructions.")
  message("  After download, place file in: 02-Data/raw/")
  message("  Then run: 01_episode_identification_FW2012.R\n")

  message("=== PIPELINE COMPLETE (except BOP manual step) ===")
}

# Uncomment to execute:
# run_data_pipeline()
