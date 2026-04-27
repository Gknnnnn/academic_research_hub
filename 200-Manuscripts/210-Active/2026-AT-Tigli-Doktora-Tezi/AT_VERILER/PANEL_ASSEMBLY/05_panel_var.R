# ============================================================
# AT Doktora Tezi — Panel VAR / VECM Analizi
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================
# Paketler: install.packages(c("vars","MTS","dplyr","tidyr","readr",
#                              "ggplot2","tseries","urca","tsDyn"))
# Referans:
#   Sims (1980) Econometrica — VAR
#   Johansen (1988) JEEM — VECM
#   Lütkepohl (2005) New Introduction to Multiple Time Series Analysis
# ============================================================

library(dplyr)

# Türkçe karakter için PDF device
if (capabilities("cairo")) options(device = function(...) cairo_pdf(...))
library(tidyr)
library(readr)
library(vars)       # VAR/VECM
library(tseries)    # ADF, PP
library(urca)       # Johansen ko-entegrasyon
library(ggplot2)
library(gridExtra)

# vars paketi select/filter'ı maskeleyebilir — explicit import
select  <- dplyr::select
filter  <- dplyr::filter
mutate  <- dplyr::mutate
rename  <- dplyr::rename
arrange <- dplyr::arrange

# ── 0. YOLLAR ─────────────────────────────────────────────────────────
BASE <- "100-Inbox/AT_VERILER/PANEL_ASSEMBLY"

# ── 1. VERİ YÜKLE ─────────────────────────────────────────────────────
panel <- read_csv(file.path(BASE, "panel_ulke_20260421.csv"),
                  show_col_types = FALSE) %>%
  rename(gdp     = gdp_current_usd,
         pcgdp   = gdp_pc_usd,
         growth  = gdp_growth_pct)

tr_trd <- read_csv(file.path(BASE, "tr_bilateral_trade_20260421.csv"),
                   show_col_types = FALSE)

ct_trd <- read_csv(file.path(BASE, "comtrade_bilateral_20260421.csv"),
                   show_col_types = FALSE)

# ── 2. PANEL VAR İÇİN DEĞİŞKEN HAZIRLAMA ──────────────────────────────
# Yıllık toplam TR ikili ticaret (ihracat + ithalat, Milyar USD)
tr_total <- tr_trd %>%
  group_by(year) %>%
  summarise(
    TR_EXP_total = sum(export_bin_usd, na.rm=TRUE) / 1e6,  # Milyar USD
    TR_IMP_total = sum(import_bin_usd, na.rm=TRUE) / 1e6,
    TR_TRADE_total = (sum(export_bin_usd, na.rm=TRUE) +
                      sum(import_bin_usd, na.rm=TRUE)) / 1e6,
    .groups = "drop"
  )

# Partner ülkelerin GDP büyüme oranları
growth_wide <- panel %>%
  filter(iso3 %in% c("TUR","BGR","ROU","GRC")) %>%
  select(iso3, year, growth) %>%
  pivot_wider(names_from = iso3, values_from = growth,
              names_prefix = "growth_") %>%
  arrange(year)

# Ana VAR değişkenleri
var_data <- growth_wide %>%
  left_join(tr_total, by = "year") %>%
  filter(year >= 2000, year <= 2024) %>%
  arrange(year)

cat("VAR veri boyutu:", nrow(var_data), "gözlem (2000-2024)\n")
cat("Değişkenler:\n")
print(names(var_data))

# ── 3. BİRİM KÖK TESTLERİ (ADF + PP) ─────────────────────────────────
degiskenler <- c("growth_TUR", "growth_BGR", "growth_ROU", "growth_GRC",
                 "TR_TRADE_total")

cat("\n=== BİRİM KÖK TESTLERİ ===\n")
cat(sprintf("%-20s %8s %8s %6s %6s\n", "Değişken", "ADF-stat", "PP-stat",
            "ADF-p", "PP-p"))
