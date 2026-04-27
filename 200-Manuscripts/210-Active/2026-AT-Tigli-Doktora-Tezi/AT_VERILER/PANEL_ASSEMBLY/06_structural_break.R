# ============================================================
# AT Doktora Tezi — Yapısal Kırılma & Eşik Analizi
# Abdülkadir Tığlı | Katkı: Res. Asst. Dr. M. Gökhan Özdemir
# Tarih: 2026-04-21
# ============================================================
# Paketler: install.packages(c("strucchange","tsDyn","dplyr","tidyr",
#                              "readr","ggplot2"))
# Referans:
#   Bai & Perron (1998, 2003) Econometrica — çoklu kırılma
#   Zivot & Andrews (1992, JBES) — tek kırılmalı birim kök
# ============================================================

library(dplyr)

# Türkçe karakter için PDF device
if (capabilities("cairo")) options(device = function(...) cairo_pdf(...))
library(tidyr)
library(readr)
library(strucchange)   # Bai-Perron, CUSUM, Chow
library(ggplot2)

# ── 0. YOLLAR ─────────────────────────────────────────────────────────
BASE <- "100-Inbox/AT_VERILER/PANEL_ASSEMBLY"

# ── 1. VERİ ───────────────────────────────────────────────────────────
panel <- read_csv(file.path(BASE, "panel_ulke_20260421.csv"),
                  show_col_types = FALSE) %>%
  rename(gdp    = gdp_current_usd,
         pcgdp  = gdp_pc_usd,
         growth = gdp_growth_pct)

tr_trd <- read_csv(file.path(BASE, "tr_bilateral_trade_20260421.csv"),
                   show_col_types = FALSE)

# TR toplam ticaret zaman serisi
tr_ts <- tr_trd %>%
  group_by(year) %>%
  summarise(trade_bn = sum(export_bin_usd + import_bin_usd, na.rm=TRUE) / 1e6,
            .groups = "drop") %>%
  arrange(year)

# TUR büyüme zaman serisi
tur_growth <- panel %>%
  filter(iso3 == "TUR") %>%
  select(year, growth) %>%
  arrange(year)

# ── 2. CUSUM STABİLİTE TESTİ ──────────────────────────────────────────
cat("=== CUSUM STABİLİTE TESTİ ===\n")
cat("H0: Ticaret-GDP büyüme ilişkisi yapısal olarak kararlıdır\n\n")

# TR ticaret ~ TUR büyüme regresyonu
cusum_df <- tur_growth %>%
  left_join(tr_ts, by="year") %>%
  na.omit()

m_cusum <- lm(trade_bn ~ growth, data = cusum_df)

# Zaman sıralı regresyon residualları
ocus <- efp(trade_bn ~ growth, data=cusum_df, type="OLS-CUSUM")
cat("OLS-CUSUM istatistiği:\n")
print(sctest(ocus))

mfluc <- efp(trade_bn ~ growth, data=cusum_df, type="fluctuation")
cat("Fluktuasyon testi:\n")
print(sctest(mfluc))

# ── 3. BAI-PERRON ÇOKLU YAPISAL KIRILMA ───────────────────────────────
cat("\n=== BAI-PERRON ÇOKLU YAPISAL KIRILMA ===\n")
cat("Bai & Perron (2003): TR ticaret serisinde kırılma tarihleri\n\n")

# TR ticaret zaman serisi üzerinde kırılma noktası ara
bp_trade <- breakpoints(trade_bn ~ 1, data=cusum_df, h=0.15)
cat("Optimal kırılma sayısı (BIC):\n")
print(summary(bp_trade))

bp_opt <- breakpoints(bp_trade)
cat("\nOptimal kırılma noktaları (yıl):\n")
if (!is.na(bp_opt$breakpoints[1])) {
  cat(cusum_df$year[bp_opt$breakpoints], "\n")
} else {
  cat("Kırılma bulunamadı\n")
}

# Kırılma güven aralıkları
ci_bp <- confint(bp_trade)
print(ci_bp)

# ── 4. CHOW TESTİ (A PRİORİ KIRILMALAR) ──────────────────────────────
cat("\n=== CHOW TESTİ (A PRİORİ KIRILMA NOKTALARI) ===\n")

# Test edilecek kırılma yılları: 2007 (AB), 2009 (GFC), 2018 (TL krizi), 2020 (COVID)
kirilma_yillari <- c(2007, 2009, 2018, 2020)

for (yr in kirilma_yillari) {
  idx <- which(cusum_df$year == yr)
  if (length(idx) == 0) { cat(yr, ": veri yok\n"); next }

  res <- tryCatch(
    sctest(trade_bn ~ growth, data=cusum_df,
           type="Chow", point=idx),
    error=function(e) NULL
  )
  if (!is.null(res)) {
    cat(sprintf("  %d: F=%.3f  p=%.4f  %s\n", yr,
                res$statistic, res$p.value,
                ifelse(res$p.value < 0.01, "***",
                       ifelse(res$p.value < 0.05, "**",
                              ifelse(res$p.value < 0.10, "*", "")))))
  }
}

