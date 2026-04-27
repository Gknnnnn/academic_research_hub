# SECTION 9: BİLEŞİK KURUMSAL ENDEKS (PCA)

library(dplyr)
library(tidyr)
library(FactoMineR)
library(factoextra)
library(plm)
library(lmtest)
library(stargazer)

cat("\n=== 9. BİLEŞİK KURUMSAL ENDEKS (PCA) ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_vol.rds")

# PCA için veri hazırlığı
pca_veri <- analiz %>%
  select(country, year, hukuk, regulasyon) %>%
  drop_na()

cat("PCA için gözlem sayısı:", nrow(pca_veri), "\n")

tryCatch({
  # PCA hesapla
  pca_sonuc <- PCA(
    pca_veri %>% select(hukuk, regulasyon),
    scale.unit = TRUE,
    ncp        = 2,
    graph      = FALSE
  )

  cat("\n--- PCA Varyans Açıklama Oranları ---\n")
  print(pca_sonuc$eig)

  # İlk bileşeni kurumsal endeks olarak kullan
  pca_veri$kurumsal_endeks <- pca_sonuc$ind$coord[, 1]

  # PCA bileplot
  p_pca <- fviz_pca_biplot(
    pca_sonuc,
    label = "var",
    col.var = "#2563eb",
    col.ind = "#94a3b8",
    alpha.ind = 0.3,
    title = "PCA: Kurumsal Değişkenler Bileplot"
  )
  ggsave("pca_biplot.png", p_pca, width = 7, height = 6, dpi = 200)

  # Endeksi ana veriye birleştir
  analiz_pca_full <- analiz %>%
    left_join(pca_veri %>% select(country, year, kurumsal_endeks),
              by = c("country", "year"))

  # ---- Bileşik Endeks ile Model ----
  cat("\n--- Bileşik Endeks ile FE Modeli ---\n")

  analiz_model_pca <- analiz_pca_full %>%
    drop_na(ln_ihracat, ln_reer, ln_gsyh, kurumsal_endeks) %>%
    mutate(reer_x_endeks = ln_reer * kurumsal_endeks)

  panel_pca <- pdata.frame(analiz_model_pca, index = c("country", "year"))

  model_pca <- plm(ln_ihracat ~ ln_reer + ln_gsyh + kurumsal_endeks + reer_x_endeks,
                   data = panel_pca, model = "within")

  cat("  PCA Endeks Modeli (Driscoll-Kraay):\n")
  res_pca <- coeftest(model_pca, vcov = vcovSCC(model_pca, type = "HC3", maxlag = 4))
  print(res_pca)

  saveRDS(res_pca, "pca_model_results.rds")
  saveRDS(analiz_pca_full, "analiz_data_pca.rds")

}, error = function(e) {
  cat("  [UYARI] PCA Error:", conditionMessage(e), "\n")
})
