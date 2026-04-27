###############################################################################
# ECOP_Revisions.R
# Makale: "Determinants of Sub-Saharan Africa's Agricultural Value Added and
#          2030 Projection: Multilayer ANN and Scenario Analysis Across 29 Countries"
#
# Bu dosya bilimsel değerlendirme sonucunda tespit edilen kritik sorunlara
# yönelik revizyon kodlarını içermektedir.
#
# SORUNLAR VE DÜZELTMELERİN ÖZETİ:
#   [R1] Data Leakage: Normalizasyon train verisi üzerinden yapılmalı
#   [R2] Gerçek 10-Fold Cross-Validation hesabı (hardcoded değil)
#   [R3] Panel yapısını gözeten sağlamlık testi (FE + RE modelleri)
#   [R4] Senaryo projeksiyonunda dışı-aralık (out-of-range) kontrolü
#   [R5] Olden skor stabilitesi — çoklu seed analizi
#   [R6] RMSE ve Adjusted R² metriklerinin eklenmesi
###############################################################################

library(dplyr)
library(neuralnet)
library(NeuralNetTools)
library(ggplot2)
library(randomForest)
library(xgboost)
library(plm)       # Panel modeller için (FE/RE) — yeni eklendi

# Veri yükleme
temiz_panel_v2 <- read.csv(normalizePath(file.path(getwd(), "../../../../400-Data/2026-Gulistan-Collaboration/data/ssa_tarim_29_ulke_v3.csv"), mustWork = FALSE))

###############################################################################
# YARDIMCI FONKSİYONLAR
###############################################################################

# Min-Max normalizasyon (eğitim istatistikleriyle)
normalize_with_stats <- function(x, mn, mx) {
  (x - mn) / (mx - mn)
}

# Performans metrikleri (RMSE dahil)
calc_metrics <- function(actual, predicted) {
  rss    <- sum((predicted - actual)^2)
  tss    <- sum((actual - mean(actual))^2)
  r2     <- 1 - rss / tss
  mse    <- mean((actual - predicted)^2)
  rmse   <- sqrt(mse)
  mae    <- mean(abs(actual - predicted))
  list(R2 = round(r2, 4), MSE = round(mse, 5),
       RMSE = round(rmse, 5), MAE = round(mae, 4))
}

###############################################################################
# [R1] DÜZELTİLMİŞ NORMALİZASYON: VERİ SIZINTISI ÖNLENİYOR
# Problem: Mevcut kodda tüm veri seti normalize edilip sonra bölünüyor.
#          Bu, test verisinin min/max değerlerinin train normalizasyonuna
#          sızmasına yol açar (data leakage).
# Çözüm:  Önce train/test bölünür, normalizasyon SADECE train'den hesaplanır,
#         aynı istatistikler test setine uygulanır.
###############################################################################

cat("\n========== [R1] DÜZELTİLMİŞ NORMALİZASYON (VERİ SIZINTISI YOK) ==========\n")

vars_m1 <- c("tarim_gsyh", "emek", "toprak", "gubre", "ihracat")
vars_m3 <- c("tarim_gsyh", "emek", "toprak", "gubre", "ihracat",
             "ekipman_teknoloji", "kaynak_ranti", "kursal_elektrik")

# --- MODEL 1: Düzeltilmiş normalizasyon ---
set.seed(42)
index_m1 <- sample(1:nrow(temiz_panel_v2), round(0.8 * nrow(temiz_panel_v2)))
train_raw_m1 <- temiz_panel_v2[index_m1, ]
test_raw_m1  <- temiz_panel_v2[-index_m1, ]

# Normalizasyon istatistikleri SADECE train'den
min_train_m1 <- sapply(train_raw_m1[, vars_m1], min, na.rm = TRUE)
max_train_m1 <- sapply(train_raw_m1[, vars_m1], max, na.rm = TRUE)

train_m1_corrected <- train_raw_m1
test_m1_corrected  <- test_raw_m1

for (v in vars_m1) {
  train_m1_corrected[[v]] <- normalize_with_stats(
    train_raw_m1[[v]], min_train_m1[v], max_train_m1[v])
  test_m1_corrected[[v]]  <- normalize_with_stats(
    test_raw_m1[[v]],  min_train_m1[v], max_train_m1[v])
}

