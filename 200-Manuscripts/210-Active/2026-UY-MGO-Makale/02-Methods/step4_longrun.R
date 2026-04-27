# SECTION 4: UZUN DÖNEM TAHMİNLERİ (DOLS & FMOLS)

library(plm)
library(dplyr)
library(lmtest)
library(sandwich)

cat("\n=== 4. UZUN DÖNEM TAHMİNLERİ (DOLS & FMOLS) ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_diff.rds")
panel  <- pdata.frame(analiz, index = c("country", "year"))

# ---- 4.1 FMOLS (Proxy using Pooled with HC Errors) ----
cat("--- FMOLS (Approximation) ---\n")
tryCatch({
  model_fmols <- plm(ln_ihracat ~ ln_reer + ln_gsyh + hukuk + reer_x_hukuk,
                     data  = panel,
                     model = "pooling")

  cat("  FMOLS (Panel Pooled approach):\n")
  res_fmols <- coeftest(model_fmols, vcov = vcovHC(model_fmols, method = "arellano"))
  print(res_fmols)
  saveRDS(res_fmols, "fmols_results.rds")
}, error = function(e) {
  cat("  [UYARI] FMOLS Error:", conditionMessage(e), "\n")
})

# ---- 4.2 DOLS (Dinamik EKK) ----
cat("\n--- DOLS ---\n")

tryCatch({
  analiz_dols <- analiz %>%
    group_by(country) %>%
    mutate(
      # 1 gecikmeli farklar
      lag1_d_reer  = lag(d_ln_reer, 1),
      lag1_d_gsyh  = lag(d_ln_gsyh, 1),
      lag1_d_hukuk = lag(d_hukuk, 1),
      # 1 ileri farklar (lead)
      lead1_d_reer  = lead(d_ln_reer, 1),
      lead1_d_gsyh  = lead(d_ln_gsyh, 1),
      lead1_d_hukuk = lead(d_hukuk, 1)
    ) %>%
    ungroup() %>%
    filter(!is.na(lag1_d_reer) & !is.na(lead1_d_reer))

  panel_dols <- pdata.frame(analiz_dols, index = c("country", "year"))

  model_dols <- plm(
    ln_ihracat ~ ln_reer + ln_gsyh + hukuk + reer_x_hukuk +
      d_ln_reer + lag1_d_reer + lead1_d_reer +
      d_ln_gsyh + lag1_d_gsyh + lead1_d_gsyh +
      d_hukuk   + lag1_d_hukuk + lead1_d_hukuk,
    data   = panel_dols,
    model  = "within",
    effect = "individual"
  )

  cat("  DOLS Model - Uzun Dönem Katsayıları:\n")
  res_dols <- coeftest(model_dols, vcov = vcovSCC(model_dols, type = "HC3", maxlag = 2))
  print(res_dols[1:4, ]) # Only show main coefficients

  saveRDS(res_dols, "dols_results.rds")
}, error = function(e) {
  cat("  [UYARI] DOLS Error:", conditionMessage(e), "\n")
})
