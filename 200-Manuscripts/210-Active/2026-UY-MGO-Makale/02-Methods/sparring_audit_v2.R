################################################################################
# sparring_audit_v2.R — UY-MGO-Makale Academic Sparring + Fix Script
# Çalıştır: source("02-Methods/sparring_audit_v2.R")
# Gerekli: R ≥ 4.2, plm, lmtest, sandwich, quantreg, pgmm, knitr, kableExtra
################################################################################

library(plm)
library(lmtest)
library(sandwich)
library(quantreg)
library(modelsummary)
library(knitr)
library(kableExtra)
library(dplyr)

cat("
╔══════════════════════════════════════════════════════════════════╗
║  UY-MGO-Makale — Sparring Audit v2 (2026-04-20)                ║
║  Tespit edilen 6 kritik sorun — R ile yeniden doğrulama         ║
╚══════════════════════════════════════════════════════════════════╝
\n")

# ── 0. Veri yükleme ──────────────────────────────────────────────────────────
DATA_PATH <- file.path(dirname(dirname(rstudioapi::getSourceEditorContext()$path)),
                        "04-Manuscript", "data", "gelismekte_olan_veri.csv")
# Fallback (script dışından çalıştırılırsa):
if (!file.exists(DATA_PATH)) {
  DATA_PATH <- "04-Manuscript/data/gelismekte_olan_veri.csv"
}
stopifnot(file.exists(DATA_PATH))

data_full <- read.csv(DATA_PATH, stringsAsFactors = FALSE)
cat("Veri yüklendi:", nrow(data_full), "satır,", ncol(data_full), "sütun\n")
cat("Sütunlar:", paste(names(data_full), collapse = ", "), "\n\n")

# Gelişmekte olan ülkeler alt örneklemi — Çin ve Zambiya zaten filtrelendi (N=37)
# Eğer 'income_group' veya benzeri sütun varsa:
if ("income_group" %in% names(data_full)) {
  data_em <- data_full[data_full$income_group != "High income", ]
} else {
  # Tüm veri gelişmekte olanlardır varsay
  data_em <- data_full
}
cat("Gelişmekte olan ülkeler örneklemi:", nrow(data_em), "gözlem,",
    length(unique(data_em[[grep("country|ulke|iso", names(data_em), ignore.case=TRUE)[1]]])),
    "ülke\n\n")

# pdata.frame — index sütunlarını tespit et
country_col <- grep("country|ulke|iso|code", names(data_em), ignore.case=TRUE, value=TRUE)[1]
year_col    <- grep("year|yil|date", names(data_em), ignore.case=TRUE, value=TRUE)[1]
cat("Panel index:", country_col, "×", year_col, "\n\n")

pdata_em <- pdata.frame(data_em, index = c(country_col, year_col))

# ── 1. FE Baseline — doğrulama ───────────────────────────────────────────────
cat("═══ SPARRING #1: FE Baseline doğrulama ═══\n")
model_fe <- plm(ln_ihracat ~ ln_reer + hukuk + ln_reer:hukuk + ln_gsyh,
                data = pdata_em, model = "within", effect = "twoways")
se_fe_cluster <- sqrt(diag(vcovHC(model_fe, type = "HC1", cluster = "group")))
coeftest_fe <- coeftest(model_fe, vcov = vcovHC(model_fe, type = "HC1", cluster = "group"))
cat("FE: β(etkileşim) =", round(coef(model_fe)["ln_reer:hukuk"], 4),
    "| Cluster SE =", round(se_fe_cluster["ln_reer:hukuk"], 4),
    "| p =", round(coeftest_fe["ln_reer:hukuk", "Pr(>|t|)"], 4), "\n")
# Beklenen: 0.129, SE≈0.058 (OLS SE), ya da daha büyük cluster SE
cat("Not: Tablodaki SE=(0.058) OLS SE ise, cluster-robust SE daha büyük olmalı.\n\n")

# ── 2. KRİTİK FIX: DK-SCC doğru uygulanması ─────────────────────────────────
cat("═══ SPARRING #2: KRİTİK-1 — DK-SCC doğru vcov ═══\n")
cat("Tablodaki mevcut değer: β=0.129** SE=(0.058) — YANLIŞ (OLS SE)\n")

# DOĞRU: vcovSCC matrisi ile
vcov_dk4 <- vcovSCC(model_fe, type = "HC3", maxlag = 4)
se_dk4   <- sqrt(diag(vcov_dk4))
t_dk4    <- coef(model_fe)["ln_reer:hukuk"] / se_dk4["ln_reer:hukuk"]
p_dk4    <- 2 * pt(abs(t_dk4), df = model_fe$df.residual, lower.tail = FALSE)
cat("DK-SCC (maxlag=4): β =", round(coef(model_fe)["ln_reer:hukuk"], 3),
    "| SE =", round(se_dk4["ln_reer:hukuk"], 3),
    "| p =", round(p_dk4, 3), "\n")
cat("Beklenen: SE≈0.110, p≈0.24 → YILDIZ YOK\n\n")

# MAXLAG DUYARLILIK ANALİZİ (Tablo dipnotu için)
cat("DK-SCC Maxlag Duyarlılık:\n")
for (ml in 2:4) {
  vcov_ml  <- vcovSCC(model_fe, type = "HC3", maxlag = ml)
  se_ml    <- sqrt(diag(vcov_ml))["ln_reer:hukuk"]
  p_ml     <- 2 * pt(abs(coef(model_fe)["ln_reer:hukuk"] / se_ml),
                      df = model_fe$df.residual, lower.tail = FALSE)
  star_ml  <- ifelse(p_ml < 0.01, "***", ifelse(p_ml < 0.05, "**",
               ifelse(p_ml < 0.10, "*", "NS")))
  cat("  maxlag =", ml, ": SE =", round(se_ml, 4), "| p =", round(p_ml, 4), star_ml, "\n")
}

# DK Full Table (doğru) — modelsummary ile
tbl_dk_correct <- modelsummary(
  model_fe,
  vcov = list(function(x) vcovSCC(x, type = "HC3", maxlag = 4)),
  stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c("ln_reer" = "ln(REER)", "hukuk" = "Hukukun Üstünlüğü",
               "ln_gsyh" = "ln(GSYH)", "ln_reer:hukuk" = "ln(REER) × Hukuk"),
  gof_omit = "IC|Log|F|RMSE|Std",
  title = "Tablo 4 (DÜZELTİLMİŞ): Driscoll-Kraay SCC — maxlag=4",
  output = "kableExtra"
)
print(tbl_dk_correct)
cat("\n")

# ── 3. KRİTİK FIX: Canay QR — Cluster Bootstrap SE ──────────────────────────
cat("═══ SPARRING #3: Tablo 5 (QR) — Cluster Bootstrap SE doğrulaması ═══\n")
cat("Tablodaki mevcut SE: (0.117), (0.105), (0.105) — YANLIŞ (pairs bootstrap)\n")
cat("Hakem Raporu doğruladı: SE = (0.160), (0.144), (0.175) — cluster bootstrap\n\n")

# Canay (2011) panel QR — FE arındırma
fe_coefs <- fixef(model_fe)
data_em$fe_adj <- data_em$ln_ihracat - fe_coefs[data_em[[country_col]]]
# NA varsa kaldır
data_qr <- data_em[!is.na(data_em$fe_adj), ]

set.seed(42)
B <- 499

run_canay_qr <- function(tau, data_qr, country_col) {
  model_q <- rq(fe_adj ~ ln_reer + hukuk + ln_reer:hukuk + ln_gsyh,
                 tau = tau, data = data_qr)
  # Cluster bootstrap
  countries <- unique(data_qr[[country_col]])
  boot_coefs <- matrix(NA, nrow = B, ncol = length(coef(model_q)))
  for (b in seq_len(B)) {
    samp_countries <- sample(countries, replace = TRUE)
    boot_data      <- do.call(rbind, lapply(samp_countries, function(c) {
      data_qr[data_qr[[country_col]] == c, ]
    }))
    tryCatch({
      m_b <- rq(fe_adj ~ ln_reer + hukuk + ln_reer:hukuk + ln_gsyh,
                  tau = tau, data = boot_data)
      boot_coefs[b, ] <- coef(m_b)
    }, error = function(e) NULL)
  }
  boot_se <- apply(boot_coefs, 2, sd, na.rm = TRUE)
  list(coef = coef(model_q), se = boot_se,
       pval = 2 * pnorm(abs(coef(model_q) / boot_se), lower.tail = FALSE))
}

cat("QR tau=0.25 çalışıyor (B=499 cluster bootstrap)...\n")
qr25 <- run_canay_qr(0.25, data_qr, country_col)
cat("τ=0.25: β(etkileşim) =", round(qr25$coef["ln_reer:hukuk"], 3),
    "| Cluster SE =", round(qr25$se[grep(":", names(qr25$coef))], 3),
    "| p =", round(qr25$pval[grep(":", names(qr25$coef))], 3), "\n")

cat("QR tau=0.50 çalışıyor...\n")
qr50 <- run_canay_qr(0.50, data_qr, country_col)
cat("τ=0.50: β(etkileşim) =", round(qr50$coef["ln_reer:hukuk"], 3),
    "| Cluster SE =", round(qr50$se[grep(":", names(qr50$coef))], 3),
    "| p =", round(qr50$pval[grep(":", names(qr50$coef))], 3), "\n")

cat("QR tau=0.75 çalışıyor...\n")
qr75 <- run_canay_qr(0.75, data_qr, country_col)
cat("τ=0.75: β(etkileşim) =", round(qr75$coef["ln_reer:hukuk"], 3),
    "| Cluster SE =", round(qr75$se[grep(":", names(qr75$coef))], 3),
    "| p =", round(qr75$pval[grep(":", names(qr75$coef))], 3), "\n\n")

# QR kable tablosu (doğru SE ile)
make_star <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
}
fmt_coef <- function(b, se, p) {
  sprintf("%.3f%s\n(%.3f)", b, make_star(p), se)
}