# ── 5. DÖNEM KARSITIRMA: PRE vs POST AB GENİŞLEMESİ ──────────────────
cat("\n=== DÖNEM ANALİZİ: ÖNCESİ vs SONRASI (2007 AB Genişlemesi) ===\n")

# Gravity verisi — 04_gravity_ppml.R çalıştırılmışsa mevcut
# Burada basit panel t-testi
ticaret_donems <- tr_trd %>%
  mutate(donem = if_else(year < 2007, "Pre-AB (2000-2006)", "Post-AB (2007-2024)")) %>%
  group_by(donem, partner_iso) %>%
  summarise(
    ort_ihracat = mean(export_bin_usd, na.rm=TRUE),
    ort_ithalat = mean(import_bin_usd, na.rm=TRUE),
    buyume_ort  = mean(export_bin_usd + import_bin_usd, na.rm=TRUE),
    .groups="drop"
  )

cat("Dönem ortalama ticaret (bin USD):\n")
print(ticaret_donems)

# BGR ve ROU için pre-post karşılaştırma
for (partner in c("BGR","ROU")) {
  pre  <- tr_trd %>% filter(partner_iso==partner, year < 2007) %>%
    pull(export_bin_usd)
  post <- tr_trd %>% filter(partner_iso==partner, year >= 2007) %>%
    pull(export_bin_usd)

  if (length(pre) > 0 & length(post) > 0) {
    tt <- t.test(post, pre)
    cat(sprintf("\nTUR→%s İhracat pre-post t-testi:\n", partner))
    cat(sprintf("  Öncesi ort: %.1f  Sonrası ort: %.1f\n",
                mean(pre, na.rm=TRUE), mean(post, na.rm=TRUE)))
    cat(sprintf("  t=%.3f  df=%.1f  p=%.4f  %s\n",
                tt$statistic, tt$parameter, tt$p.value,
                ifelse(tt$p.value < 0.05, "Anlamlı artış ✅", "Anlamsız")))
  }
}

# ── 6. GÖRSELLEŞTIRME ─────────────────────────────────────────────────
# 6a. Kırılma grafikleri — BP + Chow tarihleri
p6 <- cusum_df %>%
  ggplot(aes(x=year, y=trade_bn)) +
  geom_line(color="steelblue", linewidth=0.9) +
  geom_point(size=1.8, color="steelblue") +
  # Kırılma şüphesi olan yıllar
  geom_vline(xintercept=c(2007,2009,2018,2020),
             linetype="dashed", color="firebrick", linewidth=0.5) +
  annotate("rect", xmin=2007, xmax=2007.2, ymin=-Inf, ymax=Inf,
           fill="transparent") +
  annotate("text", x=c(2007.3,2009.3,2018.3,2020.3),
           y=max(cusum_df$trade_bn, na.rm=TRUE)*0.95,
           label=c("AB Gen.", "GFC", "TL Krizi", "COVID"),
           size=2.8, hjust=0, color="firebrick") +
  labs(
    title = "TR Toplam İkili Ticaret (2000-2024) — Yapısal Kırılma Noktaları",
    subtitle = "Bai-Perron çoklu kırılma + Chow testi a priori tarihleri",
    x = NULL, y = "Milyar USD", caption = "Kaynak: TİM + UN Comtrade"
  ) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank())

ggsave(file.path(BASE, "fig06_structural_break.pdf"), p6, width=10, height=5, dpi=300)
ggsave(file.path(BASE, "fig06_structural_break.png"), p6, width=10, height=5, dpi=300)
cat("✅ Şekil 6 (Yapısal kırılma) kaydedildi\n")

# 6b. CUSUM grafiği
pdf(file.path(BASE, "fig07_cusum.pdf"), width=9, height=5)
plot(ocus, main="OLS-CUSUM — TR Ticaret-Büyüme İlişkisi Kararlılığı",
     ylab="CUSUM", xlab="Yıl")
dev.off()
cat("✅ Şekil 7 (CUSUM) kaydedildi\n")

# ── 7. BÜTÜNLEŞIK ÖZET ────────────────────────────────────────────────
cat("\n=== YAPISAL KIRILMA ANALİZİ TAMAMLANDI ===\n")
cat("Çıktılar:\n")
cat("  fig06_structural_break.pdf/png  — TR ticaret kırılma noktaları\n")
cat("  fig07_cusum.pdf                 — OLS-CUSUM kararlılık testi\n")
cat("\nTemel bulgular için kontrol et:\n")
cat("  1. Bai-Perron optimal kırılma tarihleri teorik yıllarla uyuşuyor mu?\n")
cat("  2. Chow testi: 2007 AB genişlemesi istatistiksel olarak anlamlı mı?\n")
cat("  3. CUSUM sınır dışı: hangi dönemlerde ilişki değişti?\n")
cat("  4. Pre-Post 2007 ortalama ticaret anlamlı artış mı gösteriyor?\n")
