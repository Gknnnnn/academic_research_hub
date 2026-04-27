# ============================================================
# WGI MERGE SCRIPT
# SSA Agricultural Determinants Paper — Gulistan Collaboration
# World Bank Worldwide Governance Indicators (WGI)
# Indicators: VA, PV, GE, RQ, RL, CC  |  2000–2020  |  29 SSA Countries
# ============================================================

# --- Gerekli paketler ---
if (!require("WDI"))     install.packages("WDI")
if (!require("dplyr"))   install.packages("dplyr")
if (!require("readr"))   install.packages("readr")
if (!require("countrycode")) install.packages("countrycode")

library(WDI)
library(dplyr)
library(readr)
library(countrycode)

# --- Yollar ---
BASE_PATH  <- "400-Data/2026-Gulistan-Collaboration/data"
INPUT_FILE <- file.path(BASE_PATH, "ssa_tarim_29_ulke_v3.csv")
OUTPUT_FILE <- file.path(BASE_PATH, "ssa_tarim_29_ulke_v4.csv")

# --- Ana veri ---
base <- read_csv(INPUT_FILE, show_col_types = FALSE)
base$year <- as.integer(base$year)

# --- ISO3 kodlarini olustur ---
base$iso3c <- countrycode(base$country, "country.name", "iso3c",
                          custom_match = c("Gambia, The" = "GMB",
                                           "Sao Tome and Principe" = "STP",
                                           "Eswatini" = "SWZ"))

iso_codes <- unique(na.omit(base$iso3c))
cat("ISO3 kodlari:", paste(iso_codes, collapse = ", "), "\n")
cat("Eksik ISO3:", paste(base$country[is.na(base$iso3c)], collapse = ", "), "\n")

# --- WGI gostergelerini World Bank API'den indir ---
wgi_indicators <- c(
  "VA.EST",   # Voice & Accountability
  "PV.EST",   # Political Stability & Absence of Violence
  "GE.EST",   # Government Effectiveness
  "RQ.EST",   # Regulatory Quality
  "RL.EST",   # Rule of Law
  "CC.EST"    # Control of Corruption
)

cat("\nWorld Bank API'den WGI verisi indiriliyor...\n")
wgi_raw <- WDI(
  country   = iso_codes,
  indicator = wgi_indicators,
  start     = 2000,
  end       = 2020,
  extra     = FALSE
)

# --- Sutun isimlerini duzenle ---
wgi_clean <- wgi_raw %>%
  rename(
    iso3c   = iso3c,
    year    = year,
    wgi_va  = VA.EST,
    wgi_pv  = PV.EST,
    wgi_ge  = GE.EST,
    wgi_rq  = RQ.EST,
    wgi_rl  = RL.EST,
    wgi_cc  = CC.EST
  ) %>%
  select(iso3c, year, wgi_va, wgi_pv, wgi_ge, wgi_rq, wgi_rl, wgi_cc)

cat(sprintf("WGI veri boyutu: %d x %d\n", nrow(wgi_clean), ncol(wgi_clean)))

# --- Eksik degerleri rapor et ---
cat("\nEksik deger orani (%):\n")
missing_pct <- colMeans(is.na(wgi_clean[, -c(1,2)])) * 100
print(round(missing_pct, 2))

# --- MERGE ---
merged <- base %>%
  left_join(wgi_clean, by = c("iso3c", "year")) %>%
  select(-iso3c)   # iso3c artik gerekli degil, ana veri setinde yok

cat(sprintf("\nBirlesme oncesi: %d x %d\n", nrow(base), ncol(base)))
cat(sprintf("Birlesme sonrasi: %d x %d\n", nrow(merged), ncol(merged)))

# --- Merge kalitesi kontrolu ---
cat("\nWGI merge sonrasi eksik gozlem:\n")
print(colSums(is.na(merged[, grep("wgi_", names(merged))])))

# --- Ozet istatistikler ---
cat("\nWGI degiskenler ozet:\n")
print(summary(merged[, grep("wgi_", names(merged))]))

# --- Kaydet ---
write_csv(merged, OUTPUT_FILE)
cat(sprintf("\n✓ Kaydedildi: %s\n", OUTPUT_FILE))

# --- Bileşik kurumsal kalite endeksi (opsiyonel) ---
# WGI literatüründe yaygın kullanılan PCA veya basit ortalama
merged_final <- merged %>%
  mutate(
    wgi_composite = rowMeans(select(., wgi_va, wgi_pv, wgi_ge, wgi_rq, wgi_rl, wgi_cc),
                             na.rm = FALSE)
  )

OUTPUT_FILE_V4B <- file.path(BASE_PATH, "ssa_tarim_29_ulke_v4b.csv")
write_csv(merged_final, OUTPUT_FILE_V4B)
cat(sprintf("✓ Bilesik WGI endeksli versiyon kaydedildi: %s\n", OUTPUT_FILE_V4B))

# --- Son kontrol ---
cat("\n--- İlk 5 satir (WGI sutunlari) ---\n")
print(head(merged_final[, c("country","year","wgi_va","wgi_pv","wgi_ge","wgi_rq","wgi_rl","wgi_cc","wgi_composite")], 5))
