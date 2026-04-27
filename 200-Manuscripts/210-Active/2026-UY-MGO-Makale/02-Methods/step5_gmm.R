# SECTION 5: DİNAMİK PANEL GMM

library(plm)
library(dplyr)
library(stargazer)

cat("\n=== 5. DİNAMİK PANEL GMM ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_diff.rds")
panel  <- pdata.frame(analiz, index = c("country", "year"))

# ---- 5.1 Arellano-Bond (Fark GMM) ----
cat("--- Fark GMM (Arellano-Bond, 1991) ---\n")

tryCatch({
  model_ab <- pgmm(
    ln_ihracat ~ lag(ln_ihracat, 1) + ln_reer + ln_gsyh + hukuk + reer_x_hukuk |
      lag(ln_ihracat, 2:4),
    data     = panel,
    effect   = "twoways",
    model    = "twosteps",
    collapse = TRUE
  )

  cat("Arellano-Bond Fark GMM Sonuçları (Summary):\n")
  print(summary(model_ab, robust = TRUE))
  saveRDS(model_ab, "gmm_ab_model.rds")
}, error = function(e) {
  cat("  [UYARI] Arellano-Bond GMM Error:", conditionMessage(e), "\n")
})

# ---- 5.2 Blundell-Bond (Sistem GMM) ----
cat("\n--- Sistem GMM (Blundell-Bond, 1998) ---\n")

tryCatch({
  model_bb <- pgmm(
    ln_ihracat ~ lag(ln_ihracat, 1) + ln_reer + ln_gsyh + hukuk + reer_x_hukuk |
      lag(ln_ihracat, 2:3),
    data     = panel,
    effect   = "twoways",
    model    = "twosteps",
    transformation = "ld",
    collapse = TRUE
  )

  cat("Blundell-Bond Sistem GMM Sonuçları (Summary):\n")
  print(summary(model_bb, robust = TRUE))
  saveRDS(model_bb, "gmm_bb_model.rds")
}, error = function(e) {
  cat("  [UYARI] Sistem GMM Error:", conditionMessage(e), "\n")
})
