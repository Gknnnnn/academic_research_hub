# =============================================================================
# Sudden Stop Episode Identification: Forbes & Warnock (2012) Methodology
# Paper: Global Uncertainty, Domestic Credit, and Sudden Stops
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-28
# Reference: Forbes, K.J. & Warnock, F.E. (2012). Capital flow waves:
#            Surges, stops, flight, and retrenchment.
#            Journal of International Economics, 88(2), 235-251.
#            DOI: [UNVERIFIED — check 10.1016/j.jinteco.2012.05.003]
# =============================================================================

# Required packages
library(dplyr)
library(tidyr)
library(zoo)       # rollapply
library(lubridate)
library(readr)

# =============================================================================
# SECTION 1: EPISODE IDENTIFICATION FUNCTION (Forbes-Warnock 2012)
# =============================================================================
# Definition:
#   A "SUDDEN STOP" in gross capital inflows occurs when:
#   (i)  The 4-quarter rolling sum of year-on-year CHANGE in gross inflows
#        falls at least 1 SD below its 5-year rolling mean (condition: sustained)
#   (ii) In at least one quarter, that change is 2+ SD below the 5-year mean
#
# Analogous definitions:
#   SURGE    : gross inflows ≥1 SD ABOVE mean, at least 1 quarter ≥2 SD above
#   FLIGHT   : gross outflows (residents) ≥1 SD above mean
#   RETRENCH : gross outflows ≤1 SD below mean (retrenchment by residents)

identify_fw_episodes <- function(
    df,                  # data.frame: columns = iso3, date (Date), flow_gross_in (USD mn)
    window_years = 5,    # rolling mean/SD window (quarters)
    sd_low = 1,          # lower threshold (sustained condition)
    sd_high = 2,         # peak threshold (at least 1 quarter)
    min_quarters = 2     # minimum consecutive quarters for sustained episode
) {
  window_q <- window_years * 4  # 5 years = 20 quarters

  df <- df %>%
    arrange(iso3, date) %>%
    group_by(iso3) %>%
    mutate(
      # Step 1: Year-on-year change in gross inflows (4Q sum)
      flow_4q     = rollapply(flow_gross_in, width = 4, FUN = sum,
                               fill = NA, align = "right"),
      flow_4q_lag = lag(flow_4q, 4),
      delta_flow  = flow_4q - flow_4q_lag,

      # Step 2: Rolling mean and SD over preceding 5 years (20 quarters)
      roll_mean = rollapply(delta_flow, width = window_q,
                             FUN = mean, na.rm = TRUE,
                             fill = NA, align = "right"),
      roll_sd   = rollapply(delta_flow, width = window_q,
                             FUN = sd, na.rm = TRUE,
                             fill = NA, align = "right"),

      # Step 3: Standardise
      z_score = (delta_flow - roll_mean) / roll_sd,

      # Step 4: Flag quarters below threshold
      flag_low  = as.integer(!is.na(z_score) & z_score < -sd_low),
      flag_high = as.integer(!is.na(z_score) & z_score < -sd_high),

      # Step 5: Episode = sustained (flag_low) AND at least 1 peak (flag_high)
      # Using run-length encoding within group: identify consecutive runs
      run_id = cumsum(flag_low == 0) + 1  # each run of 1s gets same ID
    ) %>%
    group_by(iso3, run_id) %>%
    mutate(
      run_length   = sum(flag_low),
      has_peak     = any(flag_high == 1),
      sudden_stop  = as.integer(
        flag_low == 1 &
        run_length >= min_quarters &
        has_peak
      )
    ) %>%
    ungroup() %>%
    select(-run_id, -run_length, -has_peak)

  return(df)
}

# =============================================================================
# SECTION 2: DATA LOADING PLACEHOLDER
# =============================================================================
# Data source: IMF Balance of Payments Statistics (BOP) / IFS
# API: https://data.imf.org/api/
# Quarterly, USD millions, gross capital inflows
# Variables needed:
#   - Direct Investment Liabilities (BXFAD)
#   - Portfolio Investment Liabilities (BXFAP)
#   - Other Investment Liabilities (BXFAO)
#   - Total Gross Inflows = sum of above (or line BCA_BP6_USD)
#
# Placeholder: replace with actual IMF API call or downloaded CSV
# See 02_data_collection_imf_bop.R for API script

load_capital_flows <- function(filepath) {
  # Expected columns: iso3, date (YYYY-MM-DD, first day of quarter), flow_gross_in
  df <- read_csv(filepath, show_col_types = FALSE) %>%
    mutate(date = as.Date(date)) %>%
    filter(!is.na(flow_gross_in))
  return(df)
}

# =============================================================================
# SECTION 3: EPISODE SUMMARY STATISTICS
# =============================================================================

