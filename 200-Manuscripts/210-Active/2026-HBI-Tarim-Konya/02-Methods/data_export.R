# data_export.R
# Bu script, MGO_HBI_Tarim_Konya_v2.qmd dosyasındaki veri hazırlama sürecini 
# tekrarlar ve nihai veri setlerini CSV formatında yedekler.

library(WDI)
library(dplyr)
library(purrr)
library(readr)
library(countrycode)
library(zoo)

message("--- Veri Çekme Başlatıldı (WDI) ---")

# 1. Gösterge Tanımları
gostergeler <- c(tarim_gsyh = "NV.AGR.TOTL.ZS", 
                 emek = "SL.AGR.EMPL.ZS", 
                 toprak = "AG.LND.AGRI.ZS", 
                 gubre = "AG.CON.FERT.ZS",
                 verim = "AG.YLD.CREL.KG", 
                 ticaret = "TX.VAL.FOOD.ZS.UN")

# 2. Ham Veriyi Çek
veri_raw_list <- lapply(names(gostergeler), function(n) {
  WDI(indicator = gostergeler[n], start = 2000, end = 2020, extra = TRUE)
})

# 3. Verileri Birleştirme
veri_raw <- veri_raw_list %>% reduce(left_join, by = c("iso3c", "year", "country"))

# 4. Temizleme ve 105 Ülke Filtresi
# Not: region.x sütunu reduce sonrası oluşur
veri_wdi_temiz <- veri_raw %>%
  filter(!is.na(region.x) & region.x != "Aggregates") %>% 
  select(country, iso3c, year, region = region.x, all_of(names(gostergeler))) %>%
  na.omit() %>% 
  group_by(iso3c) %>% 
  filter(n() == 21) %>% 
  ungroup()

message(paste("Filtreleme sonrası ülke sayısı:", n_distinct(veri_wdi_temiz$iso3c)))

# 5. FAO Verisi Entegrasyonu
if (file.exists("fao_makine.csv")) {
  fao_ham_veri <- read_csv("fao_makine.csv", show_col_types = FALSE)
  ekipman_temiz <- fao_ham_veri %>%
    mutate(iso3c = countrycode(Area, origin = "country.name", destination = "iso3c")) %>%
    select(iso3c, year = Year, ekipman = Value) %>%
    filter(iso3c %in% veri_wdi_temiz$iso3c)

  # 6. Nihai Panel (veri_tam_panel)
  veri_tam_panel <- veri_wdi_temiz %>%
    left_join(ekipman_temiz, by = c("iso3c", "year")) %>%
    group_by(iso3c) %>%
    mutate(ekipman = na.approx(ekipman, rule = 2, na.rm = FALSE)) %>%
    ungroup() %>%
    mutate(ekipman = ifelse(is.na(ekipman), mean(ekipman, na.rm = TRUE), ekipman))
} else {
  stop("fao_makine.csv dosyası bulunamadı!")
}

# 7. Normalizasyon (model_verisi)
model_verisi <- veri_tam_panel %>%
  select(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  mutate(across(everything(), function(x) (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))))

# 8. ÇIKIŞ (Yedekleme)
if (!dir.exists("data/backup")) dir.create("data/backup", recursive = TRUE)

write_csv(veri_tam_panel, "data/backup/veri_tam_panel.csv")
write_csv(model_verisi, "data/backup/model_verisi.csv")

message("--- Yedekleme Başarıyla Tamamlandı ---")
message("Dosyalar: data/backup/veri_tam_panel.csv ve data/backup/model_verisi.csv")
