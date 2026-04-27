# ============================================================
# AT Doktora Tezi — Veri Birleştirme & Panel Oluşturma
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================

library(readxl)
library(dplyr)
library(tidyr)
library(readr)

# ---- 0. Yollar -------------------------------------------------------
veri_koku <- "100-Inbox/AT_VERILER"   # çalışma dizinine göre ayarla
cikti     <- file.path(veri_koku, "PANEL_ASSEMBLY")
dir.create(cikti, showWarnings = FALSE)

ulkeler <- c("Türkiye", "Bulgaristan", "Romanya", "Yunanistan")

# ---- 1. Nüfus (GitHub/WB — hazır CSV) --------------------------------
nufus <- read_csv(file.path(cikti, "nufus_panel_20260421.csv"),
                  show_col_types = FALSE)

# ---- 2. GSYİH Büyüme Oranları ----------------------------------------
# Her dosya: yıl + büyüme oranı içermeli (ham yapıya göre düzenle)
oku_buyume <- function(dosya, ulke) {
  df <- read_excel(dosya)
  # Kolon isimlerini normalize et
  names(df) <- tolower(names(df))
  # Yıl ve değer kolonunu bul
  yil_kol  <- names(df)[grepl("yıl|year|date|dönem", names(df), ignore.case = TRUE)][1]
  deger_kol <- names(df)[!names(df) %in% yil_kol][1]
  df <- df[, c(yil_kol, deger_kol)]
  names(df) <- c("year", "gdp_growth")
  df$country <- ulke
  df <- df %>% filter(!is.na(year), !is.na(gdp_growth))
  df$year <- as.integer(df$year)
  df
}

# UYARI: OneDrive sync tamamlanınca bu yolları aktif edin
buyume_dosyalari <- list(
  list(file.path(veri_koku, "GSYIH BUYUME ORANLARI/BULGARISTAN.xlsx"), "Bulgaristan"),
  list(file.path(veri_koku, "GSYIH BUYUME ORANLARI/ROMANYA.xlsx"),    "Romanya"),
  list(file.path(veri_koku, "GSYIH BUYUME ORANLARI/TURKIYE.xls"),     "Türkiye"),
  list(file.path(veri_koku, "GSYIH BUYUME ORANLARI/YUNANISTAN.xlsx"), "Yunanistan")
)

buyume_liste <- lapply(buyume_dosyalari, function(x) {
  tryCatch(oku_buyume(x[[1]], x[[2]]),
           error = function(e) { message("Dosya okunamadı: ", x[[1]]); NULL })
})
gdp_growth <- bind_rows(Filter(Negate(is.null), buyume_liste))

# ---- 3. Per Capita GDP -----------------------------------------------
oku_pcgdp <- function(dosya, ulke_filtre = NULL) {
  df <- read_excel(dosya)
  names(df) <- tolower(trimws(names(df)))
  # Geniş formattan uzuna çevir (yıl=sütun ise)
  if (any(grepl("^20[0-9]{2}$", names(df)))) {
    yil_kollar <- names(df)[grepl("^20[0-9]{2}$", names(df))]
    id_kol     <- names(df)[!names(df) %in% yil_kollar][1]
    df <- df %>%
      pivot_longer(cols = all_of(yil_kollar), names_to = "year", values_to = "gdp_pc") %>%
      mutate(year = as.integer(year)) %>%
      rename(country = !!id_kol)
  }
  if (!is.null(ulke_filtre)) df <- df %>% filter(country == ulke_filtre)
  df
}

pcgdp_tur   <- tryCatch(
  oku_pcgdp(file.path(veri_koku, "PER CAPITA GDP/PER CAPITA GDP TURKIYE.xls")) %>%
    mutate(country = "Türkiye"),
  error = function(e) { message("PCGDP_TUR okunamadı"); NULL })

