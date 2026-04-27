# SECTION 8: BÖLGESEL ALT-GRUP ANALİZLERİ

library(dplyr)
library(tidyr)
library(plm)
library(lmtest)
library(ggplot2)

cat("\n=== 8. BÖLGESEL ALT-GRUP ANALİZLERİ ===\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data_vol.rds")

bolge_listesi <- unique(analiz$region)
cat("Analize dahil edilen bölgeler:\n")
print(bolge_listesi)

bolge_modelleri   <- list()
bolge_sonuclari   <- data.frame()

for (bolge in bolge_listesi) {
  cat("\n---", bolge, "---\n")

  bolge_veri <- analiz %>%
    filter(region == bolge) %>%
    drop_na(ln_ihracat, ln_reer, ln_gsyh, hukuk)

  n_ulke <- length(unique(bolge_veri$country))
  n_gozlem <- nrow(bolge_veri)

  cat("  Ülke sayısı:", n_ulke, "| Gözlem:", n_gozlem, "\n")

  if (n_ulke < 3 || n_gozlem < 20) {
    cat("  [UYARI] Yetersiz gözlem, atlanıyor.\n")
    next
  }

  panel_bolge <- pdata.frame(bolge_veri, index = c("country", "year"))

  tryCatch({
    model_bolge <- plm(ln_ihracat ~ ln_reer + ln_gsyh + hukuk + reer_x_hukuk,
                       data   = panel_bolge,
                       model  = "within")

    est <- coeftest(model_bolge, vcov = vcovSCC(model_bolge, type = "HC3", maxlag = 2))

    # Etkilesim katsayisi
    estkisim_idx <- which(rownames(est) == "reer_x_hukuk")
    if (length(estkisim_idx) > 0) {
      bolge_sonuclari <- rbind(bolge_sonuclari, data.frame(
        bolge       = bolge,
        n_ulke      = n_ulke,
        n_gozlem    = n_gozlem,
        reer_kat    = round(est["ln_reer",     "Estimate"], 3),
        hukuk_kat   = round(est["hukuk",       "Estimate"], 3),
        gsyh_kat    = round(est["ln_gsyh",     "Estimate"], 3),
        etkilesim   = round(est["reer_x_hukuk","Estimate"], 3),
        p_etkilesim = round(est["reer_x_hukuk","Pr(>|t|)"], 3)
      ))
    }

    bolge_modelleri[[bolge]] <- model_bolge
  }, error = function(e) {
    cat("  [UYARI] Error for", bolge, ":", conditionMessage(e), "\n")
  })
}

cat("\n--- Bölgesel Karşılaştırma Özeti ---\n")
print(bolge_sonuclari)

# ---- Bölgesel Etkileşim Katsayısı Grafiği ----
if (nrow(bolge_sonuclari) > 0) {
  p_bolge <- ggplot(bolge_sonuclari, aes(x = reorder(bolge, etkilesim), y = etkilesim,
                                          fill = p_etkilesim < 0.05)) +
    geom_col(width = 0.6) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
    scale_fill_manual(values = c("TRUE" = "#10b981", "FALSE" = "#94a3b8"),
                      labels = c("TRUE" = "p < 0.05", "FALSE" = "p >= 0.05"),
                      name = "Significance") +
    coord_flip() +
    labs(title    = "Bölgesel Alt-Grup Analizi: REER × Hukuk Etkileşimi",
         x        = "Bölge",
         y        = "Katsayı") +
    theme_minimal()

  ggsave("bolgesel_etkilesim.png", p_bolge, width = 9, height = 6, dpi = 200)
}

saveRDS(bolge_sonuclari, "regional_results.rds")
