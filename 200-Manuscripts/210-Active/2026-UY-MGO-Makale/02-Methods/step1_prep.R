# SECTION 1: VERİ HAZIRLIĞI VE KEŞİFSEL ANALİZ

library(plm)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)

cat("\n=== 1. VERİ HAZIRLIĞI ===\n")

# Verileri oku (CSV'den) - Path fixed to data/
veri_ham <- read_csv("data/gelismekte_olan_veri.csv", show_col_types = FALSE)

# Sıralama: ülke + yıl
veri_ham <- veri_ham %>%
  arrange(country, year)

cat("Ham veri boyutu:", nrow(veri_ham), "gözlem,", length(unique(veri_ham$country)), "ülke\n")

# ---- 1.1 Temel Değişkenler ----
analiz <- veri_ham %>%
  select(country, iso3c, year, region, income,
         ln_ihracat, ln_reer, ln_gsyh,
         hukuk, regulasyon,
         ihracat, reer, gsyh) %>%
  drop_na(ln_ihracat, ln_reer, ln_gsyh, hukuk) %>%
  arrange(country, year)

cat("Temiz veri boyutu:", nrow(analiz), "gözlem,", length(unique(analiz$country)), "ülke\n")

# ---- 1.2 Tanımlayıcı İstatistikler ----
cat("\n--- Tanımlayıcı İstatistikler ---\n")
analiz %>%
  select(ln_ihracat, ln_reer, ln_gsyh, hukuk, regulasyon) %>%
  summary() %>%
  print()

# ---- 1.3 Bölge Dağılımı ----
cat("\n--- Bölge Dağılımı ---\n")
analiz %>%
  count(region, name = "gözlem") %>%
  mutate(ulke_sayisi = sapply(region, function(r)
    length(unique(analiz$country[analiz$region == r])))) %>%
  print()

# ---- 1.4 Etkileşim Terimi ----
analiz <- analiz %>%
  mutate(reer_x_hukuk = ln_reer * hukuk)

# ---- 1.5 Panel Veri Nesnesi ----
panel <- pdata.frame(analiz, index = c("country", "year"))

cat("\n✔ Panel veri nesnesi oluşturuldu.\n")
cat("Balanse durumu:", pdim(panel)$balanced, "\n")

# Save processed data for next steps
saveRDS(analiz, "analiz_data.rds")
saveRDS(panel, "panel_data.rds")
