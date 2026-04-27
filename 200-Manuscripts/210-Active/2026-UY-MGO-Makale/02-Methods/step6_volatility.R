# SECTION 6: DÖVİZ KURU OYNAKLIĞI

library(dplyr)
library(tidyr)
library(zoo)
library(rugarch)
library(plm)
library(lmtest)

cat("\n=== 6. DÖVİZ KURU OYNAKLIGI ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_diff.rds")

# ---- 6.1 Rolling Standart Sapma (3 Yıllık Pencere) ----
cat("--- Yöntem A: Rolling Standart Sapma (3 yıllık pencere) ---\n")

analiz <- analiz %>%
  group_by(country) %>%
  arrange(year) %>%
  mutate(
    reer_vol_roll3 = rollapply(reer, width = 3, FUN = sd, fill = NA, align = "right")
  ) %>%
  ungroup()

cat("  reer_vol_roll3 değişkeni oluşturuldu.\n")

# ---- 6.2 GARCH(1,1) ile Oynaklık Tahmini ----
cat("\n--- Yöntem B: GARCH(1,1) Oynaklık Tahmini ---\n")

analiz$reer_vol_garch <- NA_real_
ulkeler <- unique(analiz$country)
garch_basarili <- 0

for (ulke in ulkeler) {
  ulke_veri <- analiz %>%
    filter(country == ulke) %>%
    arrange(year) %>%
    pull(ln_reer)

  if (length(ulke_veri) < 10 || any(is.na(ulke_veri))) next

  tryCatch({
    spec <- ugarchspec(
      variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
      mean.model     = list(armaOrder = c(0, 0), include.mean = TRUE),
      distribution.model = "norm"
    )
    fit <- ugarchfit(spec = spec, data = ulke_veri, solver = "hybrid")
    vol <- as.numeric(sigma(fit))
    
    ulke_idx <- which(analiz$country == ulke)
    if (length(vol) == length(ulke_idx)) {
      analiz$reer_vol_garch[ulke_idx] <- vol
      garch_basarili <- garch_basarili + 1
    }
  }, error = function(e) NULL)
}

cat("  GARCH başarıyla tahmin edilen ülke sayısı:", garch_basarili, "/", length(ulkeler), "\n")

# ---- 6.3 Oynaklık Değişkeni ile Model ----
cat("\n--- Oynaklık Değişkeni ile FE Modeli ---\n")

analiz_vol <- analiz %>%
  drop_na(reer_vol_roll3, ln_ihracat, ln_gsyh, hukuk) %>%
  mutate(
    ln_reer_vol  = log(reer_vol_roll3 + 1),
    vol_x_hukuk  = ln_reer_vol * hukuk
  )

panel_vol <- pdata.frame(analiz_vol, index = c("country", "year"))

tryCatch({
  model_vol <- plm(ln_ihracat ~ ln_reer_vol + ln_gsyh + hukuk + vol_x_hukuk,
                   data = panel_vol, model = "within")

  cat("  Model (Oynaklık ile):\n")
  res_vol <- coeftest(model_vol, vcov = vcovSCC(model_vol, type = "HC3", maxlag = 4))
  print(res_vol)
  saveRDS(res_vol, "volatility_model_results.rds")
}, error = function(e) {
  cat("  [UYARI] Volatility Model Error:", conditionMessage(e), "\n")
})

saveRDS(analiz, "analiz_data_vol.rds")