# Model 1 eğitimi (düzeltilmiş veri ile)
set.seed(42)
nn_m1_corrected <- neuralnet(
  tarim_gsyh ~ emek + toprak + gubre + ihracat,
  data = train_m1_corrected,
  hidden = c(6, 3),
  linear.output = TRUE,
  threshold = 0.01,
  stepmax = 1e6
)

pred_m1_corrected <- predict(nn_m1_corrected, test_m1_corrected)
metrics_m1_corrected <- calc_metrics(
  test_m1_corrected$tarim_gsyh, pred_m1_corrected)

cat("Model 1 (Düzeltilmiş - Veri Sızıntısı Yok):\n")
cat("  R²   :", metrics_m1_corrected$R2, "\n")
cat("  MSE  :", metrics_m1_corrected$MSE, "\n")
cat("  RMSE :", metrics_m1_corrected$RMSE, "\n")
cat("  MAE  :", metrics_m1_corrected$MAE, "\n")

# --- MODEL 3: Düzeltilmiş normalizasyon ---
set.seed(42)
index_m3 <- sample(1:nrow(temiz_panel_v2), round(0.8 * nrow(temiz_panel_v2)))
train_raw_m3 <- temiz_panel_v2[index_m3, ]
test_raw_m3  <- temiz_panel_v2[-index_m3, ]

min_train_m3 <- sapply(train_raw_m3[, vars_m3], min, na.rm = TRUE)
max_train_m3 <- sapply(train_raw_m3[, vars_m3], max, na.rm = TRUE)

train_m3_corrected <- train_raw_m3
test_m3_corrected  <- test_raw_m3

for (v in vars_m3) {
  train_m3_corrected[[v]] <- normalize_with_stats(
    train_raw_m3[[v]], min_train_m3[v], max_train_m3[v])
  test_m3_corrected[[v]]  <- normalize_with_stats(
    test_raw_m3[[v]],  min_train_m3[v], max_train_m3[v])
}

set.seed(42)
nn_m3_corrected <- neuralnet(
  tarim_gsyh ~ emek + toprak + gubre + ihracat +
    ekipman_teknoloji + kaynak_ranti + kursal_elektrik,
  data = train_m3_corrected,
  hidden = c(6, 3),
  linear.output = TRUE,
  threshold = 0.01,
  stepmax = 1e6
)

pred_m3_corrected <- predict(nn_m3_corrected, test_m3_corrected)
metrics_m3_corrected <- calc_metrics(
  test_m3_corrected$tarim_gsyh, pred_m3_corrected)

cat("\nModel 3 Final (Düzeltilmiş - Veri Sızıntısı Yok):\n")
cat("  R²   :", metrics_m3_corrected$R2, "\n")
cat("  MSE  :", metrics_m3_corrected$MSE, "\n")
cat("  RMSE :", metrics_m3_corrected$RMSE, "\n")
cat("  MAE  :", metrics_m3_corrected$MAE, "\n")

###############################################################################
# [R2] GERÇEK 10-FOLD CROSS-VALIDATION (hardcoded değil)
# Problem: Mevcut kodda CV sonucu doğrudan cat() ile sabit metin olarak
#          yazılmış (0.801). Gerçekte hesaplanmıyor.
# Çözüm:  Gerçek 10-fold CV döngüsü — her fold'da model eğitilip test ediliyor.
###############################################################################

cat("\n========== [R2] GERÇEK 10-FOLD CROSS-VALIDATION ==========\n")

# Her fold için ayrı normalizasyon (leakage önleme ile birlikte)
set.seed(42)
n <- nrow(temiz_panel_v2)
fold_ids <- sample(rep(1:10, length.out = n))

cv_r2_m1 <- numeric(10)

for (k in 1:10) {
  # fold ayrımı (ham veri üzerinden)
  cv_train_raw <- temiz_panel_v2[fold_ids != k, ]
  cv_test_raw  <- temiz_panel_v2[fold_ids == k, ]

  # Her fold'da normalizasyon istatistikleri sadece train'den
  mn_k <- sapply(cv_train_raw[, vars_m1], min, na.rm = TRUE)
  mx_k <- sapply(cv_train_raw[, vars_m1], max, na.rm = TRUE)

  cv_train <- cv_train_raw
  cv_test  <- cv_test_raw
  for (v in vars_m1) {
    cv_train[[v]] <- normalize_with_stats(cv_train_raw[[v]], mn_k[v], mx_k[v])
    cv_test[[v]]  <- normalize_with_stats(cv_test_raw[[v]],  mn_k[v], mx_k[v])
  }

  set.seed(42 + k)  # Her fold farklı ama tekrar üretilebilir seed
  cv_nn <- tryCatch(
    neuralnet(
      tarim_gsyh ~ emek + toprak + gubre + ihracat,
      data = cv_train,
      hidden = c(6, 3),
      linear.output = TRUE,
      threshold = 0.01,
      stepmax = 5e5
    ),
    error = function(e) NULL
  )

  if (!is.null(cv_nn)) {
    cv_pred <- predict(cv_nn, cv_test)
    actual  <- cv_test$tarim_gsyh
    cv_r2_m1[k] <- 1 - sum((actual - cv_pred)^2) /
                       sum((actual - mean(actual))^2)
  } else {
    cv_r2_m1[k] <- NA
    warning(paste("Fold", k, "converge olmadı."))
  }
}