cat(strrep("-", 50), "\n")

birim_kok <- lapply(degiskenler, function(var) {
  x <- var_data[[var]]
  x <- x[!is.na(x)]

  adf_res <- tryCatch(adf.test(x, alternative = "stationary"),
                      error = function(e) list(statistic=NA, p.value=NA))
  pp_res  <- tryCatch(pp.test(x, alternative = "stationary"),
                      error = function(e) list(statistic=NA, p.value=NA))

  cat(sprintf("%-20s %8.3f %8.3f %6.3f %6.3f\n",
              var,
              ifelse(is.null(adf_res$statistic), NA, adf_res$statistic),
              ifelse(is.null(pp_res$statistic), NA, pp_res$statistic),
              ifelse(is.null(adf_res$p.value), NA, adf_res$p.value),
              ifelse(is.null(pp_res$p.value), NA, pp_res$p.value)))

  list(var=var, adf_p=adf_res$p.value, pp_p=pp_res$p.value,
       adf_stat=adf_res$statistic, pp_stat=pp_res$statistic)
})
birim_kok_df <- do.call(rbind, lapply(birim_kok, as.data.frame))

# ── 4. JOHANSEN KO-ENTEGRASYON TESTİ ──────────────────────────────────
# GDP büyüme oranları genellikle I(0) ama ticaret seviyeleri I(1) olabilir
# Eğer I(1) ise → Johansen; I(0) ise → VAR seviyelerinde

cat("\n=== JOHANSEN KO-ENTEGRASYON (GDP Büyüme + TR Ticaret) ===\n")

# Seviye değerleri için log-dönüşüm
var_data_log <- var_data %>%
  mutate(
    ln_gdp_TUR = log(panel$gdp[panel$iso3=="TUR" & panel$year %in% 2000:2024]),
    TR_TRADE_bn = TR_TRADE_total
  )

# Johansen testi (büyüme oranları seviyeleri — büyüme = I(0) beklenir)
ts_mat <- as.matrix(var_data[, c("growth_TUR","growth_BGR",
                                  "growth_ROU","growth_GRC")])
ts_mat <- na.omit(ts_mat)

jt <- tryCatch(
  ca.jo(ts_mat, type = "trace", ecdet = "none", K = 2),
  error = function(e) {
    cat("⚠️ Johansen testi başarısız:", conditionMessage(e), "\n"); NULL
  }
)
if (!is.null(jt)) {
  cat("Johansen iz istatistiği (r=0,1,2,3):\n")
  print(summary(jt))
}

# ── 5. VAR LAG SEÇİMİ ─────────────────────────────────────────────────
cat("\n=== VAR LAG SEÇIMI ===\n")

var_mat <- var_data %>%
  select(growth_TUR, growth_BGR, growth_ROU, growth_GRC) %>%
  na.omit()

lag_sel <- VARselect(var_mat, lag.max = 4, type = "const")
cat("AIC optimal lag:", lag_sel$selection["AIC(n)"], "\n")
cat("SC optimal lag: ", lag_sel$selection["SC(n)"], "\n")
cat("HQ optimal lag: ", lag_sel$selection["HQ(n)"], "\n")

# T=25 küçük örneklem → SC kriterini tercih et
# SC=4 aşırı parametreli (4×17=68 parametre, T=21 efektif) → max 2 ile sınırla
p_sc <- as.integer(lag_sel$selection["SC(n)"])
p_optimal <- min(p_sc, 2)
cat("\nSC önerisi:", p_sc, "→ T=25 kısıtı nedeniyle max 2 uygulandı\n")
cat("Kullanılacak lag:", p_optimal, "\n")

# ── 6. PANEL VAR TAHMİNİ ──────────────────────────────────────────────

# M_VAR1: Büyüme oranları
m_var1 <- VAR(var_mat, p = p_optimal, type = "const")
cat("\n=== VAR(", p_optimal, ") ÖZET (Büyüme Oranları) ===\n")
print(summary(m_var1))

