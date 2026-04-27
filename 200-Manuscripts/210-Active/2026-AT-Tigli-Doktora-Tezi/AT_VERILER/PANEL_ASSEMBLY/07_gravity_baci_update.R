# ============================================================
# AT Doktora Tezi — BACI Destekli Gravity Modeli Güncellemesi
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================
# AMAÇ: 04_gravity_ppml.R'daki karma (TİM + Comtrade) ticaret verilerini
# CEPII BACI HS92 V202601 ile değiştir. BACI: FOB USD, küresel tutarlı.
# ============================================================
# ÖN KOŞUL: 05_baci_cikart.py tamamlanmış olmalı (BACI extract)
#   → baci_bilateral_total_20260421.csv mevcut
#   → baci_bilateral_hs2_20260421.csv   mevcut
# ============================================================

library(dplyr)

# Türkçe karakter için PDF device
if (capabilities("cairo")) options(device = function(...) cairo_pdf(...))
library(tidyr)
library(readr)
library(fixest)
library(ggplot2)
library(modelsummary)

BASE <- "100-Inbox/AT_VERILER/PANEL_ASSEMBLY"

# ── 1. BACI VERİSİNİ YÜKLE ────────────────────────────────────────────
baci_total_path <- file.path(BASE, "baci_bilateral_total_20260421.csv")
baci_hs2_path   <- file.path(BASE, "baci_bilateral_hs2_20260421.csv")

if (!file.exists(baci_total_path)) {
  stop("❌ BACI çıktı dosyası bulunamadı: baci_bilateral_total_20260421.csv\n",
       "   Lütfen önce BACI extraction script'ini tamamlayın.")
}

baci <- read_csv(baci_total_path, show_col_types = FALSE)
baci_hs2 <- read_csv(baci_hs2_path, show_col_types = FALSE)

cat("BACI yüklendi:", nrow(baci), "dyad-yıl gözlemi\n")
cat("HS2 sektörel:", nrow(baci_hs2), "gözlem\n")
cat("Yıl aralığı:", min(baci$year), "-", max(baci$year), "\n")
cat("Dyad sayısı:", n_distinct(paste(baci$exporter_iso, baci$importer_iso)), "\n")

# ── 2. BACI vs TİM+COMTRADE KARŞILAŞTIRMA ────────────────────────────
# Önceki karma veri
tr_trd <- read_csv(file.path(BASE, "tr_bilateral_trade_20260421.csv"),
                   show_col_types = FALSE)
ct_trd <- read_csv(file.path(BASE, "comtrade_bilateral_20260421.csv"),
                   show_col_types = FALSE)

# Önceki veri: 2023 özet
prev_2023_tr <- tr_trd %>%
  filter(year == 2023) %>%
  transmute(dyad = paste0("TUR→", partner_iso),
            prev_bn = trade_bin_usd / 1e6)

prev_2023_ct <- ct_trd %>%
  filter(year == 2023, flow == "ihracat") %>%
  transmute(dyad = paste0(reporter_iso, "→", partner_iso),
            prev_bn = value_usd / 1e9)

# BACI 2023
baci_2023 <- baci %>%
  filter(year == 2023) %>%
  mutate(dyad = paste0(exporter_iso, "→", importer_iso),
         baci_bn = value_bin_usd / 1000) %>%
  select(dyad, baci_bn)

cat("\n=== BACI vs Önceki Kaynak Karşılaştırması (2023) ===\n")
cat(sprintf("%-22s %8s %8s %8s\n", "Dyad", "BACI(B$)", "Önceki(B$)", "Fark%"))
cat(strrep("-", 52), "\n")
for (d in unique(baci_2023$dyad)) {
  baci_v <- baci_2023$baci_bn[baci_2023$dyad == d]

  prev_tr <- prev_2023_tr$prev_bn[prev_2023_tr$dyad == d]
  prev_ct <- prev_2023_ct$prev_bn[prev_2023_ct$dyad == d]
  prev_v  <- ifelse(length(prev_tr) > 0, prev_tr[1],
               ifelse(length(prev_ct) > 0, prev_ct[1], NA))

  if (is.na(prev_v) || prev_v == 0) {
    cat(sprintf("  %-20s %8.2f %8s %8s\n", d, baci_v, "N/A", "N/A"))
  } else {
    diff_pct <- (baci_v / prev_v - 1) * 100
    cat(sprintf("  %-20s %8.2f %8.2f %7.1f%%\n", d, baci_v, prev_v, diff_pct))
  }
}