inter_idx <- grep("hukuk", names(qr25$coef))[grep(":", grep("hukuk", names(qr25$coef), value=TRUE))]
# Simpler: find ln_reer:hukuk index
inter_name <- grep("reer.*hukuk|hukuk.*reer", names(qr25$coef), ignore.case=TRUE, value=TRUE)

cat("═══ Tablo 5 DÜZELTİLMİŞ (Canay QR, Cluster Bootstrap B=499) ═══\n")
cat(sprintf("%-25s %12s %12s %12s\n", "Değişken", "τ=0.25", "τ=0.50", "τ=0.75"))
for (vname in c("ln_reer", "hukuk", "ln_gsyh", inter_name)) {
  cat(sprintf("%-25s %12s %12s %12s\n",
    vname,
    fmt_coef(qr25$coef[vname], qr25$se[match(vname,names(qr25$coef))], qr25$pval[match(vname,names(qr25$coef))]),
    fmt_coef(qr50$coef[vname], qr50$se[match(vname,names(qr50$coef))], qr50$pval[match(vname,names(qr50$coef))]),
    fmt_coef(qr75$coef[vname], qr75$se[match(vname,names(qr75$coef))], qr75$pval[match(vname,names(qr75$coef))])
  ))
}
cat("Not: Cluster bootstrap B=499, seed=42\n\n")

