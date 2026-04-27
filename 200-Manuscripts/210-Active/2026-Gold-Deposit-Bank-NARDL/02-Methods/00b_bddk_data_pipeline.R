# ============================================================
# KG-MGO-02: BDDK Data Pipeline — Gold Deposits + Financial Ratios
# Script 00b: Build panel from fetched CSV files
# Date: 2026-04-24 | Author: MGO
#
# BDDK API CONFIRMED WORKING via Python bddkdata package.
# Fetch with Python:
#   python3 00c_fetch_bddk.py   (see sister script)
# This R script reads the CSVs and builds the panel.
#
# CONFIRMED DATA AVAILABLE:
#   Table 9  → "Precious Metal Deposit Accounts - Residents/Non-Residents"
#   Table 15 → ROA, NIM, NPL, ROE
#   Table 1  → Total assets, deposits, equity
#   Groups   → 16 bank type/ownership groups
#   Period   → 2015Q1–2025Q4 (monthly available, aggregate to quarterly)
# ============================================================

library(tidyverse)
library(lubridate)

# ============================================================
# 1. LOAD RAW CSV FILES (from Python fetch)
# ============================================================

load_bddk_raw <- function(raw_dir = "01-Data/raw") {

  gold_path   <- file.path(raw_dir, "bddk_deposits_all_groups.csv")
  ratios_path <- file.path(raw_dir, "bddk_ratios_all_groups.csv")
  bs_path     <- file.path(raw_dir, "bddk_balance_sheet_all_groups.csv")

  list(
    gold   = if (file.exists(gold_path))   read_csv(gold_path,   show_col_types=FALSE) else NULL,
    ratios = if (file.exists(ratios_path)) read_csv(ratios_path, show_col_types=FALSE) else NULL,
    bs     = if (file.exists(bs_path))     read_csv(bs_path,     show_col_types=FALSE) else NULL
  )
}

# ============================================================
# 2. GOLD DEPOSIT EXTRACTION
# ============================================================

extract_gold_panel <- function(gold_df) {

  gold_df %>%
    filter(str_detect(Item, regex("Precious Metal|Gold|Altın", ignore_case=TRUE))) %>%
    mutate(
      date        = as.Date(Period),
      year        = year(date),
      month       = month(date),
      quarter     = quarter(date),
      period_q    = paste0(year, "Q", quarter),
      gold_amount = as.numeric(Total),
      deposit_type = case_when(
        str_detect(Item, "Resident")     ~ "residents",
        str_detect(Item, "Non.Resident") ~ "non_residents",
        TRUE                             ~ "total"
      )
    ) %>%
    # Group labels
    mutate(bank_group = case_when(
      group_id == 10001 ~ "all_banking",
      group_id == 10002 ~ "deposit_banks",
      group_id == 10003 ~ "participation_banks",
      group_id == 10004 ~ "dev_investment",
      group_id == 10005 ~ "domestic_private",
      group_id == 10006 ~ "state",
      group_id == 10007 ~ "foreign",
      group_id == 10008 ~ "deposit_domestic_private",
      group_id == 10009 ~ "deposit_state",
      group_id == 10010 ~ "deposit_foreign",
      group_id == 10011 ~ "participation_domestic_private",
      group_id == 10012 ~ "participation_state",
      group_id == 10013 ~ "participation_foreign",
      TRUE              ~ as.character(group_id)
    )) %>%
    select(bank_group, group_id, deposit_type, gold_amount, date, year, month, quarter, period_q)
}

# ============================================================
# 3. TOTAL DEPOSITS (for gold share computation)
# ============================================================

extract_total_deposits <- function(gold_df) {

  gold_df %>%
    filter(str_detect(Item, regex("^Total Deposit$", ignore_case=TRUE))) %>%
    mutate(
      date          = as.Date(Period),
      year          = year(date),
      quarter       = quarter(date),
      period_q      = paste0(year, "Q", quarter),
      total_deposits = as.numeric(Total),
      bank_group = case_when(
        group_id == 10001 ~ "all_banking",
        group_id == 10002 ~ "deposit_banks",
        group_id == 10003 ~ "participation_banks",
        group_id == 10005 ~ "domestic_private",
        group_id == 10006 ~ "state",
        group_id == 10007 ~ "foreign",
        TRUE              ~ as.character(group_id)
      )
    ) %>%
    select(bank_group, total_deposits, date, year, quarter, period_q)
}

# ============================================================
# 4. FINANCIAL RATIOS (ROA, NIM, NPL from Table 15)
# ============================================================