# ── 3. BACI'YI GRAVITY PANELİNE ENTEGRE ET ───────────────────────────
panel   <- read_csv(file.path(BASE, "panel_ulke_20260421.csv"),
                    show_col_types = FALSE) %>%
  rename(gdp=gdp_current_usd, pcgdp=gdp_pc_usd, growth=gdp_growth_pct)
geodist <- read_csv(file.path(BASE, "geodist_4ulke.csv"),
                    show_col_types = FALSE)
rta     <- read_csv(file.path(BASE, "rta_dummy_20260421.csv"),
                    show_col_types = FALSE)

gdp_pop <- panel %>%
  select(iso3, year, gdp, population) %>%
  filter(!is.na(gdp), !is.na(population))

# BACI: value_bin_usd → USD (×1000)
gravity_baci <- baci %>%
  filter(year >= 2000) %>%
  mutate(trade_usd = value_bin_usd * 1000) %>%
  rename(exporter = exporter_iso, importer = importer_iso) %>%
  filter(trade_usd > 0) %>%
  left_join(gdp_pop %>% rename(exporter=iso3, gdp_exp=gdp, pop_exp=population),
            by=c("exporter","year")) %>%
  left_join(gdp_pop %>% rename(importer=iso3, gdp_imp=gdp, pop_imp=population),
            by=c("importer","year")) %>%
  left_join(geodist %>% select(iso_o,iso_d,dist_km,contig,comlang_off),
            by=c("exporter"="iso_o","importer"="iso_d")) %>%
  left_join(rta %>% select(iso_o,iso_d,year,rta,eu_single_market,cu_tur_eu),
            by=c("exporter"="iso_o","importer"="iso_d","year")) %>%
  mutate(
    ln_trade   = log(trade_usd),
    ln_gdp_exp = log(gdp_exp),
    ln_gdp_imp = log(gdp_imp),
    ln_pop_exp = log(pop_exp),
    ln_pop_imp = log(pop_imp),
    ln_dist    = log(dist_km),
    crisis_gfc   = as.integer(year == 2009),
    crisis_covid = as.integer(year == 2020),
    post_eu_bg_ro = as.integer(year >= 2007),
    dyad_id = paste0(exporter, "_", importer)
  ) %>%
  filter(!is.na(gdp_exp), !is.na(gdp_imp), !is.na(dist_km))

cat("\nBACİ-tabanlı Gravity paneli:", nrow(gravity_baci), "gözlem\n")
print(gravity_baci %>% group_by(exporter, importer) %>%
        summarise(N=n(), trade_2023=trade_usd[year==2023]/1e9, .groups="drop") %>%
        arrange(exporter, importer))

# ── 4. MODEL TAHMİNLERİ (BACI) ────────────────────────────────────────
cat("\n=== BACI-tabanlı PPML Modelleri ===\n")

# M1-BACI: OLS karşılaştırma
m1_baci <- feols(ln_trade ~ ln_gdp_exp + ln_gdp_imp + ln_dist + contig +
                   rta + eu_single_market | year,
                 data=gravity_baci, cluster=~dyad_id)

# M2-BACI: PPML yıl FE
m2_baci <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp + ln_dist + contig +
                    rta + eu_single_market | year,
                  data=gravity_baci, cluster=~dyad_id)

# M3-BACI: PPML çift yönlü FE
m3_baci <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp +
                    rta + eu_single_market + crisis_gfc + crisis_covid |
                    year + dyad_id,
                  data=gravity_baci, cluster=~dyad_id)

# M4-BACI: Genişletilmiş
m4_baci <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp +
                    ln_pop_exp + ln_pop_imp + rta + eu_single_market +
                    cu_tur_eu + crisis_gfc + crisis_covid + post_eu_bg_ro | year,
                  data=gravity_baci, cluster=~dyad_id)

# ── 5. SONUÇ TABLOSU — BACI ───────────────────────────────────────────
coef_labels <- c(
  ln_gdp_exp="ln GDP (ihracatçı)", ln_gdp_imp="ln GDP (ithalatçı)",
  ln_pop_exp="ln Nüfus (ihracatçı)", ln_pop_imp="ln Nüfus (ithalatçı)",
  ln_dist="ln Mesafe", contig="Ortak Sınır", rta="RTA Dummy",
  eu_single_market="AB Tek Pazar", cu_tur_eu="TR-AB Gümrük Birliği",
  crisis_gfc="2009 Krizi", crisis_covid="2020 COVID",
  post_eu_bg_ro="Post-2007 (BG-RO AB)"
)