pcgdp_diger <- tryCatch(
  oku_pcgdp(file.path(veri_koku, "PER CAPITA GDP/DIGER UC ULKE.xlsx")),
  error = function(e) { message("PCGDP_3 okunamadı"); NULL })

gdp_pc <- bind_rows(pcgdp_tur, pcgdp_diger) %>%
  select(country, year, gdp_pc)

# ---- 4. Dış Ticaret (TR — İhracat & İthalat) -----------------------
# Bu dosyalar ülke bazlı ise BG/RO/GR satırlarını filtrele
oku_ticaret <- function(dosya, tip) {
  df <- read_excel(dosya)
  names(df) <- tolower(trimws(names(df)))
  # Geniş format (ülke=satır, yıl=sütun) varsayımı
  yil_kollar <- names(df)[grepl("^20[0-9]{2}$", names(df))]
  if (length(yil_kollar) == 0) {
    # Uzun format: year + country + value
    return(df %>% rename(value = last(names(df))) %>% mutate(type = tip))
  }
  id_kol <- names(df)[1]
  df %>%
    pivot_longer(cols = all_of(yil_kollar), names_to = "year", values_to = "value") %>%
    mutate(year = as.integer(year), type = tip) %>%
    rename(partner = !!id_kol)
}

ihracat <- tryCatch(
  oku_ticaret(file.path(veri_koku, "DIS TICARET/2000-2024 TR IHRACAT.xls"), "ihracat"),
  error = function(e) { message("İhracat okunamadı"); NULL })

ithalat <- tryCatch(
  oku_ticaret(file.path(veri_koku, "DIS TICARET/2000-2024 TR ITHALAT.xls"), "ithalat"),
  error = function(e) { message("İthalat okunamadı"); NULL })

ticaret_raw <- bind_rows(ihracat, ithalat)

# BG, RO, GR'yi filtrele
hedef_ulkeler <- c("BULGARİSTAN", "BULGARISTAN", "BGR",
                   "ROMANYA",     "ROU",
                   "YUNANİSTAN",  "YUNANISTAN",  "GRC", "GRE", "GREECE")
ticaret <- ticaret_raw %>%
  filter(toupper(partner) %in% toupper(hedef_ulkeler)) %>%
  mutate(country_partner = case_when(
    grepl("BUL|BGR", partner, ignore.case = TRUE) ~ "Bulgaristan",
    grepl("ROM|ROU", partner, ignore.case = TRUE) ~ "Romanya",
    grepl("YUN|GRC|GRE|GREECE", partner, ignore.case = TRUE) ~ "Yunanistan",
    TRUE ~ partner
  ))

# ---- 5. Ana Panel Birleştirme ----------------------------------------
panel <- nufus %>%
  left_join(gdp_growth %>% select(country, year, gdp_growth), by = c("country","year")) %>%
  left_join(gdp_pc     %>% select(country, year, gdp_pc),     by = c("country","year")) %>%
  filter(year >= 2000, year <= 2024) %>%
  arrange(country, year)

write_csv(panel, file.path(cikti, paste0("panel_AT_", format(Sys.Date(), "%Y%m%d"), ".csv")))
message("✅ Ana panel kaydedildi: ", nrow(panel), " gözlem")

# Ticaret ayrı kaydet (TR perspektif)
if (nrow(ticaret) > 0) {
  write_csv(ticaret, file.path(cikti, paste0("ticaret_TR_bilateral_", format(Sys.Date(), "%Y%m%d"), ".csv")))
  message("✅ Ticaret verisi kaydedildi: ", nrow(ticaret), " gözlem")
}

# ---- 6. Özet ----------------------------------------------------------
cat("\n=== PANEL ÖZETİ ===\n")
print(panel %>% group_by(country) %>% summarise(
  N = n(), yil_aralik = paste(min(year), max(year), sep="-"),
  eksik_buyume = sum(is.na(gdp_growth)),
  eksik_pcgdp  = sum(is.na(gdp_pc))
))
