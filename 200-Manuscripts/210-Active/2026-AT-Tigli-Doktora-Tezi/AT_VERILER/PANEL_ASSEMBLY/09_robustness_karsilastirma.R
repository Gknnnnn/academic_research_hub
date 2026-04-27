# ============================================================
# AT Doktora Tezi — Robustness: TİM+Comtrade vs BACI Karşılaştırması
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================
# AMAÇ: İki ticaret veri kaynağının gravity katsayılarını yan yana sun.
#        Tutarlılık → BACI ana kaynak olarak sunulabilir.
# ============================================================

library(dplyr)

# Türkçe karakter için PDF device
if (capabilities("cairo")) options(device = function(...) cairo_pdf(...))
library(tidyr)
library(readr)
library(fixest)
library(modelsummary)
library(ggplot2)

BASE <- "100-Inbox/AT_VERILER/PANEL_ASSEMBLY"

# ── 1. VERİ ───────────────────────────────────────────────────────────
panel   <- read_csv(file.path(BASE, "panel_ulke_20260421.csv"),
                    show_col_types = FALSE) %>%
  rename(gdp=gdp_current_usd, pcgdp=gdp_pc_usd, growth=gdp_growth_pct)
tr_trd  <- read_csv(file.path(BASE, "tr_bilateral_trade_20260421.csv"),
                    show_col_types = FALSE)
ct_trd  <- read_csv(file.path(BASE, "comtrade_bilateral_20260421.csv"),
                    show_col_types = FALSE)
baci    <- read_csv(file.path(BASE, "baci_bilateral_total_20260421.csv"),
                    show_col_types = FALSE)
geodist <- read_csv(file.path(BASE, "geodist_4ulke.csv"), show_col_types=FALSE)
rta     <- read_csv(file.path(BASE, "rta_dummy_20260421.csv"), show_col_types=FALSE)

# ── 2. YARDIMCI FONKSİYON: GRAVITY PANELİ OLUŞTURBuild ───────────────
build_gravity <- function(trade_df) {
  gdp_pop <- panel %>%
    select(iso3, year, gdp, population) %>%
    filter(!is.na(gdp), !is.na(population))

  trade_df %>%
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
      ln_dist    = log(dist_km),
      crisis_gfc   = as.integer(year == 2009),
      crisis_covid = as.integer(year == 2020),
      post_eu_bg_ro = as.integer(year >= 2007),
      dyad_id = paste0(exporter,"_",importer)
    ) %>%
    filter(!is.na(gdp_exp), !is.na(gdp_imp), !is.na(dist_km))
}

# ── 3. TİM+COMTRADE PANELİ ────────────────────────────────────────────
tr_flows <- bind_rows(
  tr_trd %>% transmute(year, exporter=reporter_iso, importer=partner_iso,
                        trade_usd=export_bin_usd*1000),
  tr_trd %>% transmute(year, exporter=partner_iso, importer=reporter_iso,
                        trade_usd=import_bin_usd*1000)
) %>% filter(trade_usd > 0)

ct_flows <- ct_trd %>%
  filter(flow=="ihracat") %>%
  transmute(year, exporter=reporter_iso, importer=partner_iso, trade_usd=value_usd) %>%
  filter(trade_usd > 0)

tim_trade <- bind_rows(tr_flows, ct_flows) %>%
  distinct(year, exporter, importer, .keep_all=TRUE)

gravity_tim  <- build_gravity(tim_trade)

# ── 4. BACI PANELİ ────────────────────────────────────────────────────
baci_trade <- baci %>%
  filter(year >= 2000) %>%
  mutate(trade_usd = value_bin_usd * 1000) %>%
  rename(exporter=exporter_iso, importer=importer_iso) %>%
  filter(trade_usd > 0)

gravity_baci <- build_gravity(baci_trade)

# ── 5. MODELLERİ TAHMİN ET — HER İKİ KAYNAK ──────────────────────────
cat("=== TİM+COMTRADE: PPML-2FE ===\n")
m_tim_2fe <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp +
                      rta + eu_single_market + crisis_gfc + crisis_covid |
                      year + dyad_id,
                    data=gravity_tim, cluster=~dyad_id)

cat("=== BACI: PPML-2FE ===\n")
m_baci_2fe <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp +
                       rta + eu_single_market + crisis_gfc + crisis_covid |
                       year + dyad_id,
                     data=gravity_baci, cluster=~dyad_id)

cat("=== TİM+COMTRADE: PPML-YFE ===\n")
m_tim_yfe <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp + ln_dist + contig +
                      rta + eu_single_market | year,
                    data=gravity_tim, cluster=~dyad_id)

cat("=== BACI: PPML-YFE ===\n")
m_baci_yfe <- fepois(trade_usd ~ ln_gdp_exp + ln_gdp_imp + ln_dist + contig +
                       rta + eu_single_market | year,
                     data=gravity_baci, cluster=~dyad_id)

# ── 6. YAN YANA KARŞILAŞTIRMA TABLOSU ────────────────────────────────
coef_labels <- c(
  ln_gdp_exp="ln GDP (ihracatçı)", ln_gdp_imp="ln GDP (ithalatçı)",
  ln_dist="ln Mesafe", contig="Ortak Sınır",
  rta="RTA Dummy", eu_single_market="AB Tek Pazar",
  crisis_gfc="2009 Krizi", crisis_covid="2020 COVID"
)