cat("10-Fold CV Sonuçları (Model 1):\n")
print(round(cv_r2_m1, 4))
cat("Ortalama CV R²  :", round(mean(cv_r2_m1, na.rm = TRUE), 4), "\n")
cat("SD (istikrar)   :", round(sd(cv_r2_m1,   na.rm = TRUE), 4), "\n")
cat("Min – Max       :", round(min(cv_r2_m1, na.rm = TRUE), 4),
    "–", round(max(cv_r2_m1, na.rm = TRUE), 4), "\n")

###############################################################################
# [R3] PANEL SAĞLAMLIK TESTİ: SABİT ETKİLER + RASTGELE ETKİLER
# Problem: Mevcut sağlamlık testinde "OLS" kullanılıyor, ancak bu sıradan
#          OLS panel yapısını (ülke + zaman boyutu) görmezden geliyor.
#          Gözlemcilerin isteyeceği doğru kıyaslama FE/RE modelidir.
# Çözüm:  plm paketi ile Fixed Effects ve Random Effects modelleri ekleniyor.
###############################################################################

cat("\n========== [R3] PANEL MODELLERİ (FE ve RE) — GENİŞLETİLMİŞ SAĞLAMLIK TESTİ ==========\n")

# Panel veri yapısı tanımla
pdata <- pdata.frame(temiz_panel_v2,
                     index = c("country", "year"),
                     drop.index = FALSE)

formula_panel <- tarim_gsyh ~ emek + toprak + gubre + ihracat +
  ekipman_teknoloji + kaynak_ranti + kursal_elektrik

# Sabit Etkiler (Fixed Effects — Within Estimator)
fe_model  <- plm(formula_panel, data = pdata, model = "within")
fe_pred   <- fitted(fe_model)
fe_actual <- as.numeric(pdata$tarim_gsyh)
fe_r2     <- summary(fe_model)$r.squared["rsq"]
fe_mse    <- mean((fe_actual - fe_pred)^2)
fe_rmse   <- sqrt(fe_mse)
fe_mae    <- mean(abs(fe_actual - fe_pred))

cat("Fixed Effects (FE) Modeli:\n")
cat("  Within R²:", round(fe_r2, 4), "\n")
cat("  MSE      :", round(fe_mse, 5), "\n")
cat("  RMSE     :", round(fe_rmse, 5), "\n")
cat("  MAE      :", round(fe_mae, 4), "\n")

# Rastgele Etkiler (Random Effects)
re_model <- plm(formula_panel, data = pdata, model = "random")
re_r2    <- summary(re_model)$r.squared["rsq"]
cat("\nRandom Effects (RE) Modeli:\n")
cat("  Overall R²:", round(re_r2, 4), "\n")

# Hausman Testi (FE mi RE mi?)
hausman_test <- phtest(fe_model, re_model)
cat("\nHausman Testi:\n")
print(hausman_test)
cat("Yorum: p <0.05 → Fixed Effects tercih edilmeli\n")

# Genişletilmiş karşılaştırma tablosu (panel modeller dahil)
cat("\n--- GENİŞLETİLMİŞ SAĞLAMLIK TABLOSU ---\n")
robustness_extended <- data.frame(
  Model = c("OLS (Pooled)", "Fixed Effects (FE)", "Random Effects (RE)",
            "Random Forest", "XGBoost", "LightGBM", "ANN - Model 3 (Düzeltilmiş)"),
  R2_approx = c(
    # OLS (tekrar hesapla)
    {
      ols_m <- lm(formula_panel, data = temiz_panel_v2)
      round(summary(ols_m)$r.squared, 4)
    },
    round(fe_r2, 4),
    round(re_r2, 4),
    NA,  # RF/XGB/LGB test seti R²'si koda entegre edilmeli — mevcut modelden alınır
    NA,
    NA,
    metrics_m3_corrected$R2
  )
)

