# SECTION 2: PANEL BİRİM KÖK TESTLERİ

library(plm)
library(dplyr)

cat("\n=== 2. PANEL BİRİM KÖK TESTLERİ ===\n")
cat("Hipotez: H0 = Birim kök vardır (seri durağan değildir)\n\n")

# Load data
analiz <- readRDS("../../../400-Data/2026-UY-MGO-Makale/analiz_data.rds")
panel <- readRDS("../../../400-Data/2026-UY-MGO-Makale/panel_data.rds")

# Testlere dahil edilecek değişkenler
degiskenler <- c("ln_ihracat", "ln_reer", "ln_gsyh", "hukuk")

birim_kok_sonuclari <- list()

for (degisken in degiskenler) {
  cat("---", degisken, "---\n")

  # Im-Pesaran-Shin (IPS) Testi
  # H0: Tüm panellerde birim kök var
  ips_sonuc <- tryCatch({
    purtest(panel[[degisken]], test = "ips", exo = "intercept", lags = "AIC")
  }, error = function(e) {
    cat("  IPS testi Error:", conditionMessage(e), "\n")
    NULL
  })

  if (!is.null(ips_sonuc)) {
    cat("  IPS testi - p-değeri:", round(ips_sonuc$statistic$p.value, 4), "\n")
    birim_kok_sonuclari[[paste0(degisken, "_IPS")]] <- ips_sonuc
  }

  # Levin-Lin-Chu (LLC) Testi
  # H0: Ortak birim kök var
  llc_sonuc <- tryCatch({
    purtest(panel[[degisken]], test = "levinlin", exo = "intercept", lags = "AIC")
  }, error = function(e) {
    cat("  LLC testi Error:", conditionMessage(e), "\n")
    NULL
  })

  if (!is.null(llc_sonuc)) {
    cat("  LLC testi - p-değeri:", round(llc_sonuc$statistic$p.value, 4), "\n")
  }
}

cat("\n  NOT: p > 0.05 → Birim kök VAR (fark alın)\n")
cat("  NOT: p < 0.05 → Birim kök YOK (seri durağan)\n")
cat("\n  I(1) seriler için 1. farkları alınarak durağanlık sağlanır:\n")

# Birinci farklar
analiz_diff <- analiz %>%
  group_by(country) %>%
  mutate(
    d_ln_ihracat  = c(NA, diff(ln_ihracat)),
    d_ln_reer     = c(NA, diff(ln_reer)),
    d_ln_gsyh     = c(NA, diff(ln_gsyh)),
    d_hukuk       = c(NA, diff(hukuk))
  ) %>%
  ungroup()

cat("✔ 1. fark değişkenleri (d_) oluşturuldu.\n")

# Save updated data
saveRDS(analiz_diff, "analiz_data_diff.rds")
# Re-create panel with diffs
panel_diff <- pdata.frame(analiz_diff, index = c("country", "year"))
saveRDS(panel_diff, "panel_data_diff.rds")