# M_VAR2: Ticaret dahil genişletilmiş VAR
var_mat2 <- var_data %>%
  select(growth_TUR, growth_BGR, growth_ROU, growth_GRC, TR_TRADE_total) %>%
  na.omit()

lag_sel2 <- VARselect(var_mat2, lag.max = 3, type = "const")
p2 <- as.integer(lag_sel2$selection["SC(n)"])

m_var2 <- VAR(var_mat2, p = max(p2, 1), type = "const")
cat("\n=== VAR(", max(p2,1), ") ÖZET (Büyüme + TR Ticaret) ===\n")
print(summary(m_var2))

# ── 7. GRANGER NEDENSELLİK ────────────────────────────────────────────
cat("\n=== GRANGER NEDENSELLİK TESTLERİ ===\n")
cat("H0: x, y'yi Granger nedenselleştirmiyor\n\n")

# Büyüme VAR'ı — çiftler
pair_tests <- list(
  c("growth_BGR", "growth_TUR"),
  c("growth_ROU", "growth_TUR"),
  c("growth_GRC", "growth_TUR"),
  c("growth_TUR", "growth_BGR"),
  c("growth_TUR", "growth_ROU"),
  c("growth_TUR", "growth_GRC")
)

granger_sonuc <- lapply(pair_tests, function(pair) {
  res <- tryCatch(
    causality(m_var1, cause = pair[1]),
    error = function(e) NULL
  )
  if (!is.null(res)) {
    cat(sprintf("%-20s → %-20s : F=%.3f  p=%.4f %s\n",
                pair[1], pair[2],
                res$Granger$statistic,
                res$Granger$p.value,
                ifelse(res$Granger$p.value < 0.05, "***",
                       ifelse(res$Granger$p.value < 0.10, "*", ""))))
    list(cause=pair[1], effect=pair[2],
         F=res$Granger$statistic, p=res$Granger$p.value)
  }
})

# Ticaret → Büyüme nedenselliği
if (!is.null(m_var2)) {
  cat("\n-- TR Ticaret → Büyüme? --\n")
  res_trd <- tryCatch(
    causality(m_var2, cause = "TR_TRADE_total"),
    error = function(e) NULL
  )
  if (!is.null(res_trd)) {
    cat(sprintf("TR_TRADE → Büyüme: F=%.3f  p=%.4f %s\n",
                res_trd$Granger$statistic,
                res_trd$Granger$p.value,
                ifelse(res_trd$Granger$p.value < 0.05, "***",
                       ifelse(res_trd$Granger$p.value < 0.10, "*", ""))))
  }
}

# ── 8. ETKI TEPKİ FONKSİYONLARI (IRF) ────────────────────────────────
cat("\n=== IRF — Etki Tepki Analizi ===\n")

# m_var1 üzerinden IRF: BGR şoku → TUR büyümesi
irf_bgr_tur <- irf(m_var1, impulse = "growth_BGR", response = "growth_TUR",
                   n.ahead = 10, boot = TRUE, ci = 0.90, runs = 500)

irf_rou_tur <- irf(m_var1, impulse = "growth_ROU", response = "growth_TUR",
                   n.ahead = 10, boot = TRUE, ci = 0.90, runs = 500)

irf_grc_tur <- irf(m_var1, impulse = "growth_GRC", response = "growth_TUR",
                   n.ahead = 10, boot = TRUE, ci = 0.90, runs = 500)