# Not: RF/XGB/LGB değerleri mevcut ECOP_Submission_EN.qmd Bölüm 4.4'ten alınmalı
# ve bu tabloya entegre edilmeli. NA değerlerini oradan doldurun.
print(robustness_extended)

###############################################################################
# [R4] SENARYO PROJEKSİYONU: DIŞI-ARALIK KONTROLÜ
# Problem: 2021-2030 projeksiyon değerleri tarihsel [min,max] aralığının
#          dışına çıkabilir; bu sigmoid aktivasyon için sorunludur.
# Çözüm:  Her değişken için sınır kontrolü ve uyarı sistemi.
###############################################################################

cat("\n========== [R4] SENARYO PROJEKSİYONU: DIŞI-ARALIK KONTROLÜ ==========\n")

base_2020     <- temiz_panel_v2 %>% filter(year == 2020)
emek_start    <- mean(base_2020$emek,              na.rm = TRUE)
toprak_start  <- mean(base_2020$toprak,            na.rm = TRUE)
gubre_start   <- mean(base_2020$gubre,             na.rm = TRUE)
ihracat_start <- mean(base_2020$ihracat,           na.rm = TRUE)
ekipman_start <- mean(base_2020$ekipman_teknoloji, na.rm = TRUE)
kaynak_start  <- mean(base_2020$kaynak_ranti,      na.rm = TRUE)
elektrik_start<- mean(base_2020$kursal_elektrik,   na.rm = TRUE)

forecast_raw <- data.frame(
  year              = 2021:2030,
  emek              = emek_start    * (0.99  ^ (1:10)),
  toprak            = rep(toprak_start, 10),
  gubre             = gubre_start   * (1.02  ^ (1:10)),
  ihracat           = ihracat_start * (1.015 ^ (1:10)),
  ekipman_teknoloji = ekipman_start * (1.015 ^ (1:10)),
  kaynak_ranti      = rep(kaynak_start, 10),
  kursal_elektrik   = elektrik_start* (1.025 ^ (1:10))
)

# Normalizasyon sınırları (train verisinden — düzeltilmiş yaklaşım)
# Senaryo için tüm veriyi kullanıyoruz (2000-2020 tarihsel sınırlar)
hist_min <- sapply(temiz_panel_v2[, names(forecast_raw)[-1]], min, na.rm = TRUE)
hist_max <- sapply(temiz_panel_v2[, names(forecast_raw)[-1]], max, na.rm = TRUE)

# Normalizasyon ve sınır kontrolü
check_extrapolation <- function(val, hist_min, hist_max, varname, year) {
  norm_val <- (val - hist_min) / (hist_max - hist_min)
  if (any(norm_val < 0)) {
    cat(sprintf("  ⚠️  %s: %d yılında DÜŞÜK sınır aşıldı! (min=%.3f)\n",
                varname, year[norm_val < 0], val[norm_val < 0]))
  }
  if (any(norm_val > 1)) {
    cat(sprintf("  ⚠️  %s: %d yılında YÜKSEK sınır aşıldı! (%.3f > tarihsel max=%.3f)\n",
                varname, year[norm_val > 1], val[norm_val > 1], hist_max))
  }
  # Klip: [0, 1] aralığına zorla (güvenli extrapolation)
  pmax(0, pmin(1, norm_val))
}

forecast_norm_checked <- data.frame(year = forecast_raw$year)
input_vars <- c("emek", "toprak", "gubre", "ihracat",
                "ekipman_teknoloji", "kaynak_ranti", "kursal_elektrik")

cat("Değişken bazlı dışı-aralık kontrolü:\n")
for (v in input_vars) {
  forecast_norm_checked[[v]] <- check_extrapolation(
    forecast_raw[[v]], hist_min[v], hist_max[v], v, forecast_raw$year
  )
}
cat("(Uyarı yoksa tüm değerler tarihsel aralık içinde kalıyor.)\n")

# Projeksiyon (düzeltilmiş model 3 ile)
pred_scenario <- predict(nn_m3_corrected,
                         forecast_norm_checked[, input_vars])

min_gsyh <- min(temiz_panel_v2$tarim_gsyh)
max_gsyh <- max(temiz_panel_v2$tarim_gsyh)

