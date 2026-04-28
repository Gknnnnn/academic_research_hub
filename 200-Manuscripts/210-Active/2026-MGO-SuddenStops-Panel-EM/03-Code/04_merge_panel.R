# =============================================================================
# Panel Merge & Clean — All Data Sources
# Paper: Global Uncertainty, Domestic Credit, and Sudden Stops
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-28
# Run AFTER: 02_data_collection_imf_bop.R + manual BOP download
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(zoo)

DATA_DIR <- "02-Data/raw/"
OUT_DIR  <- "02-Data/clean/"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# STEP 1: LOAD ALL SOURCES
# =============================================================================

load_all <- function() {

  # 1a. BOP quarterly gross flows (manual download required)
  bop_files <- list.files(DATA_DIR, pattern = "imf_bop_gross_quarterly", full.names = TRUE)
  if (length(bop_files) == 0) stop("BOP file missing — download from imf.org first")
  df_bop <- read_csv(bop_files[1], show_col_types = FALSE) %>%
    mutate(date = as.Date(date)) %>%
    arrange(iso3, date)

  # 1b. Push factors (quarterly)
  push_files <- list.files(DATA_DIR, pattern = "push_factors_quarterly", full.names = TRUE)
  df_push <- read_csv(push_files[length(push_files)], show_col_types = FALSE) %>%
    mutate(date = as.Date(date))

  # 1c. WDI controls (annual — will interpolate to quarterly)
  wdi_files <- list.files(DATA_DIR, pattern = "wdi_controls_annual", full.names = TRUE)
  df_wdi <- read_csv(wdi_files[length(wdi_files)], show_col_types = FALSE)

  # 1d. Trilemma (annual)
  tri_files <- list.files(DATA_DIR, pattern = "trilemma_aci_iso3", full.names = TRUE)
  df_tri <- read_csv(tri_files[length(tri_files)], show_col_types = FALSE)

  # 1e. iMaPP (quarterly — after manual download)
  mpp_files <- list.files(DATA_DIR, pattern = "imapp", full.names = TRUE)
  if (length(mpp_files) > 0) {
    df_mpp <- read_csv(mpp_files[length(mpp_files)], show_col_types = FALSE)
  } else {
    df_mpp <- NULL
    message("iMaPP not found — MPP variable will be missing")
  }

  # 1f. GPR index (monthly → aggregate to quarterly)
  gpr_files <- list.files(DATA_DIR, pattern = "gpr_global", full.names = TRUE)
  if (length(gpr_files) > 0) {
    df_gpr <- read_csv(gpr_files[length(gpr_files)], show_col_types = FALSE) %>%
      mutate(
        date = as.Date(date),
        quarter = as.Date(paste0(year(date), "-",
                                  sprintf("%02d", (((month(date) - 1) %/% 3) * 3) + 1),
                                  "-01"))
      ) %>%
      group_by(quarter) %>%
      summarise(gpr = mean(gpr, na.rm = TRUE), .groups = "drop") %>%
      rename(date = quarter)
  } else {
    df_gpr <- NULL
    message("GPR not found — geopolitical risk variable will be missing")
  }

  # 1g. Exchange rate regime (annual)
  irr_files <- list.files(DATA_DIR, pattern = "irr_regime", full.names = TRUE)
  if (length(irr_files) > 0) {
    df_irr <- read_csv(irr_files[length(irr_files)], show_col_types = FALSE)
  } else {
    df_irr <- NULL
    message("IRR not found — exchange rate regime variable will be missing")
  }

  list(bop = df_bop, push = df_push, wdi = df_wdi,
       tri = df_tri, mpp = df_mpp, gpr = df_gpr, irr = df_irr)
}

# =============================================================================
# STEP 2: BUILD ANNUAL→QUARTERLY BRIDGE
# =============================================================================

expand_annual_to_quarterly <- function(df_annual, id_vars = c("iso3"),
                                        value_vars, year_var = "year") {
  # For each country-year observation, replicate to Q1-Q4
  # Annual variables assigned to all quarters within that year
  # (standard approach: level variables like CA/GDP are taken as annual averages)

  df_annual %>%
    tidyr::crossing(quarter = 1:4) %>%
    mutate(
      date = as.Date(sprintf("%d-%02d-01",
                              !!sym(year_var),
                              (quarter - 1) * 3 + 1))
    ) %>%
    select(all_of(id_vars), date, all_of(value_vars)) %>%
    arrange(across(all_of(id_vars)), date)
}

# =============================================================================
# STEP 3: MERGE ALL SOURCES
# =============================================================================

