# ============================================================
# KG-MGO-01/02: BDDK Data Fetching via API
# Script 00: Comprehensive BDDK Data Collection
# Date: 2026-04-24 | Author: MGO
# ============================================================
#
# BDDK API ENDPOINT:
#   POST https://www.bddk.org.tr/BultenAylik/{lang}/Home/BasitRaporGetir
#   (Used internally by bddkR package — ozancanozdemir/bddkR)
#
# ÖNEMLI KISIT: BDDK public API → GRUP düzeyi veri (bank category aggregates)
#   Group 10001 = Mevduat Bankaları (Deposit Banks)
#   Group 10003 = Katılım Bankaları (Participation Banks)
#   Group 20001 = Kamu Bankaları (State Banks)
#   Group 20002 = Özel Bankalar (Private Banks)
#   Group 20003 = Yabancı Bankalar (Foreign Banks)
#   Group 10004 = Tüm Bankalar (All Banks)
#
# BIREYSEL BANKA DÜZEYİ: Mevcut değil bu API'de.
#   Bireysel banka için: Kandil Göker verisi (BDDK kamuyu PDF/Excel raporu)
#   veya Finnet veri tabanı.
#
# TABLE NUMBERS (1-17):
#   1 = Bilanço (Balance Sheet)
#   2 = Gelir Tablosu (Income Statement) → ROA, NIM bileşenleri
#   3 = Kredi Portföyü
#   4 = Bireysel Krediler
#   5 = Sektörel Kredi Dağılımı
#   6 = KOBİ Finansmanı
#   7 = Sendikasyon ve Seküritizasyon
#   8 = Menkul Kıymetler
#   9 = Mevduat Yapısı → ALTIN MEVDUAT buraya bakılacak
#  10 = Vadeye Göre Mevduat
#  11 = Likidite Göstergeleri
#  12 = Sermaye Yeterliliği (Capital Adequacy = CAR)
#  13 = Döviz Pozisyonu
#  14 = Bilanço Dışı Kalemler
#  15 = Oranlar (Financial Ratios → ROA, NIM, NPL)
#  16 = Faaliyet Bilgileri
#  17 = Yurt Dışı Şube Oranları
# ============================================================

library(httr)
library(jsonlite)
library(tidyverse)
library(lubridate)

# ---- 0. OPTION A: bddkR paketi (önerilen) ----
# devtools::install_github("ozancanozdemir/bddkR")
# library(bddkR)
#
# Örnek kullanım:
# df_ratios <- fetch_data(
#   start_year = 2015, start_month = 1,
#   end_year   = 2025, end_month   = 12,
#   table_no   = 15,   # Financial Ratios (ROA, NIM, NPL)
#   currency   = "TL",
#   group      = 10004, # All Banks
#   lang       = "en",
#   save_excel = FALSE
# )

# ---- 1. DİREKT API ÇAĞRISI (bddkR'ın kullandığı endpoint) ----

bddk_api_fetch <- function(
    start_year, start_month,
    end_year,   end_month,
    table_no,
    currency  = "TL",
    group_id  = 10004,
    lang      = "en") {

  base_url <- sprintf(
    "https://www.bddk.org.tr/BultenAylik/%s/Home/BasitRaporGetir", lang
  )

  # POST body (form-encoded, as used by bddkR)
  body <- list(
    baslangicYil  = as.character(start_year),
    baslangicAy   = as.character(start_month),
    bitisYil      = as.character(end_year),
    bitisAy       = as.character(end_month),
    tablo         = as.character(table_no),
    doviz         = currency,
    grup          = as.character(group_id)
  )

  resp <- tryCatch(
    POST(base_url,
         body    = body,
         encode  = "form",
         add_headers(
           "Content-Type" = "application/x-www-form-urlencoded",
           "User-Agent"   = "Mozilla/5.0 (R/httr bddkR-compatible)"
         ),
         timeout(30)),
    error = function(e) {
      message("API error: ", conditionMessage(e))
      return(NULL)
    }
  )

  if (is.null(resp) || status_code(resp) != 200) {
    message("HTTP ", status_code(resp), " for table ", table_no)
    return(NULL)
  }

  raw <- content(resp, as = "text", encoding = "UTF-8")
  parsed <- fromJSON(raw, simplifyDataFrame = FALSE)

  if (!isTRUE(parsed$success)) {
    message("API returned success=FALSE for table ", table_no)
    return(NULL)
  }

  # Parse JSON structure
  col_names <- parsed$Json$colNames
  rows      <- parsed$Json$data$rows

  df <- map_dfr(rows, function(row) {
    values <- row$cell
    if (length(values) != length(col_names)) {
      values <- c(values, rep(NA, length(col_names) - length(values)))
    }
    set_names(as.list(values), col_names) %>% as_tibble()
  })

  df
}