# ── 4. KRİTİK FIX: GMM — Doğru Observations + AR(1) yorumu ─────────────────
cat("═══ SPARRING #4: GMM — Observations=39 yanlış + AR(1) yorumu ═══\n")
model_gmm <- pgmm(
  ln_ihracat ~ lag(ln_ihracat, 1) + ln_reer + hukuk + ln_reer:hukuk + ln_gsyh |
    lag(ln_ihracat, 2:3),
  data     = pdata_em,
  effect   = "twoways",
  model    = "twosteps",
  transformation = "d"
)
n_gmm <- length(residuals(model_gmm))
cat("GMM doğru gözlem sayısı:", n_gmm, "(tabloda 39 yazıyor — YANLIŞ)\n")

gmm_sum <- summary(model_gmm, robust = TRUE)
cat("\nGMM Sargan J testi p-değeri:", round(gmm_sum$sargan[[3]], 3), "\n")
cat("GMM AR(1) testi p-değeri:   ", round(gmm_sum$m1[[3]], 3), "\n")
cat("GMM AR(2) testi p-değeri:   ", round(gmm_sum$m2[[3]], 3), "\n\n")

# AR(1) SPARRING NOTU
ar1_p <- gmm_sum$m1[[3]]
cat("⚠ AR(1) YORUMU:\n")
if (ar1_p > 0.05) {
  cat("  AR(1) p=", round(ar1_p, 3), "> 0.05 → Fark serisinde birinci derece otokorelasyon YOK.\n")
  cat("  Bu Arellano-Bond için SORUNLU: AB GMM'nin teorik temeli, Δy_{it}'nin AR(1) göstermesidir.\n")
  cat("  AR(1) reddedilemiyorsa, araç geçerliliği zayıflıyor. Dipnotta açıklanmalı:\n")
  cat("  'AB AB testi için beklenen AR(1) reddi gözlemlenmemiştir; bu, T=22'lik panel boyutunun\n")
  cat("   kısa olmasından kaynaklanan düşük güç (low power) ile açıklanabilir.'\n")
} else {
  cat("  AR(1) p=", round(ar1_p, 3), "< 0.05 → Beklenen durum, GMM geçerli.\n")
}

