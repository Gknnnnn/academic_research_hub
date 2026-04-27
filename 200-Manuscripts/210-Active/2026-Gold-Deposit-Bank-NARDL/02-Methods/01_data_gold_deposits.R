# ============================================================
# KG-MGO-02: Gold Deposits, Bank Performance, and Currency Risk
# Script 01: Data Collection — BDDK + TCMB + FRED
# Date: 2026-04-24 | Author: MGO
# ============================================================

library(tidyverse)
library(readxl)
library(WDI)
library(lubridate)
library(janitor)
library(slider)     # rolling windows
library(zoo)        # na.locf

# ---- 1. BDDK GOLD DEPOSIT DATA ----
# Source: bddk.org.tr → İstatistiki Veriler → Mevduat/Katılım Fonu Verileri
# Required series (quarterly):
#   - Altın mevduatı: miktar (ton) + değer (milyon TL)
#   - Altın mevduatı / Toplam mevduat (%)
#   - Vadesiz + vadeli altın mevduat breakdown
#   - Banka bazlı: her banka için altın mevduat tutarı

# Manual download → save as: 01-Data/raw/bddk_gold_deposits_quarterly.xlsx
# Then run:
# gold_raw <- read_excel("01-Data/raw/bddk_gold_deposits_quarterly.xlsx",
#                        sheet = "Altın Mevduat",
#                        skip  = 2) %>%
#   clean_names() %>%
#   rename(date = donem, bank_id = banka_kodu,
#          gold_deposit_ton = altin_ton,
#          gold_deposit_tl  = altin_mil_tl)

# ---- 2. BDDK BANK FINANCIALS (Quarterly) ----
# Source: bddk.org.tr → Temel Göstergeler → Banka Bazlı
# Required: ROA, NIM, ROE, NPL, CAR, total_assets, total_deposits
# Frequency: Quarterly (Q1=March, Q2=June, Q3=September, Q4=December)

# bank_fin_raw <- read_excel("01-Data/raw/bddk_bank_financials_quarterly.xlsx",
#                             sheet = "Bilanço",
#                             skip  = 3) %>%
#   clean_names()

# ---- 3. TCMB EVDS — TRY/USD + Gold Price + Policy Rate ----
# Download from: evds2.tcmb.gov.tr
# Series codes:
#   TP.DK.USD.A.12  → TRY/USD monthly average (series)
#   TP.ALTIN.S01    → Gold price (TL/gram)
#   TP.MB.B.A       → TCMB policy rate (%)
#   TP.TUFE         → CPI

# Alternative: Use FRED for USD-denominated gold price
# GOLDAMGBD228NLBM → Gold fixing price, London PM fix (USD/troy oz)

library(fredr)
# fredr_set_key("YOUR_FRED_API_KEY")  # get from fred.stlouisfed.org/docs/api/

fetch_fred_quarterly <- function(series_id, start = "2015-01-01") {
  fredr(
    series_id         = series_id,
    observation_start = as.Date(start),
    frequency         = "q"
  ) %>%
    select(date, value) %>%
    rename(!!series_id := value) %>%
    mutate(
      year    = year(date),
      quarter = quarter(date)
    )
}

# Gold price (USD/oz) → convert to TRY using TRY/USD
# fred_gold <- fetch_fred_quarterly("GOLDAMGBD228NLBM")
# fred_tryusd <- fetch_fred_quarterly("DEXTHUS")  # TRY per USD

# ---- 4. KEY VARIABLE CONSTRUCTION ----

