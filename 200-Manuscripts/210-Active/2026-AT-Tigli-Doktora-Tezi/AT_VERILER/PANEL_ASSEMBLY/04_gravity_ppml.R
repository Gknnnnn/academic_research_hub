# ============================================================
# AT Doktora Tezi — PPML Gravity Modeli
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================
# Paketler: install.packages(c("fixest","dplyr","tidyr","readr","ggplot2","modelsummary"))
# Referans: Santos Silva & Tenreyro (2006, ReStat); Yotov et al. (2016, WTO Guide)
# ============================================================

library(dplyr)

# Türkçe karakter için PDF device
if (capabilities("cairo")) options(device = function(...) cairo_pdf(...))
library(tidyr)
library(readr)
library(fixest)        # PPML + high-dimensional FE
library(ggplot2)
library(modelsummary)

# ── 0. YOLLAR ─────────────────────────────────────────────────────────
BASE <- "100-Inbox/AT_VERILER/PANEL_ASSEMBLY"   # setwd() ile ayarla

# ── 1. VERİ YÜKLE ─────────────────────────────────────────────────────
panel   <- read_csv(file.path(BASE, "panel_ulke_20260421.csv"),
                    show_col_types = FALSE) %>%
  rename(gdp = gdp_current_usd, pcgdp = gdp_pc_usd, growth = gdp_growth_pct)

tr_trd  <- read_csv(file.path(BASE, "tr_bilateral_trade_20260421.csv"),
                    show_col_types = FALSE)

ct_trd  <- read_csv(file.path(BASE, "comtrade_bilateral_20260421.csv"),
                    show_col_types = FALSE)

geodist <- read_csv(file.path(BASE, "geodist_4ulke.csv"),
                    show_col_types = FALSE)

rta     <- read_csv(file.path(BASE, "rta_dummy_20260421.csv"),
                    show_col_types = FALSE)

# ── 2. TİCARET AKIŞLARI — YÖNLENDİRİLMİŞ PANEL ───────────────────────
# Birim: USD (tüm değerleri USD'ye çevir)

# A. TR bilateral (bin USD → USD)
tr_flows <- bind_rows(
  # TUR → partner (ihracat)
  tr_trd %>% transmute(
    year, exporter = reporter_iso, importer = partner_iso,
    trade_usd = export_bin_usd * 1000
  ),
  # partner → TUR (ithalat = partnerin TUR'a ihracatı)
  tr_trd %>% transmute(
    year, exporter = partner_iso, importer = reporter_iso,
    trade_usd = import_bin_usd * 1000
  )
) %>% filter(trade_usd > 0)

# B. Comtrade bilateral (USD — reporter ihracatı)
ct_flows <- ct_trd %>%
  filter(flow == "ihracat") %>%
  transmute(
    year, exporter = reporter_iso, importer = partner_iso,
    trade_usd = value_usd
  ) %>%
  filter(trade_usd > 0)

# Tüm akışları birleştir (6 ülke çifti × 2 yön = 12 yönlü dyad)
trade <- bind_rows(tr_flows, ct_flows) %>%
  distinct(year, exporter, importer, .keep_all = TRUE) %>%
  arrange(exporter, importer, year)

cat("Toplam ticaret gözlemi:", nrow(trade), "\n")
cat("Dyad sayısı:", n_distinct(paste(trade$exporter, trade$importer)), "\n")

# ── 3. GDP & NÜFUS EKLE ───────────────────────────────────────────────
gdp_pop <- panel %>%
  select(iso3, year, gdp, population) %>%
  filter(!is.na(gdp), !is.na(population))

gravity <- trade %>%
  left_join(gdp_pop %>% rename(exporter=iso3, gdp_exp=gdp, pop_exp=population),
            by = c("exporter","year")) %>%
  left_join(gdp_pop %>% rename(importer=iso3, gdp_imp=gdp, pop_imp=population),
            by = c("importer","year")) %>%
  # GeoDist (statik)
  left_join(geodist %>% select(iso_o, iso_d, dist_km, contig, comlang_off),
            by = c("exporter"="iso_o","importer"="iso_d")) %>%
  # RTA / EU dummy
  left_join(rta %>% select(iso_o, iso_d, year, rta, eu_single_market, cu_tur_eu),
            by = c("exporter"="iso_o","importer"="iso_d","year")) %>%
  # Log dönüşümleri
  mutate(
    ln_trade   = log(trade_usd),
    ln_gdp_exp = log(gdp_exp),
    ln_gdp_imp = log(gdp_imp),
    ln_pop_exp = log(pop_exp),
    ln_pop_imp = log(pop_imp),
    ln_dist    = log(dist_km),
    # Kriz dummies
    crisis_gfc   = as.integer(year == 2009),
    crisis_covid = as.integer(year == 2020),
    # Dönem: AB öncesi / sonrası (BG, RO 2007)
    post_eu_bg_ro = as.integer(year >= 2007),
    # Dyad ID
    dyad_id = paste0(exporter,"_",importer)
  ) %>%
  filter(!is.na(gdp_exp), !is.na(gdp_imp), !is.na(dist_km))