build_panel <- function(data_list) {
  d <- data_list

  # Start from BOP quarterly backbone
  df <- d$bop

  # 3a. Merge push factors (quarterly — exact date join)
  df <- df %>% left_join(d$push, by = "date")

  # 3b. Merge WDI controls (annual → quarterly expansion)
  df_wdi_q <- d$wdi %>%
    mutate(year = as.integer(year)) %>%
    expand_annual_to_quarterly(
      id_vars    = "iso3",
      value_vars = setdiff(names(d$wdi), c("iso3", "year")),
      year_var   = "year"
    )
  df <- df %>%
    mutate(year = year(date)) %>%
    left_join(d$wdi %>% mutate(year = as.integer(year)), by = c("iso3", "year"))

  # 3c. Trilemma (annual)
  df <- df %>%
    left_join(d$tri %>% rename(year = year), by = c("iso3", "year"))

  # 3d. GPR (quarterly)
  if (!is.null(d$gpr)) {
    df <- df %>% left_join(d$gpr, by = "date")
  }

  # 3e. iMaPP (quarterly)
  if (!is.null(d$mpp)) {
    df <- df %>% left_join(d$mpp, by = c("iso3", "date"))
  }

  # 3f. IRR regime (annual)
  if (!is.null(d$irr)) {
    df <- df %>% left_join(d$irr, by = c("iso3", "year"))
  }

  df
}

# =============================================================================
# STEP 4: CLEAN & DERIVE VARIABLES
# =============================================================================

clean_panel <- function(df) {
  df %>%
    # Log transformations
    mutate(
      log_reserves_usd = log(pmax(reserves_usd, 1e6)),  # floor at $1mn
      log_gdp          = if ("gdp_usd" %in% names(.)) log(gdp_usd) else NA_real_
    ) %>%

    # Winsorise extreme values (1st-99th percentile by variable)
    mutate(across(
      c(ca_pct_gdp, credit_pct_gdp, trade_open, inflation),
      ~ {
        lo <- quantile(.x, 0.01, na.rm = TRUE)
        hi <- quantile(.x, 0.99, na.rm = TRUE)
        pmin(pmax(.x, lo), hi)
      }
    )) %>%

    # Country-income group classification (manual — expand as needed)
    mutate(
      income_group = case_when(
        iso3 %in% c("USA","GBR","DEU","FRA","JPN","AUS","CAN","SWE","NOR","CHE") ~ "Advanced",
        iso3 %in% c("KAZ","UKR","AZE","GEO","ARM","BLR","MDA","KGZ","UZB") ~ "Eurasia/CIS",
        TRUE ~ "Emerging"
      ),
      region = case_when(
        iso3 %in% c("KAZ","UKR","AZE","GEO","ARM","BLR","MDA","KGZ","UZB",
                    "RUS","POL","HUN","CZE","ROU","BGR","HRV","SRB","TUR") ~ "Eurasia/CIS",
        iso3 %in% c("ARG","BRA","CHL","COL","PER","URY","ECU","MEX") ~ "Latin America",
        iso3 %in% c("CHN","IND","IDN","KOR","THA","MYS","PHL","VNM","BGD","PAK") ~ "Asia",
        iso3 %in% c("EGY","MAR","TUN","JOR","SAU") ~ "MENA",
        iso3 %in% c("NGA","GHA","KEN","ETH","ZAF") ~ "Sub-Saharan Africa",
        iso3 %in% c("USA","GBR","DEU","FRA","JPN","AUS","CAN","SWE","NOR","CHE") ~ "Advanced",
        TRUE ~ "Other"
      )
    ) %>%

    # Remove rows with missing dependent variable
    filter(!is.na(sudden_stop)) %>%

    # Sort
    arrange(iso3, date)
}

# =============================================================================
# STEP 5: COMPLETENESS AUDIT (Anayasa — data verification)
# =============================================================================

audit_panel <- function(df) {
  cat("\n=== PANEL COMPLETENESS AUDIT ===\n")
  cat(sprintf("Countries: %d\n", length(unique(df$iso3))))
  cat(sprintf("Date range: %s to %s\n", min(df$date), max(df$date)))
  cat(sprintf("Total observations: %d\n", nrow(df)))
  cat(sprintf("Sudden stop episodes: %d (%.1f%%)\n",
              sum(df$sudden_stop, na.rm = TRUE),
              100 * mean(df$sudden_stop, na.rm = TRUE)))

  cat("\nMissing values by variable:\n")
  miss <- df %>%
    summarise(across(everything(), ~ mean(is.na(.)))) %>%
    pivot_longer(everything(), names_to = "var", values_to = "pct_missing") %>%
    filter(pct_missing > 0) %>%
    arrange(desc(pct_missing))
  print(miss, n = 20)

  cat("\nSS frequency by income group:\n")
  df %>%
    group_by(income_group) %>%
    summarise(
      n_obs = n(),
      ss_pct = round(100 * mean(sudden_stop, na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    print()

  cat("\nSS frequency by decade:\n")
  df %>%
    mutate(decade = paste0(floor(year(date) / 10) * 10, "s")) %>%
    group_by(decade) %>%
    summarise(ss_pct = round(100 * mean(sudden_stop, na.rm = TRUE), 2),
              .groups = "drop") %>%
    print()
}

# =============================================================================
# MAIN — run after BOP download
# =============================================================================

# data_list <- load_all()
# df_merged <- build_panel(data_list)
# df_clean  <- clean_panel(df_merged)
# audit_panel(df_clean)
# outf <- paste0(OUT_DIR, "panel_sudden_stops_", format(Sys.Date(), "%Y%m%d"), ".csv")
# write_csv(df_clean, outf)
# message("Final panel saved: ", outf)