extract_financial_ratios <- function(ratios_df) {

  # ROA: "Net Income / Average Total Assets (%)"
  # NIM: "Net Interest (Profit) Revenues / Average Total Assets (%)"
  # NPL: "Non-Performing Loans (Gross) / Total Cash Loans (%)"
  # ROE: "Net Income / Average Shareholder's Equity (%)"

  roa_kw  <- "Net Income / Average Total Assets"
  nim_kw  <- "Net Interest.*Average Total Assets"
  npl_kw  <- "Non-Performing Loans.*Total Cash Loans"
  roe_kw  <- "Net Income / Average Shareholder"

  extract_one <- function(df, keyword, varname) {
    df %>%
      filter(str_detect(Item, regex(keyword, ignore_case=TRUE))) %>%
      mutate(
        !!varname := as.numeric(Ratio),
        date       = as.Date(Period),
        year       = year(date),
        quarter    = quarter(date),
        period_q   = paste0(year, "Q", quarter),
        bank_group = case_when(
          group_id == 10001 ~ "all_banking",
          group_id == 10002 ~ "deposit_banks",
          group_id == 10003 ~ "participation_banks",
          group_id == 10004 ~ "dev_investment",
          group_id == 10005 ~ "domestic_private",
          group_id == 10006 ~ "state",
          group_id == 10007 ~ "foreign",
          group_id == 10008 ~ "deposit_domestic_private",
          group_id == 10009 ~ "deposit_state",
          group_id == 10010 ~ "deposit_foreign",
          group_id == 10011 ~ "participation_domestic_private",
          group_id == 10012 ~ "participation_state",
          group_id == 10013 ~ "participation_foreign",
          TRUE              ~ as.character(group_id)
        )
      ) %>%
      select(bank_group, group_id, !!varname, date, year, quarter, period_q)
  }

  roa <- extract_one(ratios_df, roa_kw, "roa")
  nim <- extract_one(ratios_df, nim_kw, "nim")
  npl <- extract_one(ratios_df, npl_kw, "npl")
  roe <- extract_one(ratios_df, roe_kw, "roe")

  # Join all ratios
  roa %>%
    left_join(nim %>% select(bank_group, period_q, nim), by=c("bank_group","period_q")) %>%
    left_join(npl %>% select(bank_group, period_q, npl), by=c("bank_group","period_q")) %>%
    left_join(roe %>% select(bank_group, period_q, roe), by=c("bank_group","period_q"))
}

# ============================================================
# 5. QUARTERLY AGGREGATION (monthly → quarterly average)
# ============================================================

to_quarterly <- function(df, value_vars) {
  df %>%
    group_by(bank_group, year, quarter, period_q) %>%
    summarise(across(all_of(value_vars), ~mean(.x, na.rm=TRUE)),
              .groups = "drop")
}

# ============================================================
# 6. BUILD PANEL + PARTIAL SUMS (for NARDL)
# ============================================================

build_nardl_panel <- function(raw) {

  # Gold deposit share
  gold_panel  <- extract_gold_panel(raw$gold) %>%
    filter(deposit_type == "residents") %>%
    to_quarterly("gold_amount")

  total_panel <- extract_total_deposits(raw$gold) %>%
    to_quarterly("total_deposits")

  gold_share <- gold_panel %>%
    left_join(total_panel, by=c("bank_group","year","quarter","period_q")) %>%
    mutate(gold_dep_share = gold_amount / total_deposits * 100)

  # Financial ratios (already monthly → aggregate to quarterly)
  ratios_panel <- extract_financial_ratios(raw$ratios) %>%
    to_quarterly(c("roa","nim","npl","roe"))

  # Merge
  panel <- gold_share %>%
    left_join(ratios_panel, by=c("bank_group","year","quarter","period_q")) %>%
    arrange(bank_group, year, quarter)

  # Partial sum decomposition for NARDL
  panel <- panel %>%
    group_by(bank_group) %>%
    mutate(
      d_gold    = gold_dep_share - lag(gold_dep_share),
      GD_pos    = cumsum(pmax(d_gold, 0, na.rm=TRUE)),  # GD+
      GD_neg    = cumsum(pmin(d_gold, 0, na.rm=TRUE)),  # GD-
      period_t  = row_number()
    ) %>%
    ungroup()

  panel
}

# ============================================================
# 7. MACRO CONTROLS (TRY/USD via quantmod)
# ============================================================

fetch_try_controls <- function() {
  library(quantmod)

  # TRY/USD from Yahoo Finance
  try_raw <- getSymbols("TRY=X", from="2015-01-01", to="2025-12-31",
                         auto.assign=FALSE)
  try_q <- try_raw %>%
    as_tibble(rownames="date") %>%
    mutate(
      date    = as.Date(date),
      try_usd = `TRY=X.Close`,
      year    = year(date),
      quarter = quarter(date),
      period_q = paste0(year, "Q", quarter)
    ) %>%
    group_by(period_q, year, quarter) %>%
    summarise(
      try_usd_avg = mean(try_usd, na.rm=TRUE),
      .groups = "drop"
    ) %>%
    arrange(year, quarter) %>%
    mutate(
      d_try_usd = log(try_usd_avg) - log(lag(try_usd_avg)),
      TRY_pos   = cumsum(pmax(d_try_usd, 0, na.rm=TRUE)),
      TRY_neg   = cumsum(pmin(d_try_usd, 0, na.rm=TRUE))
    )

  try_q
}

# ============================================================
# 8. MASTER BUILD
# ============================================================

build_full_panel <- function(raw_dir = "01-Data/raw") {

  message("Loading BDDK raw data...")
  raw <- load_bddk_raw(raw_dir)

  if (is.null(raw$gold) || is.null(raw$ratios)) {
    stop("Missing raw CSV files. Run 00c_fetch_bddk.py first.")
  }

  message("Building NARDL panel (gold deposits + ratios)...")
  panel <- build_nardl_panel(raw)

  message("Fetching macro controls (TRY/USD)...")
  macro <- tryCatch(fetch_try_controls(), error=function(e) {
    message("quantmod failed: ", e$message, " — add TRY manually later")
    NULL
  })

  if (!is.null(macro)) {
    panel <- panel %>%
      left_join(macro %>% select(period_q, try_usd_avg, d_try_usd, TRY_pos, TRY_neg),
                by="period_q")
  }

  saveRDS(panel, "01-Data/processed/bddk_panel_nardl.rds")
  write_csv(panel, "01-Data/processed/bddk_panel_nardl.csv")
  message("Panel saved: ", nrow(panel), " rows x ", ncol(panel), " cols")

  panel
}

cat("Script 00b loaded.\n")
cat("Usage: panel <- build_full_panel('01-Data/raw')\n")
cat("Requires: 00c_fetch_bddk.py to have been run first.\n")