# IRF çiz
plot_irf <- function(irf_obj, title) {
  h <- length(irf_obj$irf[[1]])
  df <- data.frame(
    horizon = 0:(h-1),
    irf     = as.numeric(irf_obj$irf[[1]]),
    lower   = as.numeric(irf_obj$Lower[[1]]),
    upper   = as.numeric(irf_obj$Upper[[1]])
  )
  ggplot(df, aes(x=horizon)) +
    geom_ribbon(aes(ymin=lower, ymax=upper), fill="steelblue", alpha=0.2) +
    geom_line(aes(y=irf), color="steelblue", linewidth=0.9) +
    geom_hline(yintercept=0, linetype="dashed", color="grey50") +
    scale_x_continuous(breaks=0:10) +
    labs(title=title,
         x="Dönem (Yıl)", y="Büyüme Oranı Tepkisi (pp)",
         caption="Not: %90 bootstrap güven bandı (500 tekrar)") +
    theme_minimal(base_size=11) +
    theme(panel.grid.minor=element_blank())
}

p_irf1 <- plot_irf(irf_bgr_tur, "Bulgaristan Büyümesi → Türkiye Büyümesi (IRF)")
p_irf2 <- plot_irf(irf_rou_tur, "Romanya Büyümesi → Türkiye Büyümesi (IRF)")
p_irf3 <- plot_irf(irf_grc_tur, "Yunanistan Büyümesi → Türkiye Büyümesi (IRF)")

# m_var1 TR → partner IRFs
irf_tur_bgr <- irf(m_var1, impulse = "growth_TUR", response = "growth_BGR",
                   n.ahead = 10, boot = TRUE, ci = 0.90, runs = 500)
p_irf4 <- plot_irf(irf_tur_bgr, "Türkiye Büyümesi → Bulgaristan Büyümesi (IRF)")

ggsave(file.path(BASE, "fig03_irf_partner_tur.pdf"),
       arrangeGrob(p_irf1, p_irf2, p_irf3, ncol=1),
       width=8, height=12, dpi=300)
ggsave(file.path(BASE, "fig03_irf_partner_tur.png"),
       arrangeGrob(p_irf1, p_irf2, p_irf3, ncol=1),
       width=8, height=12, dpi=300)
cat("✅ Şekil 3 (IRF) kaydedildi\n")

# ── 9. VARYANS AYRIŞIMI (FEVD) ────────────────────────────────────────
cat("\n=== VARYANS AYRIŞIMI (FEVD) ===\n")
fevd_res <- fevd(m_var1, n.ahead = 10)
cat("TUR büyümesi varyans ayrışımı (10 dönem):\n")
print(round(fevd_res$growth_TUR * 100, 2))

# FEVD görselleştir
fevd_df <- as.data.frame(fevd_res$growth_TUR * 100) %>%
  mutate(horizon = row_number()) %>%
  pivot_longer(-horizon, names_to = "kaynak", values_to = "pct") %>%
  mutate(kaynak = recode(kaynak,
                         growth_TUR = "Türkiye",
                         growth_BGR = "Bulgaristan",
                         growth_ROU = "Romanya",
                         growth_GRC = "Yunanistan"))

p_fevd <- ggplot(fevd_df, aes(x=horizon, y=pct, fill=kaynak)) +
  geom_area(alpha=0.8) +
  scale_fill_viridis_d(option="turbo") +
  scale_x_continuous(breaks=1:10) +
  labs(
    title = "Türkiye Büyümesi — Varyans Ayrışımı (FEVD)",
    subtitle = "Hangi ülkenin büyümesi Türkiye'nin büyüme varyansını açıklıyor?",
    x = "Dönem (Yıl)", y = "% Açıklama", fill = "Kaynak",
    caption = "Kaynak: VAR(p) modeli — GDP büyüme oranları"
  ) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank())

ggsave(file.path(BASE, "fig04_fevd_tur_buyume.pdf"),
       p_fevd, width=9, height=5, dpi=300)
ggsave(file.path(BASE, "fig04_fevd_tur_buyume.png"),
       p_fevd, width=9, height=5, dpi=300)
cat("✅ Şekil 4 (FEVD) kaydedildi\n")

# ── 10. VAR TANI TESTLERİ ─────────────────────────────────────────────
cat("\n=== VAR TANI TESTLERİ ===\n")