# Denormalizasyon (train min/max ile yapılmalı - model 3 düzeltilmiş)
min_gsyh_train <- min(train_raw_m3$tarim_gsyh)
max_gsyh_train <- max(train_raw_m3$tarim_gsyh)

forecast_raw$Tarim_GSYH_Payi_Corrected <-
  as.vector(pred_scenario) * (max_gsyh_train - min_gsyh_train) + min_gsyh_train

cat("\n--- 2021-2030 Düzeltilmiş Projeksiyon (Model 3, Veri Sızıntısı Yok) ---\n")
print(forecast_raw %>%
        select(year, Tarim_GSYH_Payi_Corrected) %>%
        mutate(Tarim_GSYH_Payi_Corrected = round(Tarim_GSYH_Payi_Corrected, 2)))

# Projeksiyon grafiği (başlık eklenerek — orijinal kodda sadece subtitle vardı)
ggplot(forecast_raw, aes(x = year, y = Tarim_GSYH_Payi_Corrected)) +
  geom_line(color = "darkgreen", linewidth = 1.5) +
  geom_point(size = 4, color = "darkorange") +
  geom_text(aes(label = round(Tarim_GSYH_Payi_Corrected, 2)),
            vjust = -1, size = 3.5) +
  labs(
    title    = "Figure 8: Sub-Saharan Africa Agricultural GDP Share — 2030 Projection",  # [Düzeltme: başlık eklendi]
    subtitle = "Scenario: Labor (-1%), Fertilizer (+2%), Exports (+1.5%), Tech. (+1.5%), Electricity (+2.5%)",
    x = "Year",
    y = "Predicted Agricultural GDP Share (%)"
  ) +
  theme_minimal() +
  ylim(min(forecast_raw$Tarim_GSYH_Payi_Corrected) - 1.5,
       max(forecast_raw$Tarim_GSYH_Payi_Corrected) + 1.5)

###############################################################################
# [R5] OLDEN SKOR STABİLİTE ANALİZİ (Çoklu Seed)
# Problem: ANN ağırlıkları rastgele başlatılır; Olden skorları seed'e
#          bağlı olarak dramatik biçimde değişebilir. Olağandışı yüksek
#          skorlar (22188, 37064) bir kararsızlık işareti olabilir.
# Çözüm:  15 farklı seed ile modeli tekrar eğitip Olden skorlarının
#          dağılımını raporluyoruz.
###############################################################################

cat("\n========== [R5] OLDEN SKOR STABİLİTE ANALİZİ (15 Seed) ==========\n")

seeds_to_test <- c(1, 7, 13, 21, 42, 99, 123, 200, 314, 500, 777, 888, 1000, 1234, 2025)
olden_results <- list()

for (s in seeds_to_test) {
  set.seed(s)
  idx_s <- sample(1:nrow(temiz_panel_v2), round(0.8 * nrow(temiz_panel_v2)))
  tr_s  <- temiz_panel_v2[idx_s, ]
  te_s  <- temiz_panel_v2[-idx_s, ]

  # Normalizasyon (her seed için train'den)
  mn_s <- sapply(tr_s[, vars_m1], min, na.rm = TRUE)
  mx_s <- sapply(tr_s[, vars_m1], max, na.rm = TRUE)
  for (v in vars_m1) {
    tr_s[[v]] <- normalize_with_stats(tr_s[[v]], mn_s[v], mx_s[v])
    te_s[[v]] <- normalize_with_stats(te_s[[v]], mn_s[v], mx_s[v])
  }

  set.seed(s)
  nn_s <- tryCatch(
    neuralnet(
      tarim_gsyh ~ emek + toprak + gubre + ihracat,
      data = tr_s, hidden = c(6, 3),
      linear.output = TRUE, threshold = 0.01, stepmax = 5e5
    ),
    error = function(e) NULL
  )

  if (!is.null(nn_s)) {
    scores <- olden(nn_s, bar_plot = FALSE)
    olden_results[[as.character(s)]] <- scores$importance
  }
}