build_gold_panel <- function(gold_df, bank_df, macro_df) {

  # 4A. Gold deposit share (% of total liabilities)
  gold_df <- gold_df %>%
    mutate(gold_dep_share = gold_deposit_tl / total_liabilities * 100)

  # 4B. Partial sum decomposition (NARDL)
  gold_df <- gold_df %>%
    arrange(bank_id, date) %>%
    group_by(bank_id) %>%
    mutate(
      d_gold_dep = gold_deposit_tl - lag(gold_deposit_tl),
      # Positive partial sum: gold deposit inflows
      gold_dep_pos = cumsum(pmax(d_gold_dep, 0, na.rm = TRUE)),
      # Negative partial sum: gold deposit outflows
      gold_dep_neg = cumsum(pmin(d_gold_dep, 0, na.rm = TRUE))
    ) %>%
    ungroup()

  # 4C. TRY depreciation (quarterly log-change)
  macro_df <- macro_df %>%
    arrange(date) %>%
    mutate(
      delta_try = log(tryusd) - lag(log(tryusd)),
      # Positive = depreciation (more TL per USD)
      delta_try_pos = cumsum(pmax(delta_try, 0, na.rm = TRUE)),
      delta_try_neg = cumsum(pmin(delta_try, 0, na.rm = TRUE)),
      # Gold price change (TRY terms)
      delta_gold_try = log(gold_price_try) - lag(log(gold_price_try))
    )

  # 4D. Merge
  panel <- gold_df %>%
    left_join(bank_df,  by = c("bank_id", "date")) %>%
    left_join(macro_df, by = "date") %>%
    # Interaction: gold deposit share × TRY depreciation
    mutate(
      gold_try_interact = gold_dep_share * delta_try,
      # Log total assets
      log_assets = log(total_assets),
      # Crisis dummies
      crisis_2018 = as.integer(year(date) == 2018),
      crisis_2021 = as.integer(year(date) == 2021),
      covid       = as.integer(year(date) %in% c(2020, 2021))
    ) %>%
    arrange(bank_id, date)

  panel
}

# ---- 5. SUMMARY STATISTICS ----
summary_gold <- function(panel_df) {
  vars_of_interest <- c("roa", "nim", "roe", "npl_ratio", "car",
                         "gold_dep_share", "delta_try", "delta_gold_try",
                         "log_assets", "gold_try_interact")
  panel_df %>%
    select(any_of(vars_of_interest)) %>%
    pivot_longer(everything(), names_to = "variable") %>%
    group_by(variable) %>%
    summarise(
      N    = sum(!is.na(value)),
      Mean = mean(value, na.rm = TRUE),
      SD   = sd(value, na.rm = TRUE),
      Min  = min(value, na.rm = TRUE),
      P25  = quantile(value, 0.25, na.rm = TRUE),
      Med  = median(value, na.rm = TRUE),
      P75  = quantile(value, 0.75, na.rm = TRUE),
      Max  = max(value, na.rm = TRUE)
    )
}

# ---- 6. TREND PLOT: Gold Deposit Share vs TRY/USD ----
plot_gold_try_trend <- function(panel_df) {
  agg <- panel_df %>%
    group_by(date) %>%
    summarise(
      gold_dep_share_avg = mean(gold_dep_share, na.rm = TRUE),
      tryusd = first(tryusd)
    )

  ggplot(agg, aes(x = date)) +
    geom_col(aes(y = gold_dep_share_avg * 5), fill = "#d4a000", alpha = 0.6) +
    geom_line(aes(y = tryusd / max(tryusd, na.rm = TRUE) * max(gold_dep_share_avg * 5)),
              colour = "#c0392b", linewidth = 1.2) +
    scale_y_continuous(
      name        = "Avg. Gold Deposit Share (% total liabilities)",
      sec.axis    = sec_axis(~. / 5 * max(agg$tryusd, na.rm = TRUE) / max(agg$gold_dep_share_avg * 5),
                             name = "TRY/USD")
    ) +
    labs(
      title   = "Gold Deposit Share and TRY Depreciation — Turkish Banks (2015–2026)",
      caption = "Source: BDDK, TCMB. Gold bars = deposit share; red line = TRY/USD."
    ) +
    theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank())
}

cat("Script 01 loaded. Waiting for BDDK quarterly gold deposit data.\n")
