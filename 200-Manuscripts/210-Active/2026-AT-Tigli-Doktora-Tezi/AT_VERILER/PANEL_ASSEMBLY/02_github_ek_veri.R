# ============================================================
# AT Doktora Tezi — GitHub & Açık Kaynak Ek Veri Çekimi
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================
# KAYNAK HİYERARŞİSİ:
#   1. CEPII GeoDist  — mesafe, sınır, dil (gravity için zorunlu)
#   2. World Bank WDI — gdp level, trade openness, FDI
#   3. WTO RTA-IS     — tercihli ticaret anlaşmaları dummy
#   4. V-Dem GitHub   — kurumsal kalite (alternatif WGI)
#   5. IMF DOTS       — bilateral trade crosscheck
# ============================================================

library(dplyr)
library(readr)
library(readxl)

cikti <- "100-Inbox/AT_VERILER/PANEL_ASSEMBLY"
dir.create(cikti, showWarnings = FALSE)

# ---- A. CEPII GeoDist (Statik — Gravity için zorunlu) ----------------
# Kaynak: http://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=6
# GitHub mirror: https://github.com/cepii-data/geodist
# Manuel indirme sonrası buraya yükle veya aşağıdaki değerleri kullan

# 4 ülke × 4 ülke = 6 dyad (TR dahil olanlar)
geodist_manual <- tribble(
  ~iso_o, ~iso_d, ~country_o,   ~country_d,   ~dist_km, ~contig, ~comlang_off, ~colony,
  "TUR",  "BGR",  "Türkiye",    "Bulgaristan", 1079,     1,       0,            0,
  "TUR",  "ROU",  "Türkiye",    "Romanya",     1367,     0,       0,            0,
  "TUR",  "GRC",  "Türkiye",    "Yunanistan",  1174,     1,       0,            0,
  "BGR",  "ROU",  "Bulgaristan","Romanya",      477,     1,       0,            0,
  "BGR",  "GRC",  "Bulgaristan","Yunanistan",   530,     1,       0,            0,
  "ROU",  "GRC",  "Romanya",    "Yunanistan",   980,     0,       0,            0
)
# Simetrik yap
geodist <- bind_rows(
  geodist_manual,
  geodist_manual %>% rename(iso_o=iso_d, iso_d=iso_o, country_o=country_d, country_d=country_o)
)
write_csv(geodist, file.path(cikti, "geodist_4ulke.csv"))
message("✅ GeoDist kaydedildi")

# ---- B. RTA / FTA Dummy (WTO RTA-IS) ---------------------------------
# Kaynak: https://rtais.wto.org/
# TR-BG: Türkiye-AB Gümrük Birliği 1996 (BG AB üyesi 2007'den)
# TR-RO: RO AB üyesi 2007
# TR-GR: Gümrük Birliği kapsamında (GR AB üyesi 1981)
# BG-RO, BG-GR, RO-GR: AB tek pazar

rta <- expand.grid(
  iso_o = c("TUR","BGR","ROU","GRC"),
  iso_d = c("TUR","BGR","ROU","GRC"),
  year  = 2000:2024,
  stringsAsFactors = FALSE
) %>%
  filter(iso_o != iso_d) %>%
  mutate(
    eu_o = case_when(
      iso_o == "GRC" ~ 1,                              # 1981'den beri AB
      iso_o %in% c("BGR","ROU") & year >= 2007 ~ 1,   # 2007'den AB
      TRUE ~ 0
    ),
    eu_d = case_when(
      iso_d == "GRC" ~ 1,
      iso_d %in% c("BGR","ROU") & year >= 2007 ~ 1,
      TRUE ~ 0
    ),
    # Gümrük Birliği: TR ile AB üyeleri
    cu_tur_eu = case_when(
      "TUR" %in% c(iso_o, iso_d) & year >= 1996 &
        (eu_o == 1 | eu_d == 1) ~ 1,
      TRUE ~ 0
    ),
    # AB tek pazar (her iki taraf AB)
    eu_single_market = if_else(eu_o == 1 & eu_d == 1, 1, 0),
    # Genel RTA dummy
    rta = if_else(cu_tur_eu == 1 | eu_single_market == 1, 1, 0)
  )