cat("\nGravity panel:\n")
print(gravity %>% group_by(exporter, importer) %>%
        summarise(N=n(), trade_2023=trade_usd[year==2023]/1e9, .groups="drop") %>%
        arrange(exporter, importer))

# ── 4. MODEL TAHMİNLERİ ───────────────────────────────────────────────

# M1: Temel OLS (log-linear, karşılaştırma için)
m1_ols <- feols(ln_trade ~ ln_gdp_exp + ln_gdp_imp + ln_dist + contig +
                  rta + eu_single_market | year,
                data = gravity, cluster = ~dyad_id)

# M2: PPML — yıl sabit etkileri
m2_ppml <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp + ln_dist + contig +
                    rta + eu_single_market | year,
                  data = gravity, cluster = ~dyad_id)

# M3: PPML — çift yönlü sabit etkiler (yıl + dyad)
# Yotov et al. 2016: pair FE endojenliği kontrol eder
m3_ppml_fe <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp +
                       rta + eu_single_market +
                       crisis_gfc + crisis_covid | year + dyad_id,
                     data = gravity, cluster = ~dyad_id)

# M4: PPML — Genişletilmiş (nüfus + AB genişlemesi etkisi)
m4_ppml_ext <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp +
                        ln_pop_exp + ln_pop_imp +
                        rta + eu_single_market + cu_tur_eu +
                        crisis_gfc + crisis_covid + post_eu_bg_ro | year,
                      data = gravity, cluster = ~dyad_id)

# ── 5. SONUÇ TABLOSU ──────────────────────────────────────────────────
coef_labels <- c(
  ln_gdp_exp       = "ln GDP (ihracatçı)",
  ln_gdp_imp       = "ln GDP (ithalatçı)",
  ln_pop_exp       = "ln Nüfus (ihracatçı)",
  ln_pop_imp       = "ln Nüfus (ithalatçı)",
  ln_dist          = "ln Mesafe",
  contig           = "Ortak Sınır",
  rta              = "RTA Dummy",
  eu_single_market = "AB Tek Pazar",
  cu_tur_eu        = "TR-AB Gümrük Birliği",
  crisis_gfc       = "2009 Krizi",
  crisis_covid     = "2020 COVID",
  post_eu_bg_ro    = "Post-2007 (BG-RO AB)"
)

# HTML çıktı (pandoc R paketi gerekmez)
modelsummary(
  list("OLS (log)"=m1_ols,"PPML-YFE"=m2_ppml,"PPML-2FE"=m3_ppml_fe,"PPML-Ext"=m4_ppml_ext),
  stars      = c("*"=0.1,"**"=0.05,"***"=0.01),
  coef_rename = coef_labels,
  gof_map    = c("nobs","r.squared","adj.r.squared"),
  output     = file.path(BASE, "tablo_gravity_sonuclari.html"),
  title      = "Gravity Model: TR-BG-RO-GR (2000-2024)"
)
cat("✅ Tablo HTML kaydedildi\n")

# Aynı tabloyu konsola da bas
modelsummary(
  list("OLS"=m1_ols,"PPML-YFE"=m2_ppml,"PPML-2FE"=m3_ppml_fe,"PPML-Ext"=m4_ppml_ext),
  stars      = c("*"=0.1,"**"=0.05,"***"=0.01),
  coef_rename = coef_labels,
  gof_map    = c("nobs","r.squared","adj.r.squared")
)

# ── 6. İMPULSE: TİCARET YOĞUNLUĞU ENDEKSİ (Balassa) ─────────────────
# TII_ij = (X_ij / X_i) / (X_wj / X_w)  — 1'in üzeri yoğunluk
# Basitleştirilmiş: her dyad'ın toplam içindeki payı

tii <- gravity %>%
  group_by(year, exporter) %>%
  mutate(total_exp = sum(trade_usd)) %>%
  ungroup() %>%
  mutate(
    share_ij = trade_usd / total_exp,
    tii_label = paste0(exporter,"→",importer)
  )

# ── 7. GÖRSELLEŞTIRME ─────────────────────────────────────────────────