# Stabilite özet tablosu
if (length(olden_results) > 0) {
  olden_mat <- do.call(rbind, olden_results)
  colnames(olden_mat) <- rownames(olden(
    neuralnet(tarim_gsyh ~ emek + toprak + gubre + ihracat,
              data = train_m1_corrected, hidden = c(6,3),
              linear.output = TRUE, threshold = 0.01, stepmax = 1e5),
    bar_plot = FALSE))

  cat("Olden Skor Stabilitesi (15 farklı seed, Model 1):\n")
  stability_summary <- data.frame(
    Degisken  = colnames(olden_mat),
    Ortalama  = round(colMeans(olden_mat, na.rm = TRUE), 0),
    SD        = round(apply(olden_mat, 2, sd, na.rm = TRUE), 0),
    Min       = round(apply(olden_mat, 2, min, na.rm = TRUE), 0),
    Max       = round(apply(olden_mat, 2, max, na.rm = TRUE), 0),
    CV_pct    = round(abs(apply(olden_mat, 2, sd, na.rm = TRUE) /
                            colMeans(olden_mat, na.rm = TRUE)) * 100, 1)
  )
  print(stability_summary)
  write.csv(stability_summary, "../03-Results/stability_summary_olden.csv", row.names = FALSE)
  cat("\nNot: CV% > 50 ise skor yüksek kararsızlık gösteriyor —",
      "makalede bu sınırlılık belirtilmeli.\n")
} else {
  cat("Stabilite analizi için yeterli converge sağlanamadı.\n")
}

###############################################################################
# [R6] GENİŞLETİLMİŞ METRİK TABLOSU (RMSE + Adjusted R² dahil)
###############################################################################

cat("\n========== [R6] GENİŞLETİLMİŞ METRİK TABLOSU (RMSE + Adj. R²) ==========\n")

# Adjusted R² hesabı
adj_r2 <- function(r2, n, k) {
  1 - (1 - r2) * (n - 1) / (n - k - 1)
}

n_test_m1 <- nrow(test_m1_corrected)
metrics_table <- data.frame(
  Model       = c("Model 1 (4 giriş)", "Model 3 (7 giriş, Düzeltilmiş)"),
  n_inputs    = c(4, 7),
  R2          = c(metrics_m1_corrected$R2, metrics_m3_corrected$R2),
  Adj_R2      = c(
    round(adj_r2(metrics_m1_corrected$R2, n_test_m1, 4), 4),
    round(adj_r2(metrics_m3_corrected$R2, nrow(test_m3_corrected), 7), 4)
  ),
  MSE         = c(metrics_m1_corrected$MSE,  metrics_m3_corrected$MSE),
  RMSE        = c(metrics_m1_corrected$RMSE, metrics_m3_corrected$RMSE),
  MAE         = c(metrics_m1_corrected$MAE,  metrics_m3_corrected$MAE)
)

print(metrics_table)
write.csv(metrics_table, "../03-Results/metrics_comparison_final.csv", row.names = FALSE)
cat("\nNot: Adj. R² ek değişken sayısını cezalandırır.",
    "Model 3'ün gerçek katkısı buradan görülür.\n")

###############################################################################
# ÖZET: HANGİ SATIRLAR QMD DOSYASINDA DEĞİŞTİRİLMELİ
###############################################################################

cat("\n\n")
cat("================================================================\n")
cat("         ECOP_Submission_EN.qmd İÇİN DEĞİŞTİRİLMESİ GEREKEN\n")
cat("         KRİTİK SATIRLAR (Satır numarasıyla)\n")
cat("================================================================\n")
cat("\n[1] Satır 216: j = 1, 2, ..., 5  →  j = 1, 2, ..., 6  (6 nöron var!)\n")
cat("[2] Satır 246-247: normalize() ÖNCE tüm veriyle uygulanıyor.\n")
cat("    → train/test ayrımı ÖNCE yapılmalı, sonra sadece train'den normalize.\n")
cat("[3] Satır 521: hardcoded 0.801 → Gerçek 10-fold CV hesabıyla değiştir.\n")
cat("[4] Satır 393-396: Bölüm 4.3.4 başlığı iki kez tekrar ediyor — birini sil.\n")
cat("[5] Satır 934 ve 961: Her ikisi de '4.6.3' numaralı — ikincisini '4.6.4' yap.\n")
cat("[6] Satır 26-28: Abstract'ta son iki cümle duplicate — birini sil.\n")
cat("[7] Satır 1148: Senaryo grafiğine 'title' ekle (sadece subtitle var).\n")
cat("[8] Sağlamlık karşılaştırması (Bölüm 4.4): FE ve RE panel modellerini ekle.\n")
cat("[9] Tüm metrik tablolarına RMSE sütunu ekle.\n")
cat("[10] Encoding hataları: 'Ã¢â€ ', 'MilaÃ„Â...' vb. → UTF-8 karakterlere düzelt.\n")
cat("================================================================\n")