# ---- 2. ALTIN MEVDUAT VERİSİ (Table 9 — Mevduat Yapısı) ----

fetch_gold_deposits <- function(start_year = 2015, end_year = 2025) {

  groups <- c(
    all          = 10004,
    deposit      = 10001,
    participation = 10003,
    state        = 20001,
    private      = 20002,
    foreign      = 20003
  )

  map_dfr(names(groups), function(grp_name) {
    message("Fetching gold deposit data for group: ", grp_name)
    df <- bddk_api_fetch(
      start_year = start_year, start_month = 1,
      end_year   = end_year,   end_month   = 12,
      table_no   = 9,          # Mevduat Yapısı
      group_id   = groups[grp_name]
    )
    if (!is.null(df)) df %>% mutate(bank_group = grp_name)
    else NULL
  })
}

# ---- 3. FİNANSAL ORANLAR (Table 15 — ROA, NIM, NPL) ----

fetch_financial_ratios <- function(start_year = 2015, end_year = 2025) {

  groups <- c(
    all           = 10004,
    deposit       = 10001,
    participation = 10003,
    state         = 20001,
    private       = 20002,
    foreign       = 20003
  )

  map_dfr(names(groups), function(grp_name) {
    message("Fetching financial ratios for group: ", grp_name)
    df <- bddk_api_fetch(
      start_year = start_year, start_month = 1,
      end_year   = end_year,   end_month   = 12,
      table_no   = 15,
      group_id   = groups[grp_name]
    )
    if (!is.null(df)) df %>% mutate(bank_group = grp_name)
    else NULL
  })
}

# ---- 4. BİLANÇO (Table 1) — Aktif büyüklük, özkaynak ----

fetch_balance_sheet <- function(start_year = 2015, end_year = 2025) {
  groups <- c(all = 10004, state = 20001, private = 20002,
              foreign = 20003, participation = 10003)

  map_dfr(names(groups), function(grp_name) {
    df <- bddk_api_fetch(
      start_year = start_year, start_month = 1,
      end_year   = end_year,   end_month   = 12,
      table_no   = 1,
      group_id   = groups[grp_name]
    )
    if (!is.null(df)) df %>% mutate(bank_group = grp_name)
    else NULL
  })
}

# ---- 5. SERMAYE YETERLİLİĞİ (Table 12 — CAR) ----

fetch_capital_adequacy <- function(start_year = 2015, end_year = 2025) {
  bddk_api_fetch(
    start_year = start_year, start_month = 1,
    end_year   = end_year,   end_month   = 12,
    table_no   = 12,
    group_id   = 10004
  )
}

# ---- 6. PANEL DÖNÜŞÜMÜ (Monthly → Quarterly) ----

