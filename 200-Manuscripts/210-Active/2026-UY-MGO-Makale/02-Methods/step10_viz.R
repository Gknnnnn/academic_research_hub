# SECTION 10: GÖRSELLEŞTİRMELER

library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(viridis)
library(plm)
library(lmtest)

cat("\n=== 10. GÖRSELLEŞTİRMELER ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_pca.rds")

# ---- 10.1 Zaman İçinde REER Oynaklığı ----
cat("--- Grafik 1: REER Oynaklığı (Bölge Bazında) ---\n")

analiz_plot <- analiz %>% drop_na(reer_vol_roll3)

p1 <- ggplot(analiz_plot, aes(x = year, y = reer_vol_roll3, color = region, group = country)) +
  geom_line(alpha = 0.3, linewidth = 0.5) +
  stat_summary(aes(group = region), fun = mean, geom = "line",
               linewidth = 1.5, linetype = "solid") +
  scale_color_viridis_d(option = "plasma", name = "Bölge") +
  labs(title    = "Bölge Bazında Reel Döviz Kuru Oynaklığı",
       subtitle = "İnce çizgiler: ülkeler | Kalın çizgiler: bölge ortalaması",
       x        = "Yıl", y        = "REER Oynaklığı") +
  theme_minimal() +
  theme(legend.position = "bottom")

# ---- 10.2 Hukuk Skoruna Göre İhracat ----
cat("--- Grafik 2: Hukuk vs İhracat Scatter ---\n")

p2 <- ggplot(analiz, aes(x = hukuk, y = ln_ihracat, color = region)) +
  geom_point(alpha = 0.3, size = 1) +
  geom_smooth(method = "lm", se = TRUE, color = "#1e40af", linewidth = 1.2) +
  scale_color_viridis_d(option = "magma", name = "Bölge") +
  labs(title    = "Kurumsal Kalite ve İhracat Performansı",
       x        = "Hukukun Üstünlüğü Endeksi",
       y        = "Log(İhracat)") +
  theme_minimal() +
  theme(legend.position = "bottom")

# ---- 10.3 REER ve İhracat (Hukuk Kalitesine Göre) ----
cat("--- Grafik 3: REER-İhracat İlişkisi (Hukuk Kalitesi Grupları) ---\n")

analiz_grup <- analiz %>%
  drop_na(hukuk, ln_reer, ln_ihracat) %>%
  mutate(hukuk_grup = cut(hukuk,
                          breaks = quantile(hukuk, c(0, 0.33, 0.66, 1), na.rm = TRUE),
                          labels = c("Düşük Hukuk", "Orta Hukuk", "Yüksek Hukuk"),
                          include.lowest = TRUE))

p3 <- ggplot(analiz_grup, aes(x = ln_reer, y = ln_ihracat, color = hukuk_grup)) +
  geom_point(alpha = 0.3, size = 1) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1.2) +
  scale_color_manual(values = c("#ef4444", "#f59e0b", "#10b981"),
                     name = "Kurumsal Kalite") +
  labs(title    = "REER ve İhracat: Kurumsal Kalite Grupları",
       x        = "Log(REER)", y = "Log(İhracat)") +
  theme_minimal() +
  theme(legend.position = "bottom")

# ---- 10.4 Katsayı Görselleştirmesi ----
cat("--- Grafik 4: Model Katsayı Karşılaştırması ---\n")

tryCatch({
  panel_full <- pdata.frame(analiz, index = c("country", "year"))
  model_base_dk <- plm(ln_ihracat ~ ln_reer + ln_gsyh + hukuk + reer_x_hukuk,
                       data = panel_full, model = "within")
  est_dk <- coeftest(model_base_dk, vcov = vcovSCC(model_base_dk, type = "HC3", maxlag = 4))

  koef_df <- data.frame(
    degisken = rownames(est_dk),
    katsayi  = est_dk[, "Estimate"],
    se       = est_dk[, "Std. Error"],
    p        = est_dk[, "Pr(>|t|)"]
  ) %>%
    mutate(
      alt = katsayi - 1.96 * se,
      ust = katsayi + 1.96 * se,
      anlamli = ifelse(p < 0.05, "p < 0.05", "p >= 0.05"),
      degisken = factor(degisken,
                        levels = c("ln_reer", "hukuk", "ln_gsyh", "reer_x_hukuk"),
                        labels = c("Log(REER)", "Hukuk", "Log(GSYH)", "REER x Hukuk"))
    )

  p4 <- ggplot(koef_df, aes(x = degisken, y = katsayi, color = anlamli)) +
    geom_point(size = 4) +
    geom_errorbar(aes(ymin = alt, ymax = ust), width = 0.2, linewidth = 1) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    scale_color_manual(values = c("p < 0.05" = "#10b981", "p >= 0.05" = "#94a3b8"),
                       name = "Anlamlılık") +
    coord_flip() +
    labs(title    = "FE Model Katsayıları (Driscoll-Kraay %95 GA)",
         x        = NULL, y = "Katsayı Tahmini") +
    theme_minimal()

  # Grafikleri birlesik kaydet
  grafik_birlesik <- (p1 + p2) / (p3 + p4) +
    plot_annotation(
      title    = "Döviz Kuru Şokları ve Kurumsal Kalite: Görsel Analiz",
      subtitle = "2000-2022, Gelişmekte Olan Ülkeler"
    )

  ggsave("grafik_tam_analiz.png", grafik_birlesik, width = 16, height = 12, dpi = 200)
  cat("✔ Birleşik grafik kaydedildi: grafik_tam_analiz.png\n")

}, error = function(e) {
  cat("  [UYARI] Grafik birleştirme hatası:", conditionMessage(e), "\n")
})

ggsave("grafik_1_reer_oynakligi.png",   p1, width = 10, height = 6, dpi = 200)
ggsave("grafik_2_hukuk_ihracat.png",    p2, width = 8, height = 6, dpi = 200)
ggsave("grafik_3_reer_kurumsal.png",    p3, width = 8, height = 6, dpi = 200)