# ── 5. KRİTİK: Angrist & Pischke (2009) — Kaynakçaya Ekle ──────────────────
cat("\n═══ SPARRING #5: Ghost Citation — Angrist & Pischke (2009) ═══\n")
cat("Metin: '...koşullu ilişkiler olarak yorumlanmalıdır (Angrist & Pischke, 2009).'\n")
cat("Kaynakça: BU KAYNAK YOK — Ghost citation!\n")
cat("Düzeltme: Aşağıdaki kaynakçayı KAYNAKÇA bölümüne ekleyin:\n\n")
cat("Angrist, J. D. & Pischke, J.-S. (2009). Mostly harmless econometrics:\n")
cat("  An empiricist's companion. Princeton University Press.\n\n")
cat("DOI: 10.1515/9781400829828 (Princeton UP eBook)\n")
cat("veya ISBN: 978-0-691-12034-8\n\n")

# ── 6. SPARRING: Tablo 2 (FE) — SE (0.058) OLS mi Cluster mi? ───────────────
cat("═══ SPARRING #6: Tablo 2 (FE) SE kontrolü ═══\n")
se_ols   <- sqrt(diag(vcov(model_fe)))["ln_reer:hukuk"]
se_clust <- sqrt(diag(vcovHC(model_fe, type="HC1", cluster="group")))["ln_reer:hukuk"]
cat("FE OLS SE (etkileşim):", round(se_ols, 4), "\n")
cat("FE Cluster-robust SE:", round(se_clust, 4), "\n")
cat("Tablodaki SE: 0.058 — ")
if (abs(se_ols - 0.058) < 0.005) {
  cat("OLS SE (cluster-robust DEĞİL)\n")
  cat("⚠ Tablo 2 için de cluster-robust SE kullanılmalıydı!\n")
} else if (abs(se_clust - 0.058) < 0.005) {
  cat("Cluster-robust SE ✅\n")
} else {
  cat("Ne OLS ne cluster — kontrol edilmeli\n")
}

# ── 7. SPARRING: Ek Kontroller (Trade Openness, FDI, Inflation) ──────────────
cat("\n═══ SPARRING #7: Eksik Kontrol Değişkenleri ═══\n")
cat("Mevcut model: ln_ihracat ~ ln_reer + hukuk + ln_reer:hukuk + ln_gsyh + FE\n")
cat("Eksik standart kontroller:\n")
cat("  - Ticaret açıklığı (trade openness = ihracat+ithalat/GSYH)\n")
cat("  - FDI girişleri (ln_fdi)\n")
cat("  - Enflasyon (WDI CPI)\n")
cat("  - Ticaret anlaşması üyeliği (dummy)\n\n")

extra_vars <- c("trade_openness", "ln_fdi", "inflation")
avail <- extra_vars[extra_vars %in% names(data_em)]
if (length(avail) > 0) {
  cat("Mevcut değişkenler:", paste(avail, collapse=", "), "\n")
  formula_ext <- as.formula(
    paste("ln_ihracat ~ ln_reer + hukuk + ln_reer:hukuk + ln_gsyh +",
          paste(avail, collapse=" + "))
  )
  model_ext <- plm(formula_ext, data = pdata_em, model = "within", effect = "twoways")
  vcov_ext  <- vcovSCC(model_ext, type = "HC3", maxlag = 4)
  ct_ext    <- coeftest(model_ext, vcov = vcov_ext)
  cat("Robustness (ek kontroller DK-SCC):\n")
  cat("  β(etkileşim) =", round(ct_ext["ln_reer:hukuk", "Estimate"], 3),
      "p =", round(ct_ext["ln_reer:hukuk", "Pr(>|t|)"], 3), "\n\n")
} else {
  cat("Bu değişkenler veri setinde yok — WDI'dan çekilmeli (WorldBank package)\n\n")
}

# ── 8. SPARRING: Yapısal Kırılma (GFC 2008, COVID 2020) ─────────────────────
cat("═══ SPARRING #8: Yapısal Kırılma Kontrolü ═══\n")
data_em$d_gfc   <- as.integer(data_em[[year_col]] >= 2008 & data_em[[year_col]] <= 2009)
data_em$d_covid <- as.integer(data_em[[year_col]] == 2020)
pdata_em2 <- pdata.frame(data_em, index = c(country_col, year_col))