to_quarterly_panel <- function(df, date_col = "Tarih", value_cols) {

  df %>%
    mutate(
      date = parse_date_time(.data[[date_col]], orders = c("Ym", "dmy", "ymd")),
      year  = year(date),
      month = month(date),
      qtr   = quarter(date)
    ) %>%
    filter(!is.na(date)) %>%
    # Quarter average (3-month mean)
    group_by(bank_group, year, qtr, across(all_of(value_cols[!value_cols %in% date_col]))) %>%
    summarise(across(all_of(value_cols), ~mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    mutate(period = paste0(year, "Q", qtr))
}

# ---- 7. ALTIN MEVDUAT — VARİABLE EKSTRAKSİYONU ----
#
# Table 9 muhtemelen şu satırları içerir:
#   - Toplam Mevduat (Total deposits)
#   - TL Mevduat
#   - YP Mevduat (foreign currency)
#   - Altın Mevduat (gold deposits) ← ANA DEĞİŞKEN
#
# Satır adları Türkçe — elde edilen df'i inspect ettikten sonra
# doğru sütun/satır adını kullan.
#
# NOT: API muhtemelen satırları değil sütunları döndürür.
# fetch_gold_deposits() çalıştırıp colnames(df) ile incele.

extract_gold_deposit_share <- function(gold_df) {
  # Bu fonksiyon Table 9 output'una göre düzenlenecek.
  # Örnek (gerçek col names fetch sonrası güncellenecek):
  gold_df %>%
    mutate(
      across(contains(c("Altin", "Altın", "Gold", "GOLD")),
             ~as.numeric(gsub(",", ".", .))),
      across(contains(c("Toplam", "Total")),
             ~as.numeric(gsub(",", ".", .)))
    ) %>%
    # Gold deposit share = gold deposits / total deposits * 100
    mutate(
      gold_dep_share = .data[[grep("Altin|Altın|Gold", names(.), value = TRUE)[1]]] /
                       .data[[grep("Toplam|Total", names(.), value = TRUE)[1]]] * 100
    )
}

# ---- 8. TCMB EVDS — TRY/USD VE ALTIN FİYATI ----
#
# EVDS API: https://evds2.tcmb.gov.tr/service/evds/
# API key gerekiyor — ücretsiz kayıt: evds2.tcmb.gov.tr
#
# Alternatif: quantmod / tidyquant ile Yahoo Finance üzerinden

fetch_try_usd <- function(start = "2015-01-01", end = "2025-12-31") {
  library(quantmod)
  # Yahoo Finance: TRY/USD = TRYUSD=X
  getSymbols("TRY=X", from = start, to = end, auto.assign = FALSE) %>%
    as_tibble(rownames = "date") %>%
    mutate(date = as.Date(date)) %>%
    select(date, try_usd = `TRY=X.Close`) %>%
    mutate(
      year  = year(date),
      month = month(date),
      qtr   = quarter(date),
      # Quarterly log-change
      try_usd_logchg = log(try_usd) - log(lag(try_usd, 3))
    )
}

fetch_gold_price_try <- function(start = "2015-01-01", end = "2025-12-31") {
  library(quantmod)
  # Gold price in USD
  gold_usd <- getSymbols("GC=F", from = start, to = end, auto.assign = FALSE) %>%
    as_tibble(rownames = "date") %>%
    mutate(date = as.Date(date)) %>%
    select(date, gold_usd = `GC=F.Close`)

  # TRY/USD
  try_rate <- getSymbols("TRY=X", from = start, to = end, auto.assign = FALSE) %>%
    as_tibble(rownames = "date") %>%
    mutate(date = as.Date(date)) %>%
    select(date, try_usd = `TRY=X.Close`)

  gold_usd %>%
    left_join(try_rate, by = "date") %>%
    mutate(
      gold_try = gold_usd * try_usd,   # Gold price in TRY
      gold_try_logchg = log(gold_try) - log(lag(gold_try))
    )
}

# ---- 9. WORLD BANK — GDP GROWTH, INFLATION, CREDIT/GDP ----

fetch_wb_turkey <- function() {
  library(WDI)
  WDI(
    country   = "TR",
    indicator = c(
      gdp_growth  = "NY.GDP.MKTP.KD.ZG",
      inflation   = "FP.CPI.TOTL.ZG",
      credit_gdp  = "FS.AST.PRVT.GD.ZS",
      broad_money = "FM.LBL.BMNY.GD.ZS"
    ),
    start = 2015,
    end   = 2025,
    extra = FALSE
  ) %>%
    as_tibble() %>%
    select(-country, -iso2c, -iso3c)
}

# ---- 10. MASTER BUILD FUNCTION ----

build_bddk_panel <- function(start_year = 2015, end_year = 2025) {

  message("=== BDDK Panel Build Start ===")
  message("NOTE: This API returns bank GROUP aggregates, not individual bank data.")
  message("Groups: all, deposit, participation, state, private, foreign")

  message("\n[1/4] Fetching financial ratios (ROA, NIM, NPL)...")
  ratios <- fetch_financial_ratios(start_year, end_year)
  saveRDS(ratios, "01-Data/raw/bddk_ratios_raw.rds")

  message("[2/4] Fetching gold deposit structure...")
  gold   <- fetch_gold_deposits(start_year, end_year)
  saveRDS(gold, "01-Data/raw/bddk_gold_raw.rds")

  message("[3/4] Fetching balance sheet (assets, equity)...")
  bs     <- fetch_balance_sheet(start_year, end_year)
  saveRDS(bs, "01-Data/raw/bddk_balance_sheet_raw.rds")

  message("[4/4] Fetching macro controls (WB + quantmod)...")
  macro  <- fetch_wb_turkey()
  saveRDS(macro, "01-Data/raw/wb_turkey_macro.rds")

  message("\n=== Raw data saved to 01-Data/raw/ ===")
  message("Next: Run 01_data_merge.R to compute Z-scores and build panel.")

  list(ratios = ratios, gold = gold, balance_sheet = bs, macro = macro)
}

# ---- 11. WHAT BDDK API GIVES vs WHAT WE NEED ----
#
# ┌──────────────────────────────┬──────────────────────┬──────────────────────────┐
# │ Variable                     │ BDDK API Available?  │ Source                   │
# ├──────────────────────────────┼──────────────────────┼──────────────────────────┤
# │ ROA (by bank group)          │ ✅ Table 15          │ bddk_api_fetch(t=15)     │
# │ NIM (by bank group)          │ ✅ Table 15          │ bddk_api_fetch(t=15)     │
# │ NPL ratio (by bank group)    │ ✅ Table 15          │ bddk_api_fetch(t=15)     │
# │ CAR (by bank group)          │ ✅ Table 12          │ bddk_api_fetch(t=12)     │
# │ Gold deposits (by group)     │ ✅ Table 9           │ bddk_api_fetch(t=9)      │
# │ Total assets (by group)      │ ✅ Table 1           │ bddk_api_fetch(t=1)      │
# │ TRY/USD exchange rate        │ ❌ Not in BDDK       │ quantmod/Yahoo Finance   │
# │ Gold price (TRY/gram)        │ ❌ Not in BDDK       │ TCMB EVDS / quantmod     │
# │ Policy rate                  │ ❌ Not in BDDK       │ TCMB EVDS / WDI          │
# ├──────────────────────────────┼──────────────────────┼──────────────────────────┤
# │ INDIVIDUAL bank-level data   │ ❌ NOT AVAILABLE      │ Kandil Göker / Finnet    │
# │ (Z-score per bank, gold per  │                      │ BDDK PDF quarterly        │
# │  bank, ROA per bank, etc.)   │                      │ reports (manual scrape)   │
# └──────────────────────────────┴──────────────────────┴──────────────────────────┘
#
# SONUÇ:
# KG-MGO-01 (Bank Fragility MMQR):
#   → Bireysel banka = Kandil Göker verisi gerekli
#   → Alternatif: GRUP bazlı panel (N=5 grup, T=120 ay) — küçük N sorunu
#
# KG-MGO-02 (Gold Deposit NARDL):
#   → BDDK Table 9 → altın mevduat payı by bank type ✅
#   → Panel: N=5 bank groups × T=44 quarters (2015Q1-2025Q4)
#   → Yeterli — hipotezler bank-type heterogeneity zaten hedefliyor

# ---- 12. ALTERNATİF: BDDK KREDİLER (Selenium fallback) ----
# Kaynak: ertancelik.medium.com Python rehberi
# Selenium gerektirir; R'da RSelenium ile yapılabilir:
#
# library(RSelenium)
# rD <- rsDriver(browser = "chrome", port = 4567L)
# remDr <- rD$client
# remDr$navigate("https://www.bddk.org.tr/BultenHaftalik")
# ... (JavaScript dropdown → HTML table extract)
#
# Bu yaklaşım yalnızca haftalık bülten için çalışıyor.
# Aylık veriler için direkt API (yukarıdaki bddk_api_fetch) çok daha iyi.

cat("=== BDDK Fetch Script Loaded ===\n")
cat("Kullanım:\n")
cat("  panel <- build_bddk_panel(2015, 2025)\n")
cat("  # veya tekil tablo:\n")
cat("  ratios <- bddk_api_fetch(2015,1,2025,12, table_no=15, group_id=10004)\n")
cat("\nÖNEMLİ: API grup düzeyi veri sağlar (bireysel banka yok).\n")
cat("Bireysel banka için Kandil Göker verisi zorunlu.\n")