modelsummary(
  list("OLS-BACI"=m1_baci, "PPML-YFE-BACI"=m2_baci,
       "PPML-2FE-BACI"=m3_baci, "PPML-Ext-BACI"=m4_baci),
  stars       = c("*"=0.1, "**"=0.05, "***"=0.01),
  coef_rename = coef_labels,
  gof_map     = c("nobs","r.squared","adj.r.squared"),
  output      = file.path(BASE, "tablo_gravity_baci_sonuclari.html"),
  title       = "Gravity Model (BACI): TR-BG-RO-GR (2000-2024)"
)
cat("✅ BACI tablo HTML kaydedildi\n")

modelsummary(
  list("OLS"=m1_baci, "PPML-YFE"=m2_baci,
       "PPML-2FE"=m3_baci, "PPML-Ext"=m4_baci),
  stars       = c("*"=0.1, "**"=0.05, "***"=0.01),
  coef_rename = coef_labels,
  gof_map     = c("nobs","r.squared","adj.r.squared")
)

# ── 6. SEKTÖREL ANALİZ (HS2) ──────────────────────────────────────────
cat("\n=== SEKTÖREL ANALİZ — HS2 Bazlı TUR İhracatı ===\n")

# BACI HS2 etiketleri (HS92 seçili)
hs2_etiket <- c(
  "01"="Canlı Hayvanlar", "02"="Et", "03"="Balık", "04"="Süt&Yumurta",
  "07"="Sebze", "08"="Meyve", "10"="Tahıl", "15"="Bitkisel Yağlar",
  "22"="İçecekler", "27"="Mineral Yakıtlar", "28"="Kimyasallar",
  "29"="Organik Kimya", "39"="Plastik", "40"="Kauçuk",
  "52"="Pamuk", "61"="Örgü Giyim", "62"="Dokuma Giyim",
  "63"="Tekstil (Diğer)", "72"="Demir&Çelik", "73"="Demir Ürünleri",
  "84"="Makine", "85"="Elektrikli Mak.", "87"="Araçlar",
  "94"="Mobilya"
)

tur_hs2 <- baci_hs2 %>%
  filter(exporter_iso == "TUR", year == 2023) %>%
  mutate(sektor = hs2_etiket[hs2]) %>%
  mutate(sektor = ifelse(is.na(sektor), paste0("HS", hs2), sektor)) %>%
  arrange(desc(value_bin_usd)) %>%
  head(20)

cat("TUR ihracatı 2023 — ilk 20 HS2 sektörü:\n")
print(tur_hs2 %>% select(hs2, sektor, importer_iso, value_bin_usd) %>%
        mutate(value_mn = round(value_bin_usd/1e3, 1)))

# Top sektörler görselleştir
p8 <- baci_hs2 %>%
  filter(exporter_iso == "TUR") %>%
  group_by(year, hs2) %>%
  summarise(value_bn = sum(value_bin_usd) / 1e6, .groups="drop") %>%
  filter(hs2 %in% names(which(sort(table(tur_hs2$hs2), dec=TRUE) > 0)[1:8])) %>%
  mutate(sektor = hs2_etiket[hs2]) %>%
  mutate(sektor = ifelse(is.na(sektor), paste0("HS", hs2), sektor)) %>%
  ggplot(aes(x=year, y=value_bn, color=sektor, group=sektor)) +
  geom_line(linewidth=0.7) +
  scale_color_viridis_d(option="turbo") +
  labs(
    title = "Türkiye İhracatı — Sektörel Dağılım (2000-2024)",
    subtitle = "HS2 bazlı, BACI; Milyar USD",
    x=NULL, y="Milyar USD", color="Sektör",
    caption="Kaynak: CEPII BACI HS92 V202601"
  ) +
  theme_minimal(base_size=10) +
  theme(legend.position="right", panel.grid.minor=element_blank())

ggsave(file.path(BASE, "fig08_tur_sektor_ihracat.pdf"), p8, width=11, height=6, dpi=300)
ggsave(file.path(BASE, "fig08_tur_sektor_ihracat.png"), p8, width=11, height=6, dpi=300)
cat("✅ Şekil 8 (Sektörel ihracat) kaydedildi\n")

cat("\n✅ BACI-tabanlı tüm analizler tamamlandı.\n")
cat("Çıktılar:\n")
cat("  tablo_gravity_baci_sonuclari.html  — BACI PPML sonuçları\n")
cat("  fig08_tur_sektor_ihracat.pdf/png   — Sektörel ihracat trendi\n")
cat("\nSONRAKİ ADIM: 04 (TİM+Comtrade) vs 07 (BACI) katsayılarını karşılaştır\n")
cat("  → Tutarlılık güçlü ise BACI'yı ana veri olarak sun\n")
cat("  → Farklılık varsa: TİM FOB vs CIF farkı + raporlama yılı not düş\n")