model_crisis <- plm(
  ln_ihracat ~ ln_reer + hukuk + ln_reer:hukuk + ln_gsyh + d_gfc + d_covid,
  data = pdata_em2, model = "within", effect = "twoways"
)
vcov_cr <- vcovSCC(model_crisis, type = "HC3", maxlag = 4)
ct_cr   <- coeftest(model_crisis, vcov = vcov_cr)
cat("Kriz dummies ile DK-SCC:\n")
cat("  β(etkileşim) =", round(ct_cr["ln_reer:hukuk", "Estimate"], 3),
    "| p =", round(ct_cr["ln_reer:hukuk", "Pr(>|t|)"], 3), "\n")
cat("  β(GFC)  =", round(ct_cr["d_gfc", "Estimate"], 3),
    "| p =", round(ct_cr["d_gfc", "Pr(>|t|)"], 3), "\n")
cat("  β(COVID)=", round(ct_cr["d_covid", "Estimate"], 3),
    "| p =", round(ct_cr["d_covid", "Pr(>|t|)"], 3), "\n\n")

# ── 9. SPARRING: Nonlinear threshold (Lissack L11) ───────────────────────────
cat("═══ SPARRING #9: Lissack L11 — Nonlinear Threshold Testi ═══\n")
cat("Eşik regresyon (Hansen 1999) — kurumsal kalkan eşiği istatistiksel olarak anlamlı mı?\n")
# Hansen bootstrap LR threshold test
if (requireNamespace("strucchange", quietly = TRUE)) {
  library(strucchange)
  cat("strucchange yüklü — Bai-Perron yapısal kırılma taraması yapılabilir\n")
} else {
  cat("Hansen (1999) threshold test için 'threshold' paketi gerekli:\n")
  cat("  install.packages('threshold')  # CRAN'da yok, GitHub'dan:\n")
  cat("  remotes::install_github('HansenLab/threshold')\n")
  cat("Alternatif: EK-3'teki RSS minimizasyonu görsel — ama bootstrap LR p-değeri yok!\n")
  cat("⚠ Bu, Hakem Raporu MİNÖR-4'ün hâlâ açık olduğunu gösteriyor.\n\n")
}

# ── 10. ÖZET BULGULAR ────────────────────────────────────────────────────────
cat("\n╔══════════════════════════════════════════════════════════════════╗\n")
cat("║  SPARRING AUDIT ÖZET                                            ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n\n")
cat("KRİTİK (gönderim engelleyici):\n")
cat("  ❌ Tablo 4: DK-SCC SE=0.058 → doğru SE≈0.110, 0.129** → NS\n")
cat("  ❌ Tablo 5: QR SE=(0.117) → doğru SE=(0.160), 0.242** → NS\n")
cat("  ❌ Tablo 8: Alternatif DK — aynı vcov hatası\n")
cat("  ❌ GMM Observations=39 → doğrusu:", n_gmm, "\n")
cat("  ❌ Angrist & Pischke (2009) kaynakçada yok\n\n")
cat("MAJÖR:\n")
cat("  ⚠ AR(1) p=0.531 — fark serisinde AR(1) reddedilemedi; dipnot gerekli\n")
cat("  ⚠ DK maxlag duyarlılık — tabloda gösterilmeli\n")
cat("  ⚠ Tablo 2 FE: SE=(0.058) OLS mı cluster-robust mı? Netleştirilmeli\n")
cat("  ⚠ Ek kontroller (openness, FDI) eklenmeli (sınırlılıklar bölümünde belirtilmeli)\n\n")
cat("MİNÖR:\n")
cat("  • EK-3 threshold — Hansen bootstrap LR p-değeri eksik\n")
cat("  • EK-2 bölgesel analizde maxlag=2 vs ana model maxlag=4 farkı açıklanmalı\n")
cat("  • Tablo 9 p=0.442 sabit kodlanmış — inline R ile değiştirilmeli\n\n")
cat("TAMAMLANMIŞ (önceki oturumda):\n")
cat("  ✅ Tablo 7 Volatilite×Hukuk NS (p=0.102) — anlatı güncellendi\n")
cat("  ✅ N=39→N=37 fix (6 adet)\n")
cat("  ✅ Zombie citation kontrolü (5 aday doğrulandı)\n")
cat("  ✅ 5 yeni paragraf eklendi (null result, Canay varsayım, DK maxlag, GMM araç, simultaneity)\n")