# Otokorelasyon testi (Portmanteau)
pt_test <- serial.test(m_var1, lags.pt = 10, type = "PT.asymptotic")
cat("Portmanteau (H0: otokorelasyon yok):\n")
print(pt_test)

# Normallik testi (Jarque-Bera)
jb_test <- normality.test(m_var1)
cat("\nJarque-Bera normallik testi:\n")
print(jb_test)

# Heteroskedastisite (ARCH-LM)
arch_test <- arch.test(m_var1)
cat("\nARCH-LM testi:\n")
print(arch_test)

# Kararlılık (tüm kökler birim çember içinde mi?)
roots_var <- roots(m_var1)
cat("\nVAR köklerinin modülü (tümü < 1 olmalı):\n")
print(round(roots_var, 4))
cat("VAR kararlı mı?", all(roots_var < 1), "\n")

# ── 11. BÜYÜME KARŞILAŞTIRMA GRAFİĞİ ─────────────────────────────────
p5 <- panel %>%
  filter(iso3 %in% c("TUR","BGR","ROU","GRC"), !is.na(growth)) %>%
  mutate(ulke = recode(iso3,
                       TUR="Türkiye", BGR="Bulgaristan",
                       ROU="Romanya", GRC="Yunanistan")) %>%
  ggplot(aes(x=year, y=growth, color=ulke, group=ulke)) +
  geom_line(linewidth=0.8) +
  geom_point(size=1.5) +
  geom_hline(yintercept=0, linetype="dashed", color="grey60") +
  geom_vline(xintercept=c(2007,2009,2020), linetype="dotted",
             color="grey40", linewidth=0.4) +
  annotate("text", x=2007.2, y=12, label="AB genişlemesi",
           size=2.5, hjust=0, color="grey40") +
  annotate("text", x=2009.2, y=10, label="GFC",
           size=2.5, hjust=0, color="grey40") +
  annotate("text", x=2020.2, y=8, label="COVID",
           size=2.5, hjust=0, color="grey40") +
  scale_color_viridis_d(option="turbo") +
  labs(
    title = "TR-BG-RO-GR GDP Büyüme Oranları (2000-2024)",
    subtitle = "% yıllık; dikey çizgiler: 2007 AB genişlemesi, 2009 GFC, 2020 COVID",
    x = NULL, y = "GDP Büyüme (%)", color = NULL,
    caption = "Kaynak: World Bank WDI"
  ) +
  theme_minimal(base_size=11) +
  theme(legend.position="bottom",
        panel.grid.minor=element_blank())

ggsave(file.path(BASE, "fig05_buyume_trend.pdf"), p5, width=10, height=5, dpi=300)
ggsave(file.path(BASE, "fig05_buyume_trend.png"), p5, width=10, height=5, dpi=300)
cat("✅ Şekil 5 (Büyüme trend) kaydedildi\n")

# ── 12. ÖZET ──────────────────────────────────────────────────────────
cat("\n=== VAR ANALİZİ TAMAMLANDI ===\n")
cat("Çıktılar:\n")
cat("  fig03_irf_partner_tur.pdf/png   — IRF (3 partner → TUR)\n")
cat("  fig04_fevd_tur_buyume.pdf/png   — Varyans ayrışımı\n")
cat("  fig05_buyume_trend.pdf/png      — Büyüme trend grafiği\n")
cat("\nYorumlanacak ana bulgular:\n")
cat("  1. Granger nedensellik: hangi ülke hangi yönde?\n")
cat("  2. FEVD: Türkiye büyümesini en çok hangi ülke etkiliyor?\n")
cat("  3. IRF: Şokların etkisi kaç yılda sönümleniyor?\n")
cat("  4. AB genişlemesi (2007) büyüme ilişkisini değiştirdi mi?\n")
cat("     → M4 extended modelde post_eu_bg_ro dummies incele\n")