cat("\n=== ROBUSTNESS KARŞILAŞTIRMA TABLOSU ===\n")
modelsummary(
  list(
    "TİM+CT\\nPPML-YFE" = m_tim_yfe,
    "BACI\\nPPML-YFE"   = m_baci_yfe,
    "TİM+CT\\nPPML-2FE" = m_tim_2fe,
    "BACI\\nPPML-2FE"   = m_baci_2fe
  ),
  stars       = c("*"=0.1, "**"=0.05, "***"=0.01),
  coef_rename = coef_labels,
  gof_map     = c("nobs","r.squared"),
  output      = file.path(BASE, "tablo_robustness_karsilastirma.html"),
  title       = "Robustness: TİM+Comtrade vs BACI — PPML Gravity (TR-BG-RO-GR, 2000-2024)"
)
modelsummary(
  list(
    "TİM+CT PPML-YFE" = m_tim_yfe,
    "BACI PPML-YFE"   = m_baci_yfe,
    "TİM+CT PPML-2FE" = m_tim_2fe,
    "BACI PPML-2FE"   = m_baci_2fe
  ),
  stars       = c("*"=0.1, "**"=0.05, "***"=0.01),
  coef_rename = coef_labels,
  gof_map     = c("nobs","r.squared")
)
cat("✅ Robustness tablosu kaydedildi: tablo_robustness_karsilastirma.html\n")

# ── 7. KATSAYI KARŞILAŞTIRMA GRAFİĞİ ─────────────────────────────────
# Her iki kaynaktan PPML-2FE katsayılarını görsel olarak karşılaştır
coef_tim  <- coef(m_tim_2fe)
coef_baci <- coef(m_baci_2fe)
se_tim    <- se(m_tim_2fe)
se_baci   <- se(m_baci_2fe)

# Ortak değişkenler
common_vars <- intersect(names(coef_tim), names(coef_baci))
common_vars <- common_vars[common_vars %in% names(coef_labels)]

if (length(common_vars) > 0) {
  plot_df <- data.frame(
    var    = rep(coef_labels[common_vars], 2),
    est    = c(coef_tim[common_vars], coef_baci[common_vars]),
    se     = c(se_tim[common_vars], se_baci[common_vars]),
    kaynak = rep(c("TİM+Comtrade", "BACI"), each=length(common_vars))
  ) %>%
    mutate(
      lower = est - 1.96*se,
      upper = est + 1.96*se
    )

  p_robust <- ggplot(plot_df, aes(x=var, y=est, color=kaynak, shape=kaynak)) +
    geom_hline(yintercept=0, linetype="dashed", color="grey60") +
    geom_pointrange(aes(ymin=lower, ymax=upper),
                    position=position_dodge(0.4), size=0.8) +
    coord_flip() +
    scale_color_manual(values=c("TİM+Comtrade"="steelblue","BACI"="firebrick")) +
    labs(
      title   = "Robustness: TİM+Comtrade vs BACI — PPML-2FE Katsayıları",
      subtitle = "%95 güven aralıkları; dyad-cluster robust SE",
      x=NULL, y="Katsayı tahmini",
      color="Veri Kaynağı", shape="Veri Kaynağı",
      caption="Not: Her iki model yıl + dyad sabit etkileri içermektedir."
    ) +
    theme_minimal(base_size=11) +
    theme(legend.position="bottom", panel.grid.minor=element_blank())

  ggsave(file.path(BASE, "fig09_robustness_karsilastirma.pdf"),
         p_robust, width=9, height=5, dpi=300)
  ggsave(file.path(BASE, "fig09_robustness_karsilastirma.png"),
         p_robust, width=9, height=5, dpi=300)
  cat("✅ Şekil 9 (Robustness karşılaştırma) kaydedildi\n")
}

# ── 8. SAYISAL TUTARLILIK ÖZETİ ───────────────────────────────────────
cat("\n=== KATSAYI TUTARLILIK ÖZETİ (PPML-2FE) ===\n")
cat(sprintf("%-25s %10s %10s %8s\n", "Değişken", "TİM+CT", "BACI", "Tutarlı?"))
cat(strrep("-", 58), "\n")
for (v in common_vars) {
  lbl <- coef_labels[v]
  b1 <- coef_tim[v];  b2 <- coef_baci[v]
  s1 <- se_tim[v];    s2 <- se_baci[v]
  same_sign <- sign(b1) == sign(b2)
  overlap   <- !(b1 + 1.96*s1 < b2 - 1.96*s2 | b2 + 1.96*s2 < b1 - 1.96*s1)
  ok <- if (same_sign & overlap) "✅ Tutarlı" else if (same_sign) "⚠️ Aynı işaret" else "❌ Farklı"
  cat(sprintf("%-25s %10.3f %10.3f %8s\n", lbl, b1, b2, ok))
}
cat("\n✅ Robustness analizi tamamlandi.\n")
cat("Çiktilar:\n")
cat("  tablo_robustness_karsilastirma.html\n")
cat("  fig09_robustness_karsilastirma.pdf/png\n")
