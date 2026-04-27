# SECTION 7: PANEL EŞİK REGRESYONU

library(dplyr)
library(tidyr)
library(plm)
library(lmtest)
library(ggplot2)

cat("\n=== 7. PANEL EŞİK REGRESYONU ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_vol.rds")

# Manuel eşik arama
cat("--- Manuel Eşik Analizi ---\n")

esik_adaylari <- quantile(analiz$hukuk, probs = seq(0.2, 0.8, by = 0.05), na.rm = TRUE)
esik_RSS <- numeric(length(esik_adaylari))

analiz_esik <- analiz %>% drop_na(ln_ihracat, ln_reer, ln_gsyh, hukuk)
panel_esik  <- pdata.frame(analiz_esik, index = c("country", "year"))

for (i in seq_along(esik_adaylari)) {
  esik_deger <- esik_adaylari[i]

  analiz_esik_tmp <- analiz_esik %>%
    mutate(
      D_asagi  = as.numeric(hukuk <  esik_deger),
      D_yukari = as.numeric(hukuk >= esik_deger),
      reer_asagi  = ln_reer * D_asagi,
      reer_yukari = ln_reer * D_yukari
    )

  panel_tmp <- pdata.frame(analiz_esik_tmp, index = c("country", "year"))

  tryCatch({
    m <- plm(ln_ihracat ~ reer_asagi + reer_yukari + ln_gsyh,
             data = panel_tmp, model = "within")
    esik_RSS[i] <- sum(residuals(m)^2)
  }, error = function(e) {
    esik_RSS[i] <- NA
  })
}

# En iyi eşik değeri
esik_en_iyi_idx <- which.min(esik_RSS)
esik_en_iyi     <- esik_adaylari[esik_en_iyi_idx]

cat("  Optimal eşik değeri (RSS minimizasyonu):", round(esik_en_iyi, 3), "\n")

# ---- Eşik Modelini Tahmin Et ----
cat("--- Eşik Modelinin Tahmini ---\n")

analiz_esik_final <- analiz_esik %>%
  mutate(
    D_dusuk_hukuk = as.numeric(hukuk <  esik_en_iyi),
    D_yuksek_hukuk = as.numeric(hukuk >= esik_en_iyi),
    reer_dusuk  = ln_reer * D_dusuk_hukuk,
    reer_yuksek = ln_reer * D_yuksek_hukuk
  )

panel_esik_final <- pdata.frame(analiz_esik_final, index = c("country", "year"))

tryCatch({
  model_esik_final <- plm(
    ln_ihracat ~ reer_dusuk + reer_yuksek + ln_gsyh + hukuk,
    data   = panel_esik_final,
    model  = "within"
  )

  cat("  Eşik Model Sonuçları (Driscoll-Kraay):\n")
  res_esik <- coeftest(model_esik_final, vcov = vcovSCC(model_esik_final, type = "HC3", maxlag = 4))
  print(res_esik)
  saveRDS(res_esik, "threshold_model_results.rds")
}, error = function(e) {
  cat("  [UYARI] Threshold Model Error:", conditionMessage(e), "\n")
})

# ---- Eşik RSS Grafiği ----
esik_df <- data.frame(
  esik  = esik_adaylari,
  RSS   = esik_RSS
)

p_esik <- ggplot(esik_df, aes(x = esik, y = RSS)) +
  geom_line(color = "#2563eb", linewidth = 1.2) +
  geom_point(color = "#2563eb", size = 2) +
  geom_vline(xintercept = esik_en_iyi, linetype = "dashed",
             color = "#dc2626", linewidth = 1) +
  labs(title    = "Eşik Regresyonu: RSS - Eşik Değeri İlişkisi",
       x        = "Hukuk Eşik Değeri",
       y        = "Artıkların Kareler Toplamı (RSS)") +
  theme_minimal()

ggsave("esik_RSS_grafik.png", p_esik, width = 8, height = 5, dpi = 200)
cat("\n✔ Eşik RSS grafiği kaydedildi: esik_RSS_grafik.png\n")

saveRDS(esik_en_iyi, "optimal_threshold.rds")