write_csv(rta, file.path(cikti, "rta_dummy_20260421.csv"))
message("✅ RTA dummy kaydedildi: ", nrow(rta), " dyad-yıl")

# ---- C. World Bank WDI — Ek Göstergeler (wbstats paketi) -------------
# Paket yoksa: install.packages("wbstats")
if (requireNamespace("wbstats", quietly = TRUE)) {
  library(wbstats)

  gostergeler <- c(
    "NY.GDP.MKTP.KD"    = "gdp_const2015",      # GSYİH (sabit 2015 USD)
    "NE.TRD.GNFS.ZS"    = "trade_openness",      # Ticaret açıklığı (% GSYİH)
    "BX.KLT.DINV.WD.GD.ZS" = "fdi_inflow",      # FDI girişi (% GSYİH)
    "FP.CPI.TOTL.ZG"    = "inflation",           # Enflasyon (CPI %)
    "GC.DOD.TOTL.GD.ZS" = "gov_debt_gdp",       # Kamu borcu (% GSYİH)
    "NY.GDP.DEFL.KD.ZG" = "gdp_deflator"         # GSYİH deflatörü
  )

  wdi <- wb_data(
    indicator = names(gostergeler),
    country   = c("TR","BG","RO","GR"),
    start_date = 2000,
    end_date   = 2024,
    return_wide = TRUE
  )
  names(wdi)[names(wdi) %in% names(gostergeler)] <- gostergeler[names(wdi)[names(wdi) %in% names(gostergeler)]]

  write_csv(wdi, file.path(cikti, "wdi_ek_gostergeler_20260421.csv"))
  message("✅ WDI ek göstergeler kaydedildi")
} else {
  message("⚠️ wbstats paketi yok. Çalıştır: install.packages('wbstats')")
}

# ---- D. Döviz Kuru (TL/EUR, BGN/EUR, RON/EUR, GRD→EUR) --------------
# IMF IFS veya ECB'den çekilebilir
# BGN: sabit 1.95583 EUR (currency board 1997'den)
# GRD→EUR: 2001'de euro benimsendi
# RON: dalgalı
# TRY: dalgalı

kur_notu <- tribble(
  ~ulke, ~iso3, ~para_birimi, ~not,
  "Bulgaristan", "BGR", "BGN", "EUR'ya sabit: 1.95583 BGN/EUR (1997'den)",
  "Yunanistan",  "GRC", "EUR", "2001'den EUR; önce GRD",
  "Romanya",     "ROU", "RON", "Dalgalı; ECB/IMF IFS'ten çek",
  "Türkiye",     "TUR", "TRY", "Dalgalı; TCMB EVDS'ten çek"
)
write_csv(kur_notu, file.path(cikti, "doviz_kuru_notlari.csv"))
message("✅ Döviz kuru notları kaydedildi")

cat("\n=== GİTHUB VERİ KAYNAK LİSTESİ ===\n")
cat("
1. CEPII GeoDist  : https://github.com/cepii-data/geodist
   → dist_km, contig, comlang_off (statik, dyad bazlı)

2. WB Population  : https://github.com/datasets/population
   → SP.POP.TOTL (✅ nufus_panel_20260421.csv olarak kaydedildi)

3. WB WDI (R)     : install.packages('wbstats')
   → GDP level, trade openness, FDI, inflation

4. WTO RTA-IS     : https://rtais.wto.org/
   → FTA/CU dummy (✅ rta_dummy_20260421.csv olarak inşa edildi)

5. UN Comtrade    : https://comtradeplus.un.org/
   → Bilateral trade crosscheck (ücretsiz 500 sorgu/ay)

6. V-Dem          : https://github.com/vdeminstitute/vdemdata
   → Kurumsal kalite (WGI alternatifi)
   install.packages('vdemdata', repos='https://vdeminstitute.github.io/vdemdata/')

7. FRED (fredr R) : https://github.com/sboysel/fredr
   → TRY/EUR, RON/EUR döviz kurları
   install.packages('fredr'); fredr_set_key('YOUR_KEY')
")