summarise_episodes <- function(df_episodes) {
  df_episodes %>%
    filter(sudden_stop == 1) %>%
    group_by(iso3) %>%
    summarise(
      n_episodes     = n(),
      first_episode  = min(date),
      last_episode   = max(date),
      avg_z_score    = mean(z_score, na.rm = TRUE),
      min_z_score    = min(z_score, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(n_episodes))
}

# =============================================================================
# SECTION 4: PANEL FREQUENCY TABLE (for manuscript Table 1)
# =============================================================================

episode_frequency_table <- function(df_episodes, group_var = NULL) {
  # Overall SS frequency by country-quarter
  freq_overall <- df_episodes %>%
    filter(!is.na(sudden_stop)) %>%
    summarise(
      total_country_quarters = n(),
      ss_quarters            = sum(sudden_stop),
      ss_frequency_pct       = round(100 * ss_quarters / total_country_quarters, 2)
    )

  # By decade
  freq_decade <- df_episodes %>%
    filter(!is.na(sudden_stop)) %>%
    mutate(decade = paste0(floor(year(date) / 10) * 10, "s")) %>%
    group_by(decade) %>%
    summarise(
      ss_frequency_pct = round(100 * mean(sudden_stop, na.rm = TRUE), 2),
      .groups = "drop"
    )

  # By crisis episode (GFC 2008-09, COVID 2020)
  freq_crisis <- df_episodes %>%
    filter(!is.na(sudden_stop)) %>%
    mutate(
      crisis = case_when(
        date >= "2008-07-01" & date <= "2009-12-31" ~ "GFC 2008-09",
        date >= "2020-01-01" & date <= "2020-12-31" ~ "COVID-19 2020",
        TRUE ~ "Non-crisis"
      )
    ) %>%
    group_by(crisis) %>%
    summarise(
      ss_frequency_pct = round(100 * mean(sudden_stop, na.rm = TRUE), 2),
      .groups = "drop"
    )

  list(
    overall = freq_overall,
    by_decade = freq_decade,
    by_crisis = freq_crisis
  )
}

# =============================================================================
# SECTION 5: ROBUSTNESS — ALTERNATIVE DEFINITIONS
# =============================================================================
# Alternative 1: Net flows (traditional Calvo 1998/2004 approach)
# Alternative 2: 2-SD threshold for sustained (more restrictive)
# Alternative 3: Exclude GFC and COVID quarters

identify_fw_net <- function(df, ...) {
  # Same as identify_fw_episodes but applied to net flows
  # df must have column: flow_net (= gross inflows - gross outflows)
  df %>% rename(flow_gross_in = flow_net) %>%
    identify_fw_episodes(...) %>%
    rename(flow_net = flow_gross_in)
}

# =============================================================================
# SECTION 6: BINARY OUTCOME VARIABLE EXPORT (for panel probit)
# =============================================================================

export_for_probit <- function(df_episodes, outpath) {
  df_out <- df_episodes %>%
    select(iso3, date, sudden_stop, delta_flow, z_score, roll_mean, roll_sd) %>%
    filter(!is.na(sudden_stop))

  write_csv(df_out, outpath)
  message("Exported: ", nrow(df_out), " country-quarter observations to ", outpath)
  invisible(df_out)
}

# =============================================================================
# SECTION 7: MAIN EXECUTION (run after data is available)
# =============================================================================

# Uncomment when 02-Data/bop_gross_inflows_quarterly.csv is ready:
#
# df_raw <- load_capital_flows("02-Data/bop_gross_inflows_quarterly.csv")
#
# df_ss <- identify_fw_episodes(
#   df        = df_raw,
#   window_years = 5,
#   sd_low    = 1,
#   sd_high   = 2,
#   min_quarters = 2
# )
#
# summary_stats <- summarise_episodes(df_ss)
# freq_table    <- episode_frequency_table(df_ss)
#
# print(summary_stats)
# print(freq_table$overall)
# print(freq_table$by_decade)
# print(freq_table$by_crisis)
#
# export_for_probit(df_ss, "02-Data/sudden_stop_binary_fw2012.csv")

# =============================================================================
# CROSS-CHECK NOTE (Anayasa — data verification protocol)
# =============================================================================
# After generating SS episodes:
# 1. Manually verify 2008Q4-2009Q1 shows SS for major EMs (Brazil, South Korea,
#    Mexico, Poland) — confirmed in Forbes & Warnock (2012) Table 1.
# 2. Verify COVID 2020Q1-Q2 shows SS for most countries.
# 3. Compare episode count/frequency with:
#    - Business Perspectives (2025): ~10-15% quarterly frequency
#    - Du & Pu (2025): check their reported episode statistics
# 4. Log any discrepancies: audit_episode_identification_YYYYMMDD.txt