# 7a. Ticaret akışları trend (Healy standardı)
p1 <- gravity %>%
  mutate(trade_bn = trade_usd / 1e9,
         dyad = paste0(exporter,"→",importer)) %>%
  ggplot(aes(x=year, y=trade_bn, color=dyad, group=dyad)) +
  geom_line(linewidth=0.8) +
  geom_point(size=1.5) +
  geom_vline(xintercept=c(2007,2009,2020), linetype="dashed",
             color="grey50", linewidth=0.5) +
  annotate("text", x=2007.3, y=max(gravity$trade_usd/1e9)*0.9,
           label="BG-RO AB", size=2.8, hjust=0, color="grey40") +
  annotate("text", x=2009.3, y=max(gravity$trade_usd/1e9)*0.8,
           label="GFC", size=2.8, hjust=0, color="grey40") +
  annotate("text", x=2020.3, y=max(gravity$trade_usd/1e9)*0.7,
           label="COVID", size=2.8, hjust=0, color="grey40") +
  scale_color_viridis_d(option="turbo") +
  labs(
    title = "TR-BG-RO-GR Bilateral Ticaret Akışları (2000-2024)",
    subtitle = "Milyar USD; dikey çizgiler: 2007 AB genişlemesi, 2009 GFC, 2020 COVID",
    x = NULL, y = "Milyar USD", color = "Dyad",
    caption = "Kaynak: TİM + UN Comtrade"
  ) +
  theme_minimal(base_size=11) +
  theme(legend.position="right",
        panel.grid.minor=element_blank())

ggsave(file.path(BASE, "fig01_ticaret_trendleri.pdf"),
       p1, width=10, height=6, dpi=300)
ggsave(file.path(BASE, "fig01_ticaret_trendleri.png"),
       p1, width=10, height=6, dpi=300)
cat("✅ Şekil 1 kaydedildi\n")

# 7b. GDP vs Ticaret scatter (gravity görselleştirme)
p2 <- gravity %>%
  mutate(trade_bn = trade_usd / 1e9,
         gdp_sum_bn = (gdp_exp + gdp_imp) / 1e9,
         dyad = paste0(exporter,"→",importer)) %>%
  ggplot(aes(x=gdp_sum_bn, y=trade_bn, color=dyad)) +
  geom_point(alpha=0.7, size=2) +
  geom_smooth(method="lm", se=FALSE, linewidth=0.6, color="grey30") +
  scale_x_log10(labels=scales::comma) +
  scale_y_log10(labels=scales::comma) +
  scale_color_viridis_d(option="turbo") +
  labs(
    title = "Gravity İlişkisi: GDP × Bilateral Ticaret",
    subtitle = "Log-Log eksen; her nokta bir dyad-yıl gözlemi",
    x = "Toplam GDP (İhracatçı + İthalatçı, Milyar USD, log)",
    y = "Bilateral Ticaret (Milyar USD, log)",
    color = "Dyad",
    caption = "Kaynak: TİM + UN Comtrade + WB WDI"
  ) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank())

ggsave(file.path(BASE, "fig02_gravity_scatter.pdf"),
       p2, width=9, height=6, dpi=300)
ggsave(file.path(BASE, "fig02_gravity_scatter.png"),
       p2, width=9, height=6, dpi=300)
cat("✅ Şekil 2 kaydedildi\n")

# ── 8. ÖZET İSTATİSTİKLER ─────────────────────────────────────────────
cat("\n=== TANIMSAL İSTATİSTİKLER ===\n")
gravity %>%
  summarise(
    N            = n(),
    trade_mean   = mean(trade_usd/1e9, na.rm=TRUE),
    trade_sd     = sd(trade_usd/1e9, na.rm=TRUE),
    trade_min    = min(trade_usd/1e9, na.rm=TRUE),
    trade_max    = max(trade_usd/1e9, na.rm=TRUE),
    gdp_exp_mean = mean(gdp_exp/1e9, na.rm=TRUE),
    dist_mean    = mean(dist_km, na.rm=TRUE),
    rta_pct      = mean(rta, na.rm=TRUE)*100,
    eu_pct       = mean(eu_single_market, na.rm=TRUE)*100
  ) %>% print()

# Dyad bazlı 2024 özet
cat("\n=== 2024 TİCARET (Milyar USD) ===\n")
gravity %>%
  filter(year==2024) %>%
  select(exporter, importer, trade_usd, rta, eu_single_market) %>%
  mutate(trade_bn = round(trade_usd/1e9,2)) %>%
  arrange(desc(trade_bn)) %>%
  print()

cat("\n✅ Tüm analizler tamamlandı.\n")
cat("Çıktılar: tablo_gravity_sonuclari.docx | fig01 | fig02\n")
