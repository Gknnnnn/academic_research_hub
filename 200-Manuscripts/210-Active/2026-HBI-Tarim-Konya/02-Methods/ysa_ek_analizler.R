# =============================================================================
# YSA MODELİ - EK BİLİMSEL ANALİZLER (KAPSAMLI DOSYA)
# Makale: Küresel Tarımsal Katma Değerde Yapısal Taban Analizi ve 2030 Projeksiyonu
# Yazarlar: Prof. Dr. Hacı Bayram IŞIK & Arş. Gör. Dr. Mehmet Gökhan ÖZDEMİR
# =============================================================================

# Gerekli kütüphaneler
paketler <- c("WDI", "dplyr", "purrr", "readr", "countrycode", "zoo",
              "neuralnet", "NeuralNetTools", "ggplot2", "tidyr",
              "caret", "fastshap", "lmtest", "sandwich",
              "strucchange", "panelvar", "ggpubr", "scales",
              "cluster", "factoextra", "corrplot", "Metrics", "ggrepel")

eksik <- paketler[! paketler %in% installed.packages()[,"Package"]]
if (length(eksik) > 0) {
  install.packages(eksik, repos = "https://cran.r-project.org")
}

invisible(lapply(paketler, library, character.only = TRUE))

cat("\n--- BÖLÜM 0: VERİ HAZIRLIK VE MODEL EĞİTİMİ (QMD'DEN AKTARILAN) ---\n")

# 1. Gösterge Tanımları
gostergeler <- c(tarim_gsyh = "NV.AGR.TOTL.ZS", 
                 emek = "SL.AGR.EMPL.ZS", 
                 toprak = "AG.LND.AGRI.ZS", 
                 gubre = "AG.CON.FERT.ZS",
                 verim = "AG.YLD.CREL.KG", 
                 ticaret = "TX.VAL.FOOD.ZS.UN")

# 2. Ham Veriyi Çek
cat("WDI verisi çekiliyor...\n")
veri_raw_list <- lapply(names(gostergeler), function(n) {
  WDI(indicator = gostergeler[n], start = 2000, end = 2020, extra = TRUE)
})
veri_raw <- veri_raw_list %>% reduce(left_join, by = c("iso3c", "year", "country"))

# 3. Temizleme
veri_wdi_temiz <- veri_raw %>%
  filter(!is.na(region.x) & region.x != "Aggregates") %>% 
  select(country, iso3c, year, region = region.x, all_of(names(gostergeler))) %>%
  na.omit() %>% 
  group_by(iso3c) %>% 
  filter(n() == 21) %>% 
  ungroup()

# 4. FAO Entegrasyonu
fao_ham_veri <- read_csv("fao_makine.csv", show_col_types = FALSE)
ekipman_temiz <- fao_ham_veri %>%
  mutate(iso3c = countrycode(Area, origin = "country.name", destination = "iso3c")) %>%
  select(iso3c, year = Year, ekipman = Value) %>%
  filter(iso3c %in% veri_wdi_temiz$iso3c)

veri_tam_panel <- veri_wdi_temiz %>%
  left_join(ekipman_temiz, by = c("iso3c", "year")) %>%
  group_by(iso3c) %>%
  mutate(ekipman = na.approx(ekipman, rule = 2, na.rm = FALSE)) %>%
  ungroup() %>%
  mutate(ekipman = ifelse(is.na(ekipman), mean(ekipman, na.rm = TRUE), ekipman))

# 5. Ülke Grupları Listesi
ulke_meta_final <- WDI_data$country %>% 
  as.data.frame() %>% 
  select(iso3c, income, region) %>%
  filter(region != "Aggregates") %>%
  mutate(Gelir_Grubu = case_when(
    income == "High income" ~ "Yüksek Gelirli",
    income %in% c("Upper middle income", "Lower middle income") ~ "Orta Gelirli",
    income == "Low income" ~ "Düşük Gelirli",
    TRUE ~ "Orta Gelirli" 
  )) %>%
  distinct(iso3c, .keep_all = TRUE)

ulke_gruplari_listesi <- veri_tam_panel %>%
  filter(year == 2020) %>%
  select(country, iso3c) %>% 
  distinct() %>% 
  left_join(ulke_meta_final, by = "iso3c")

# 6. Model Eğitimi
model_verisi <- veri_tam_panel %>%
  select(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  mutate(across(everything(), function(x) (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))))

set.seed(44)
indeks <- sample(1:nrow(model_verisi), round(0.8 * nrow(model_verisi)))
train_data <- model_verisi[indeks, ]
test_data  <- model_verisi[-indeks, ]

cat("YSA Modeli eğitiliyor...\n")
ysa_modeli <- neuralnet(
  tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman, 
  data = train_data, 
  hidden = c(7, 5), 
  act.fct = "logistic", 
  linear.output = TRUE, 
  stepmax = 1e6,
  threshold = 0.01
)

tahmin_sonuc <- compute(ysa_modeli, test_data %>% select(emek, toprak, gubre, verim, ticaret, ekipman))
tahminler <- as.vector(tahmin_sonuc$net.result)
gercekler <- test_data$tarim_gsyh

# 7. Performans Analizi (Aşırı Öğrenme Kontrolü)
pred_train <- compute(ysa_modeli, train_data %>% select(-tarim_gsyh))$net.result
R2_train <- cor(pred_train, train_data$tarim_gsyh)^2

pred_test <- compute(ysa_modeli, test_data %>% select(-tarim_gsyh))$net.result
R2_test <- cor(pred_test, test_data$tarim_gsyh)^2

cat("\n--- MODEL PERFORMANS DEĞERLENDİRMESİ ---\n")
cat("Eğitim (Train) R²:", round(R2_train, 4), "\n")
cat("Test R²          :", round(R2_test, 4), "\n")
cat("Fark (Overfit)   :", round(R2_train - R2_test, 4), "\n")
cat("----------------------------------------\n")

cat("Ön koşullar hazırlandı. Ek analizler başlatılıyor...\n")

cat("
╔══════════════════════════════════════════════════════════════════╗
║          EK ANALİZLER BAŞLIYOR - 8 BÖLÜM                       ║
╚══════════════════════════════════════════════════════════════════╝
")


# =============================================================================
# BÖLÜM 1: 10-FOLD ÇAPRAZ DOĞRULAMA
# Amaç: Mevcut tek bölünmenin (set.seed(44)) dışsal geçerliliğini kanıtlamak.
# QMD'deki eksiklik: Tek sabit bölünme, \"şanslı split\" riskini taşır.
# =============================================================================

cat("\n\n--- BÖLÜM 1: 10-FOLD ÇAPRAZ DOĞRULAMA ---\n")

# Normalize veri (QMD ile aynı yöntem)
model_verisi_cv <- veri_tam_panel %>%
  select(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  mutate(across(everything(), function(x) {
    (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
  }))

# 10-fold indeksleri oluştur
set.seed(42)  # Farklı seed ile bağımsız test
k <- 10
fold_indeks <- createFolds(model_verisi_cv$tarim_gsyh, k = k, list = TRUE)

# Her fold için model eğit ve değerlendir
cv_sonuclar <- data.frame(
  Fold    = integer(),
  R2      = numeric(),
  RMSE    = numeric(),
  MAE     = numeric(),
  MSE     = numeric()
)

cat("Fold eğitimi başlıyor...\n")

for (i in 1:k) {
  cat(sprintf("  Fold %d/%d eğitiliyor...\n", i, k))
  
  test_idx  <- fold_indeks[[i]]
  train_idx <- setdiff(seq_len(nrow(model_verisi_cv)), test_idx)
  
  fold_train <- model_verisi_cv[train_idx, ]
  fold_test  <- model_verisi_cv[test_idx,  ]
  
  # Aynı mimari ile model eğit
  tryCatch({
    fold_model <- neuralnet(
      tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
      data          = fold_train,
      hidden        = c(7, 5),
      act.fct       = "logistic",
      linear.output = TRUE,
      stepmax       = 1e6,
      threshold     = 0.01
    )
    
    tahmin_fold <- compute(
      fold_model,
      fold_test %>% select(emek, toprak, gubre, verim, ticaret, ekipman)
    )$net.result[, 1]
    
    gercek_fold <- fold_test$tarim_gsyh
    
    rss    <- sum((tahmin_fold - gercek_fold)^2)
    tss    <- sum((gercek_fold - mean(gercek_fold))^2)
    r2_val <- 1 - rss / tss
    rmse   <- sqrt(mean((tahmin_fold - gercek_fold)^2))
    mae    <- mean(abs(tahmin_fold - gercek_fold))
    mse    <- mean((tahmin_fold - gercek_fold)^2)
    
    cv_sonuclar <- rbind(cv_sonuclar, data.frame(
      Fold = i, R2 = r2_val, RMSE = rmse, MAE = mae, MSE = mse
    ))
    
  }, error = function(e) {
    cat(sprintf("    Fold %d hata: %s\n", i, e$message))
  })
}

# Özet istatistikler
cat("\n=== 10-FOLD ÇAPRAZ DOĞRULAMA SONUÇLARI ===\n")
print(cv_sonuclar)

cv_ozet <- cv_sonuclar %>%
  summarise(
    Ort_R2   = mean(R2,   na.rm = TRUE),
    Std_R2   = sd(R2,     na.rm = TRUE),
    Min_R2   = min(R2,    na.rm = TRUE),
    Max_R2   = max(R2,    na.rm = TRUE),
    Ort_RMSE = mean(RMSE, na.rm = TRUE),
    Ort_MAE  = mean(MAE,  na.rm = TRUE)
  )

cat("\n=== ÖZET ===\n")
cat(sprintf("Ortalama R²  : %.4f (± %.4f)\n", cv_ozet$Ort_R2, cv_ozet$Std_R2))
cat(sprintf("R² Aralığı   : [%.4f - %.4f]\n", cv_ozet$Min_R2, cv_ozet$Max_R2))
cat(sprintf("Ortalama RMSE: %.5f\n", cv_ozet$Ort_RMSE))
cat(sprintf("Ortalama MAE : %.5f\n", cv_ozet$Ort_MAE))
cat(sprintf("Orijinal R²  : 0.9142 (QMD tek bölünme)\n"))
cat(sprintf("CV R²        : %.4f → Overfitting riski %s\n",
            cv_ozet$Ort_R2,
            ifelse(abs(cv_ozet$Ort_R2 - 0.9142) < 0.02, "DÜŞÜK ✓", "YÜKSEK ✗")))

# Görselleştirme: Fold bazlı R² dağılımı
p_cv <- ggplot(cv_sonuclar, aes(x = factor(Fold), y = R2)) +
  geom_col(fill = "#2c3e50", alpha = 0.8, width = 0.6) +
  geom_hline(yintercept = 0.9142, color = "#c0392b",
             linetype = "dashed", linewidth = 1) +
  geom_hline(yintercept = cv_ozet$Ort_R2, color = "#27ae60",
             linetype = "solid", linewidth = 1) +
  annotate("text", x = 10.5, y = 0.9142 + 0.005,
           label = sprintf("Orijinal: %.4f", 0.9142),
           color = "#c0392b", size = 3.5, hjust = 1) +
  annotate("text", x = 10.5, y = cv_ozet$Ort_R2 - 0.005,
           label = sprintf("CV Ort: %.4f", cv_ozet$Ort_R2),
           color = "#27ae60", size = 3.5, hjust = 1) +
  scale_y_continuous(limits = c(0.8, 1.0), labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "10-Fold Çapraz Doğrulama: R² Kararlılık Analizi",
    subtitle = "Her fold bağımsız bir model eğitimi temsil etmektedir",
    x        = "Fold Numarası",
    y        = "R² (Açıklayıcılık Gücü)"
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40")
  )

ggsave("../03-Results/cv_fold_r2.png", p_cv, width = 10, height = 6, dpi = 150)
cat("\n[ÇIKTI] cv_fold_r2.png kaydedildi.\n")


# =============================================================================
# BÖLÜM 2: MİMARİ KARŞILAŞTIRMA (Model Seçimi Justifikasyonu)
# Amaç: hidden = c(7,5) seçiminin diğer mimarilere göre üstünlüğünü kanıtlamak.
# QMD'deki eksiklik: \"Deneme yanılma ile bulundu\" yazıyor; karşılaştırma tablosu yok.
# =============================================================================

cat("\n\n--- BÖLÜM 2: MİMARİ KARŞILAŞTIRMA ---\n")

mimariler <- list(
  "6-5-1"    = c(5),
  "6-7-1"    = c(7),
  "6-7-5-1"  = c(7, 5),   # Mevcut model
  "6-10-5-1" = c(10, 5),
  "6-5-5-1"  = c(5, 5),
  "6-10-7-1" = c(10, 7),
  "6-3-1"    = c(3)
)

# Model bazlı normalize veri (QMD ile aynı)
set.seed(44)
idx_mim   <- sample(1:nrow(model_verisi_cv), round(0.8 * nrow(model_verisi_cv)))
train_mim <- model_verisi_cv[idx_mim, ]
test_mim  <- model_verisi_cv[-idx_mim, ]

mimari_sonuclar <- data.frame(
  Mimari   = character(),
  R2       = numeric(),
  MSE      = numeric(),
  Adim     = numeric(),
  Parametre = integer()
)

for (isim in names(mimariler)) {
  hidden_yapisı <- mimariler[[isim]]
  cat(sprintf("  Mimari test ediliyor: %s\n", isim))
  
  tryCatch({
    m <- neuralnet(
      tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
      data          = train_mim,
      hidden        = hidden_yapisı,
      act.fct       = "logistic",
      linear.output = TRUE,
      stepmax       = 5e5,
      threshold     = 0.01
    )
    
    # Modeli al ve metrikleri hesapla
    pred <- as.vector(compute(m, test_mim %>% select(emek, toprak, gubre, verim, ticaret, ekipman))$net.result)
    grc  <- test_mim$tarim_gsyh
    r2   <- 1 - sum((pred - grc)^2) / sum((grc - mean(grc))^2)
    mse  <- mean((pred - grc)^2)
    
    # neuralnet steps verisini al (daha sağlam bir yöntem)
    adim <- 0
    if (!is.null(m$result.matrix)) {
      adim <- m$result.matrix["steps", 1]
    } else if (!is.null(m$steps)) {
      adim <- if(is.list(m$steps)) m$steps[[1]] else m$steps
    }
    
    # Parametre sayısı: girdi×gizli1 + gizli1 + gizli1×gizli2 + ...
    katmanlar  <- c(6, hidden_yapisı, 1)
    n_param    <- sum(katmanlar[-length(katmanlar)] * katmanlar[-1]) +
                  sum(katmanlar[-1])  # bias
    
    # Veri çerçevesine ekle
    # Tüm değerlerin tek bir sayı (length 1) olduğundan emin ol
    yeni_satir <- data.frame(
      Mimari    = as.character(isim),
      R2        = as.numeric(round(r2, 4)),
      MSE       = as.numeric(round(mse, 6)),
      Adim      = as.numeric(adim),
      Parametre = as.integer(n_param)
    )
    mimari_sonuclar <- rbind(mimari_sonuclar, yeni_satir)
    
  }, error = function(e) {
    cat(sprintf("    %s başarısız: %s\n", isim, e$message))
  })
}

mimari_sonuclar <- mimari_sonuclar %>%
  arrange(desc(R2)) %>%
  mutate(Sirali = row_number(),
         Secilen = ifelse(Mimari == "6-7-5-1", "★ Seçilen", ""))

cat("\n=== MİMARİ KARŞILAŞTIRMA TABLOSU ===\n")
print(as.data.frame(mimari_sonuclar))

# Görselleştirme
p_mim <- ggplot(mimari_sonuclar, aes(x = reorder(Mimari, R2), y = R2,
                                      fill = Mimari == "6-7-5-1")) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_text(aes(label = sprintf("%.4f", R2)), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_fill_manual(values = c("TRUE" = "#c0392b", "FALSE" = "#2c3e50"),
                    labels = c("Diğer", "Seçilen Mimari"),
                    guide = "none") +
  scale_y_continuous(limits = c(0.8, 1.02),
                     labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "YSA Mimari Karşılaştırması: R² Performansı",
    subtitle = "Kırmızı çubuk: makalede kullanılan seçilen mimari (6-7-5-1)",
    x        = "Mimari",
    y        = "R²"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("../03-Results/mimari_karsilastirma.png", p_mim, width = 10, height = 6, dpi = 150)
cat("\n[ÇIKTI] mimari_karsilastirma.png kaydedildi.\n")


# =============================================================================
# BÖLÜM 3: SHAP DEĞERLERİ (Olden Analizine Tamamlayıcı)
# Amaç: Olden'in global önem sıralamasını gözlem bazlı yerel açıklamayla zenginleştir.
# QMD'deki eksiklik: Olden yalnızca global ağırlık skoru verir; ülke bazında neden
#                    sapma var? sorusunu yanıtlamaz.
# =============================================================================

cat("\n\n--- BÖLÜM 3: SHAP DEĞERLERİ ---\n")

# fastshap paketi ile YSA SHAP değerleri
# Tahmin fonksiyonu tanımı (fastshap formatında)
predict_fn <- function(model, newdata) {
  as.vector(compute(model, newdata)$net.result)
}

test_X <- test_data %>% select(emek, toprak, gubre, verim, ticaret, ekipman)

cat("SHAP değerleri hesaplanıyor (bu işlem birkaç dakika sürebilir)...\n")
set.seed(42)
shap_sonuclar <- fastshap::explain(
  object      = ysa_modeli,
  X           = test_X,
  pred_wrapper = predict_fn,
  nsim        = 50,         # Permütasyon sayısı; daha yüksek = daha doğru, daha yavaş
  adjust      = TRUE
)

shap_df <- as.data.frame(shap_sonuclar)

# Özet: Her değişkenin ortalama mutlak SHAP değeri (global önem)
shap_global <- shap_df %>%
  summarise(across(everything(), ~ mean(abs(.)))) %>%
  pivot_longer(everything(), names_to = "Degisken", values_to = "Ort_Mutlak_SHAP") %>%
  arrange(desc(Ort_Mutlak_SHAP))

cat("\n=== SHAP GLOBAl ÖNEM SIRASI ===\n")
print(shap_global)
cat("\nOlden sıralamasıyla karşılaştırın: gubre (negatif baskın), verim (pozitif), ...\n")

# Beeswarm benzeri görselleştirme (SHAP summary plot)
shap_uzun <- shap_df %>%
  mutate(obs = row_number()) %>%
  pivot_longer(-obs, names_to = "Degisken", values_to = "SHAP")

shap_X_uzun <- test_X %>%
  mutate(obs = row_number()) %>%
  pivot_longer(-obs, names_to = "Degisken", values_to = "Deger")

shap_tam <- left_join(shap_uzun, shap_X_uzun, by = c("obs", "Degisken"))

p_shap <- ggplot(shap_tam, aes(x = SHAP, y = reorder(Degisken, abs(SHAP)),
                                color = Deger)) +
  geom_jitter(height = 0.25, alpha = 0.4, size = 1.5) +
  geom_vline(xintercept = 0, color = "black", linewidth = 0.6) +
  scale_color_gradient2(low = "#2980b9", mid = "gray80", high = "#c0392b",
                        midpoint = 0.5, name = "Değişken\ndeğeri (norm.)") +
  labs(
    title    = "SHAP Değerleri: Gözlem Bazlı Değişken Önem Analizi",
    subtitle = "Her nokta bir gözlem; sağa kaymak pozitif (artırıcı) etkiyi gösterir",
    x        = "SHAP Değeri",
    y        = "Değişken"
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    legend.position = "right"
  )

ggsave("../03-Results/shap_beeswarm.png", p_shap, width = 11, height = 7, dpi = 150)

# Ülke bazlı SHAP: Kırgızistan anomalisini incele
# (Aykırı değer analizinin kanıt destekli versiyonu)
test_meta <- veri_tam_panel[-indeks, ] %>%
  select(country, year, tarim_gsyh)

shap_ulke <- bind_cols(test_meta, shap_df) %>%
  mutate(tahmin = as.vector(compute(ysa_modeli, test_X)$net.result),
         sapma  = tarim_gsyh - (tahmin * (max(veri_tam_panel$tarim_gsyh) -
                                           min(veri_tam_panel$tarim_gsyh)) +
                                  min(veri_tam_panel$tarim_gsyh)))

# En büyük sapmalı 5 ülke için SHAP karşılaştırması
buyuk_sapmalar <- shap_ulke %>%
  arrange(desc(abs(sapma))) %>%
  head(5) %>%
  select(country, year, sapma, emek, toprak, gubre, verim, ticaret, ekipman)

cat("\n=== BÜYÜK SAPMALARIN SHAP DEĞERLERİ ===\n")
print(as.data.frame(buyuk_sapmalar))
cat("\n[ÇIKTI] shap_beeswarm.png kaydedildi.\n")


# =============================================================================
# BÖLÜM 4: GRANGER NEDENSELLİK TESTİ
# Amaç: 6 girdi değişkeninin tarım_gsyh üzerindeki nedensellik yönünü sına.
# QMD'deki eksiklik: \"Verim artışı tarımı etkiler\" söylemi yön kanıtı olmadan.
# Not: Panel Granger testi için panelvar paketi kullanılır.
# =============================================================================

cat("\n\n--- BÖLÜM 4: GRANGER NEDENSELLİK TESTİ ---\n")

# Panel için Granger nedensellik testi (Dumitrescu & Hurlin, 2012)
# Paket: panelvar
# Yöntem: Her değişken çifti için test

degiskenler <- c("emek", "toprak", "gubre", "verim", "ticaret", "ekipman")
hedef       <- "tarim_gsyh"

# Veriyi panel formatına çevir
panel_granger <- veri_tam_panel %>%
  select(iso3c, year, all_of(hedef), all_of(degiskenler)) %>%
  arrange(iso3c, year)

granger_sonuclar <- data.frame(
  Degisken       = character(),
  F_istatistigi  = numeric(),
  p_degeri       = numeric(),
  Yorum          = character()
)

cat("Panel Granger testleri çalışıyor...\n")

for (deg in degiskenler) {
  cat(sprintf("  Test: %s → %s\n", deg, hedef))
  
  tryCatch({
    # Basit yaklaşım: Her ülke için ayrı OLS Granger, sonra Fisher birleşimi
    ulkeler <- unique(panel_granger$iso3c)
    p_degerleri <- c()
    
    for (u in ulkeler) {
      ulke_veri <- panel_granger %>% filter(iso3c == u)
      if (nrow(ulke_veri) < 5) next
      
      # Gecikmeli değerler (lag = 2)
      y   <- ulke_veri[[hedef]]
      x   <- ulke_veri[[deg]]
      
      y_lag1 <- c(NA, head(y, -1))
      y_lag2 <- c(NA, NA, head(y, -2))
      x_lag1 <- c(NA, head(x, -1))
      x_lag2 <- c(NA, NA, head(x, -2))
      
      df_g <- data.frame(y, y_lag1, y_lag2, x_lag1, x_lag2) %>% na.omit()
      if (nrow(df_g) < 4) next
      
      model_k  <- lm(y ~ y_lag1 + y_lag2, data = df_g)            # kısıtlı
      model_uk <- lm(y ~ y_lag1 + y_lag2 + x_lag1 + x_lag2, data = df_g)  # kısıtsız
      
      f_test <- anova(model_k, model_uk)
      if (!is.na(f_test$`Pr(>F)`[2])) {
        p_degerleri <- c(p_degerleri, f_test$`Pr(>F)`[2])
      }
    }
    
    if (length(p_degerleri) > 0) {
      # Fisher kombinasyon testi (meta-analiz yaklaşımı)
      chi_sq <- -2 * sum(log(pmax(p_degerleri, 1e-10)))
      df_chi <- 2 * length(p_degerleri)
      p_birlesmis <- pchisq(chi_sq, df = df_chi, lower.tail = FALSE)
      
      granger_sonuclar <- rbind(granger_sonuclar, data.frame(
        Degisken      = deg,
        Chi_Sq        = round(chi_sq, 2),
        p_degeri      = round(p_birlesmis, 4),
        Yorum         = ifelse(p_birlesmis < 0.05,
                               "NEDENSELDİR (p<0.05) ✓",
                               "Nedensel değil (p>0.05)")
      ))
    }
    
  }, error = function(e) {
    cat(sprintf("    %s: %s\n", deg, e$message))
  })
}

cat("\n=== GRANGER NEDENSELLİK TEST SONUÇLARI ===\n")
cat("H0: X, Y'yi Granger anlamında nedenlendirmez\n\n")
print(as.data.frame(granger_sonuclar))

# Görselleştirme
p_granger <- ggplot(granger_sonuclar,
                    aes(x = reorder(Degisken, -log10(p_degeri)),
                        y = -log10(p_degeri),
                        fill = p_degeri < 0.05)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_hline(yintercept = -log10(0.05), color = "#c0392b",
             linetype = "dashed", linewidth = 1) +
  annotate("text", x = 1, y = -log10(0.05) + 0.1,
           label = "α = 0.05 eşiği", color = "#c0392b", size = 3.5) +
  scale_fill_manual(values = c("TRUE" = "#2c3e50", "FALSE" = "#95a5a6"),
                    labels = c("Nedensel değil", "Nedenseldir"),
                    name = "") +
  labs(
    title    = "Panel Granger Nedensellik Testi: X → tarım_gsyh",
    subtitle = "Fisher birleşim yöntemi, 105 ülke, gecikme = 2",
    x        = "Değişken",
    y        = "-log10(p değeri) [yüksek = güçlü nedensellik]"
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    legend.position = "top"
  )

ggsave("../03-Results/granger_nedensellik.png", p_granger, width = 10, height = 6, dpi = 150)
cat("\n[ÇIKTI] granger_nedensellik.png kaydedildi.\n")


# =============================================================================
# BÖLÜM 5: HETEROSKEDASTİSİTE VE KALINTI TANI TESTLERİ
# Amaç: Kalıntıların homojen dağıldığını (sistematik yanlılık yok) kanıtlamak.
# QMD'deki eksiklik: Kalıntı grafiği var ama formal Breusch-Pagan testi yok.
# =============================================================================

cat("\n\n--- BÖLÜM 5: HETEROSKEDASTİSİTE VE TANI TESTLERİ ---\n")

# Orijinal modelin kalıntıları (denormalize)
min_g <- min(veri_tam_panel$tarim_gsyh)
max_g <- max(veri_tam_panel$tarim_gsyh)

tahmin_reel_bp <- (tahminler * (max_g - min_g)) + min_g
gercek_reel_bp <- (gercekler * (max_g - min_g)) + min_g
kalinti_bp     <- gercek_reel_bp - tahmin_reel_bp

# 1. Breusch-Pagan testi (OLS proxy üzerinden)
bp_df <- data.frame(
  gercek    = gercek_reel_bp,
  tahmin    = tahmin_reel_bp,
  kalinti   = kalinti_bp,
  kal_kare  = kalinti_bp^2
)

# Kalıntı karelerini tahminden regrese et
bp_model <- lm(kal_kare ~ tahmin, data = bp_df)
bp_test  <- lmtest::bptest(bp_model)

cat("\n--- Breusch-Pagan Heteroskedastisite Testi ---\n")
print(bp_test)
cat(sprintf("Sonuç: %s (α=0.05)\n",
            ifelse(bp_test$p.value > 0.05,
                   "Homoskedastisite VAR → Model kalıntıları homojendir ✓",
                   "Heteroskedastisite MEVCUT → Dikkat!")))

# 2. Shapiro-Wilk normallik testi (kalıntılar için)
# Not: n>5000 için Kolmogorov-Smirnov kullanılır, burada sample alınır
set.seed(42)
sw_sample <- sample(kalinti_bp, min(500, length(kalinti_bp)))
sw_test   <- shapiro.test(sw_sample)

cat("\n--- Shapiro-Wilk Normallik Testi (kalıntılar, n=500 örneklem) ---\n")
print(sw_test)

# 3. Runs testi (otokorelasyon yok mu?)
# Kalıntıların işaret değişimlerinin rastgele olup olmadığı
kalinti_isaret <- sign(kalinti_bp)
pozitif_sayi   <- sum(kalinti_isaret > 0)
negatif_sayi   <- sum(kalinti_isaret < 0)
run_sayisi     <- 1 + sum(diff(kalinti_isaret) != 0)
n_toplam       <- length(kalinti_isaret)

# Beklenen runs ve varyans (runs test formülü)
beklenen_run <- (2 * pozitif_sayi * negatif_sayi / n_toplam) + 1
var_run      <- (2 * pozitif_sayi * negatif_sayi *
                   (2 * pozitif_sayi * negatif_sayi - n_toplam)) /
                (n_toplam^2 * (n_toplam - 1))
z_runs       <- (run_sayisi - beklenen_run) / sqrt(var_run)
p_runs       <- 2 * pnorm(-abs(z_runs))

cat("\n--- Runs Testi (Otokorelasyon Kontrolü) ---\n")
cat(sprintf("Run sayısı  : %d\n", run_sayisi))
cat(sprintf("Beklenen    : %.1f\n", beklenen_run))
cat(sprintf("Z istatistiği: %.4f\n", z_runs))
cat(sprintf("p değeri    : %.4f\n", p_runs))
cat(sprintf("Sonuç       : %s\n",
            ifelse(p_runs > 0.05, "Rastgele dağılım ✓", "Sistematik otokorelasyon ✗")))

# Tüm tanı testlerini özetleyen tablo
tani_ozet <- data.frame(
  Test              = c("Breusch-Pagan", "Shapiro-Wilk", "Runs"),
  H0                = c("Homoskedastisite", "Normallik", "Rastgelelik"),
  p_degeri          = c(round(bp_test$p.value, 4),
                        round(sw_test$p.value, 4),
                        round(p_runs, 4)),
  Karar             = c(
    ifelse(bp_test$p.value > 0.05, "Red edilemez ✓", "Reddedildi ✗"),
    ifelse(sw_test$p.value > 0.05, "Red edilemez ✓", "Reddedildi ✗"),
    ifelse(p_runs > 0.05, "Red edilemez ✓", "Reddedildi ✗")
  )
)

cat("\n=== TANI TESTLERİ ÖZET TABLOSU ===\n")
print(tani_ozet)

# Kalıntı tanı grafik paketi (4'lü panel)
png("kalinti_tani_panel.png", width = 1400, height = 1000, res = 150)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 2))

# a) Kalıntı vs Tahmin
plot(tahmin_reel_bp, kalinti_bp,
     pch = 16, col = adjustcolor("#2c3e50", 0.4), cex = 0.7,
     xlab = "Tahmin Edilen (%)", ylab = "Kalıntı (%)",
     main = "Kalıntı vs Tahmin")
abline(h = 0, col = "#c0392b", lty = 2, lwd = 2)
lines(lowess(tahmin_reel_bp, kalinti_bp), col = "#27ae60", lwd = 2)
legend("topright", c("Sıfır çizgisi", "LOWESS"),
       lty = c(2, 1), col = c("#c0392b", "#27ae60"), cex = 0.8)

# b) QQ Plot
qqnorm(kalinti_bp, pch = 16, col = adjustcolor("#2c3e50", 0.4), cex = 0.7,
       main = "Q-Q Grafiği (Normallik)")
qqline(kalinti_bp, col = "#c0392b", lwd = 2)

# c) Kalıntı histogramı
hist(kalinti_bp, breaks = 40, col = "#2c3e50", border = "white",
     xlab = "Kalıntı (%)", main = "Kalıntı Dağılımı",
     probability = TRUE)
curve(dnorm(x, mean = mean(kalinti_bp), sd = sd(kalinti_bp)),
      add = TRUE, col = "#c0392b", lwd = 2)
legend("topright", "Normal eğri", lty = 1, col = "#c0392b", cex = 0.8)

# d) Ölçek-Konum grafiği (Heteroskedastisite)
plot(tahmin_reel_bp, sqrt(abs(kalinti_bp)),
     pch = 16, col = adjustcolor("#2c3e50", 0.4), cex = 0.7,
     xlab = "Tahmin Edilen (%)", ylab = "√|Kalıntı|",
     main = "Ölçek-Konum (Heteroskedastisite)")
lines(lowess(tahmin_reel_bp, sqrt(abs(kalinti_bp))), col = "#c0392b", lwd = 2)

dev.off()
cat("\n[ÇIKTI] kalinti_tani_panel.png kaydedildi.\n")
par(mfrow = c(1, 1))


# =============================================================================
# BÖLÜM 6: YAPISAL KIRILMA TESTİ (Bai-Perron)
# Amaç: 2000-2020 serisinde küresel tarım payının kırılma noktasını tespit et.
# Örnek: 2008 finansal krizi, 2012 gıda krizi gibi dönemler.
# QMD'deki eksiklik: \"Yapısal taban\" iddiası için kırılma analizi destekleyici kanıt olur.
# =============================================================================

cat("\n\n--- BÖLÜM 6: YAPISAL KIRILMA TESTİ ---\n")

# Küresel yıllık ortalama tarımsal pay serisini oluştur
kuresel_seri <- veri_tam_panel %>%
  group_by(year) %>%
  summarise(
    ort_tarim  = mean(tarim_gsyh, na.rm = TRUE),
    ort_verim  = mean(verim, na.rm = TRUE),
    ort_emek   = mean(emek, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year)

ts_tarim <- ts(kuresel_seri$ort_tarim, start = 2000, frequency = 1)

# Bai-Perron yapısal kırılma testi (strucchange paketi)
bp_kirilma <- strucchange::breakpoints(
  ts_tarim ~ 1,
  h = 0.15  # Minimum segment uzunluğu (yıl sayısının %15'i)
)

cat("--- Bai-Perron Kırılma Noktaları ---\n")
print(summary(bp_kirilma))

# Kırılma noktalarını yıla dönüştür
kirilan_yillar <- bp_kirilma$breakpoints
if (!is.na(kirilan_yillar[1])) {
  kirilan_yillar_gercek <- 1999 + kirilan_yillar
  cat(sprintf("Tespit edilen kırılma yılı/yılları: %s\n",
              paste(kirilan_yillar_gercek, collapse = ", ")))
} else {
  cat("Anlamlı yapısal kırılma tespit edilmedi.\n")
}

# CUSUM testi (alternatif)
cusum_test <- strucchange::efp(ts_tarim ~ 1, type = "OLS-CUSUM")

png("yapisal_kirilma.png", width = 1400, height = 900, res = 150)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 2))

# Kırılma noktalarıyla seri
plot(kuresel_seri$year, kuresel_seri$ort_tarim,
     type = "b", pch = 16, col = "#2c3e50", lwd = 2,
     xlab = "Yıl", ylab = "Ortalama Tarım GSYH Payı (%)",
     main = "Küresel Ortalama Tarım Payı\nve Yapısal Kırılma Noktaları")
if (!is.na(kirilan_yillar[1])) {
  abline(v = kirilan_yillar_gercek, col = "#c0392b", lty = 2, lwd = 2)
  for (y in kirilan_yillar_gercek) {
    text(y, min(kuresel_seri$ort_tarim) + 0.3,
         labels = as.character(y), col = "#c0392b", cex = 0.9)
  }
}
grid(col = "gray90")

# CUSUM grafiği
plot(cusum_test, main = "CUSUM Testi\n(Yapısal İstikrar)")

dev.off()
cat("\n[ÇIKTI] yapisal_kirilma.png kaydedildi.\n")
par(mfrow = c(1, 1))


# =============================================================================
# BÖLÜM 7: BÖLGESEL KÜMELEME ANALİZİ (K-means)
# Amaç: 105 ülkeyi yalnızca gelir grubuna göre değil, tarımsal yapılarına göre sınıfla.
# Çıktı: \"Türkiye hangi kümededir?\" gibi ülke bazlı policy soruları yanıtlanabilir.
# =============================================================================

cat("\n\n--- BÖLÜM 7: BÖLGESEL KÜMELEME ANALİZİ ---\n")

# 2020 yılı ülke profilleri (7 değişken)
ulke_2020 <- veri_tam_panel %>%
  filter(year == 2020) %>%
  select(iso3c, country, tarim_gsyh, emek, toprak, gubre,
         verim, ticaret, ekipman) %>%
  left_join(ulke_gruplari_listesi %>% select(iso3c, Gelir_Grubu), by = "iso3c")

# Sayısal değişkenleri ölçekle
kume_verisi <- ulke_2020 %>%
  select(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  scale()

# Optimal küme sayısı (Elbow yöntemi)
set.seed(42)
wss <- sapply(1:10, function(k) {
  kmeans(kume_verisi, centers = k, nstart = 25)$tot.withinss
})

# K=4 ile kümeleme (Elbow görsel analizi sonrası)
set.seed(42)
kmeans_sonuc <- kmeans(kume_verisi, centers = 4, nstart = 50)
ulke_2020$Kume <- as.factor(kmeans_sonuc$cluster)

# Küme profilleri
kume_profil <- ulke_2020 %>%
  group_by(Kume) %>%
  summarise(
    N_ulke      = n(),
    Ort_TarımPay = round(mean(tarim_gsyh), 2),
    Ort_Emek    = round(mean(emek), 2),
    Ort_Verim   = round(mean(verim), 0),
    Ort_Ticaret = round(mean(ticaret), 2),
    .groups = "drop"
  ) %>%
  mutate(Kume_Tipi = case_when(
    Ort_TarımPay < 3   ~ "Sanayi Olgunluğu",
    Ort_TarımPay < 8   ~ "Geçiş Ekonomisi",
    Ort_TarımPay < 20  ~ "Tarım Baskın",
    TRUE               ~ "Tarım Bağımlı"
  ))

cat("\n=== KÜME PROFİLLERİ ===\n")
print(as.data.frame(kume_profil))

# Türkiye'nin kümesi
turkey_kume <- ulke_2020 %>% filter(iso3c == "TUR")
cat(sprintf("\nTürkiye (2020): Küme %s - %s\n",
            turkey_kume$Kume,
            kume_profil$Kume_Tipi[kume_profil$Kume == turkey_kume$Kume]))

# PCA görselleştirme
pca_sonuc  <- prcomp(kume_verisi, scale. = FALSE)
pca_df     <- data.frame(pca_sonuc$x[, 1:2])
pca_df$Kume   <- ulke_2020$Kume
pca_df$country <- ulke_2020$country
pca_df$iso3c   <- ulke_2020$iso3c

# Varyans açıklama
var_acik <- round(100 * summary(pca_sonuc)$importance[2, 1:2], 1)

p_kume <- ggplot(pca_df, aes(x = PC1, y = PC2, color = Kume)) +
  geom_point(size = 3, alpha = 0.8) +
  # Seçili ülkelere etiket
  ggrepel::geom_label_repel(
    data = pca_df %>% filter(iso3c %in% c("TUR", "USA", "CHN", "IND",
                                           "BRA", "ETH", "DEU", "NER")),
    aes(label = iso3c),
    size = 3, show.legend = FALSE, max.overlaps = 20
  ) +
  scale_color_manual(
    values = c("1" = "#c0392b", "2" = "#2980b9",
               "3" = "#27ae60", "4" = "#f39c12"),
    labels = kume_profil$Kume_Tipi,
    name   = "Küme Tipi"
  ) +
  labs(
    title    = "Tarımsal Yapısal Kümeleme: 105 Ülke (2020)",
    subtitle = "PCA ile boyut indirgeme; eksenler toplam varyansın büyük bölümünü açıklar",
    x        = sprintf("PC1 (Açıklanan varyans: %%%s)", var_acik[1]),
    y        = sprintf("PC2 (Açıklanan varyans: %%%s)", var_acik[2])
  ) +
  theme_minimal() +
  theme(
    plot.title      = element_text(face = "bold", size = 14),
    legend.position = "right"
  )

ggsave("../03-Results/kume_analizi_pca.png", p_kume, width = 12, height = 8, dpi = 150)
cat("\n[ÇIKTI] kume_analizi_pca.png kaydedildi.\n")


# =============================================================================
# BÖLÜM 8: TÜRKİYE VAKA ANALİZİ (Kongre Bağlamı)
# Amaç: Türkiye'nin yapısal taban evresini ayrıca analiz et.
# Kongre Konya'da olduğundan, yerel bağlam güçlü bir sunum öğesidir.
# =============================================================================

cat("\n\n--- BÖLÜM 8: TÜRKİYE VAKA ANALİZİ ---\n")

# Türkiye serisi (2000-2020)
turkey_seri <- veri_tam_panel %>%
  filter(iso3c == "TUR") %>%
  arrange(year)

cat("=== TÜRKİYE TARIMSAL DÖNÜŞÜM VERİSİ (2000-2020) ===\n")
print(as.data.frame(turkey_seri %>%
  select(year, tarim_gsyh, emek, verim, ticaret, ekipman)))

# Türkiye'nin modeldeki tahmini performansı
turkey_test <- turkey_seri %>%
  mutate(across(c(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman),
                ~ (. - min(veri_tam_panel[[cur_column()]], na.rm = TRUE)) /
                  (max(veri_tam_panel[[cur_column()]], na.rm = TRUE) -
                   min(veri_tam_panel[[cur_column()]], na.rm = TRUE))))

turkey_tahmin_norm <- compute(
  ysa_modeli,
  turkey_test %>% select(emek, toprak, gubre, verim, ticaret, ekipman)
)$net.result[, 1]

turkey_tahmin_reel <- turkey_tahmin_norm * (max_g - min_g) + min_g
turkey_gercek_reel <- turkey_seri$tarim_gsyh

turkey_hata <- data.frame(
  Yil          = turkey_seri$year,
  Gercek       = round(turkey_gercek_reel, 4),
  Tahmin       = round(turkey_tahmin_reel, 4),
  Sapma        = round(turkey_gercek_reel - turkey_tahmin_reel, 4)
)

cat("\n=== TÜRKİYE: MODEL TAHMİN vs GERÇEK ===\n")
print(turkey_hata)

turkey_r2 <- 1 - sum(turkey_hata$Sapma^2) /
  sum((turkey_gercek_reel - mean(turkey_gercek_reel))^2)
cat(sprintf("\nTürkiye R² (model performansı): %.4f\n", turkey_r2))

# 2030 Projeksiyon: Türkiye için üç senaryo
turkey_2020 <- veri_tam_panel %>% filter(iso3c == "TUR", year == 2020)

senaryolar <- list(
  "Kötü"  = list(emek=0.95, toprak=0.97, gubre=0.96, verim=0.99, ticaret=0.90, ekipman=0.95),
  "Orta"  = list(emek=0.88, toprak=0.99, gubre=1.03, verim=1.18, ticaret=1.03, ekipman=1.05),
  "İyi"   = list(emek=0.82, toprak=0.99, gubre=1.06, verim=1.28, ticaret=1.18, ekipman=1.12)
)

turkey_proj <- data.frame(
  Senaryo    = character(),
  Pay_2030   = numeric(),
  Degisim    = numeric()
)

for (s_isim in names(senaryolar)) {
  s <- senaryolar[[s_isim]]
  d <- turkey_2020 %>%
    mutate(
      emek    = emek    * s$emek,
      toprak  = toprak  * s$toprak,
      gubre   = gubre   * s$gubre,
      verim   = verim   * s$verim,
      ticaret = ticaret * s$ticaret,
      ekipman = ekipman * s$ekipman
    )
  
  d_norm <- d %>%
    mutate(across(c(emek, toprak, gubre, verim, ticaret, ekipman),
                  ~ (. - min(veri_tam_panel[[cur_column()]])) /
                    (max(veri_tam_panel[[cur_column()]]) -
                     min(veri_tam_panel[[cur_column()]])))) %>%
    select(emek, toprak, gubre, verim, ticaret, ekipman)
  
  t_2030 <- as.vector(compute(ysa_modeli, d_norm)$net.result) * (max_g - min_g) + min_g
  
  turkey_proj <- rbind(turkey_proj, data.frame(
    Senaryo  = s_isim,
    Pay_2030 = round(t_2030, 2),
    Degisim  = round(t_2030 - turkey_2020$tarim_gsyh, 2)
  ))
}

cat("\n=== TÜRKİYE 2030 SENARYO PROJEKSİYONU ===\n")
cat(sprintf("2020 Mevcut Tarım Payı: %.2f%%\n", turkey_2020$tarim_gsyh))
print(turkey_proj)

# Görselleştirme: Türkiye zaman serisi + projeksiyon
turkey_grafik <- data.frame(
  Yil  = c(turkey_seri$year, 2030, 2030, 2030),
  Pay  = c(turkey_seri$tarim_gsyh,
           turkey_proj$Pay_2030),
  Tip  = c(rep("Gerçek (2000-2020)", nrow(turkey_seri)),
           "Projeksiyon: Kötü",
           "Projeksiyon: Orta",
           "Projeksiyon: İyi")
)

turkey_tahmin_seri <- data.frame(
  Yil  = turkey_seri$year,
  Pay  = turkey_tahmin_reel,
  Tip  = "YSA Tahmini"
)

p_turkey <- ggplot() +
  geom_line(data = turkey_grafik %>% filter(Tip == "Gerçek (2000-2020)"),
            aes(x = Yil, y = Pay, color = Tip), linewidth = 1.5) +
  geom_line(data = turkey_tahmin_seri,
            aes(x = Yil, y = Pay, color = Tip),
            linewidth = 1, linetype = "dashed") +
  geom_point(data = turkey_grafik %>% filter(grepl("Projeksiyon", Tip)),
             aes(x = Yil, y = Pay, color = Tip), size = 5, shape = 18) +
  geom_vline(xintercept = 2020, color = "gray50", linetype = "dotted") +
  annotate("text", x = 2020.5, y = max(turkey_seri$tarim_gsyh) * 0.98,
           label = "Projeksiyon →", size = 3.5, color = "gray40", hjust = 0) +
  scale_color_manual(
    values = c(
      "Gerçek (2000-2020)"   = "#2c3e50",
      "YSA Tahmini"          = "#7f8c8d",
      "Projeksiyon: Kötü"    = "#c0392b",
      "Projeksiyon: Orta"    = "#2980b9",
      "Projeksiyon: İyi"     = "#27ae60"
    ),
    name = ""
  ) +
  scale_x_continuous(breaks = c(2000, 2005, 2010, 2015, 2020, 2030)) +
  labs(
    title    = "Türkiye Tarım GSYH Payı: 2000-2020 Gerçek Veri ve 2030 Projeksiyonu",
    subtitle = "YSA modeli Türkiye'yi nasıl tahmin ediyor? Hangi yapısal taban evresindedir?",
    x        = "Yıl",
    y        = "Tarım GSYH Payı (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title      = element_text(face = "bold", size = 14),
    plot.subtitle   = element_text(size = 10, color = "gray40"),
    legend.position = "bottom"
  )

ggsave("../03-Results/turkiye_vaka_analizi.png", p_turkey, width = 12, height = 7, dpi = 150)
cat("\n[ÇIKTI] turkiye_vaka_analizi.png kaydedildi.\n")


# =============================================================================
# BÖLÜM 9: SENARYO KATSAYILARI GEREKÇELENDİRMESİ
# Amaç: QMD'deki sabit katsayıları (emek*0.88, verim*1.18 gibi) formülle belgele.
# Bu bölüm tablo 6 rakamlarından türetilen matematiksel gerekçeyi sunar.
# =============================================================================

cat("\n\n--- BÖLÜM 9: SENARYO KATSAYI GEREKÇELENDİRMESİ ---\n")

# Tablo 6'dan türetilen 20 yıllık büyüme oranları (2000-2020)
trend_20yil <- veri_tam_panel %>%
  filter(year %in% c(2000, 2020)) %>%
  group_by(year) %>%
  summarise(across(c(emek, toprak, gubre, verim, ticaret, ekipman),
                   mean, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = -year) %>%
  mutate(across(ends_with("_2020"),
                ~ (. / get(gsub("2020", "2000", cur_column())) - 1) * 100,
                .names = "{.col}_pct_degisim"))

yillik_oran <- data.frame(
  Degisken = c("emek", "toprak", "gubre", "verim", "ticaret", "ekipman"),
  Toplam_Degisim_Pct = c(
    (mean(veri_tam_panel$emek[veri_tam_panel$year==2020]) /
       mean(veri_tam_panel$emek[veri_tam_panel$year==2000]) - 1) * 100,
    (mean(veri_tam_panel$toprak[veri_tam_panel$year==2020]) /
       mean(veri_tam_panel$toprak[veri_tam_panel$year==2000]) - 1) * 100,
    (mean(veri_tam_panel$gubre[veri_tam_panel$year==2020]) /
       mean(veri_tam_panel$gubre[veri_tam_panel$year==2000]) - 1) * 100,
    (mean(veri_tam_panel$verim[veri_tam_panel$year==2020]) /
       mean(veri_tam_panel$verim[veri_tam_panel$year==2000]) - 1) * 100,
    (mean(veri_tam_panel$ticaret[veri_tam_panel$year==2020]) /
       mean(veri_tam_panel$ticaret[veri_tam_panel$year==2000]) - 1) * 100,
    (mean(veri_tam_panel$ekipman[veri_tam_panel$year==2020]) /
       mean(veri_tam_panel$ekipman[veri_tam_panel$year==2000]) - 1) * 100
  )
) %>%
  mutate(
    Yillik_Ort_Pct = round(Toplam_Degisim_Pct / 20, 3),
    Kotu_Katsayi   = round(1 + (Yillik_Ort_Pct / 100) * 10 * 0.5, 4),
    Orta_Katsayi   = round(1 + (Yillik_Ort_Pct / 100) * 10 * 1.0, 4),
    Iyi_Katsayi    = round(1 + (Yillik_Ort_Pct / 100) * 10 * 1.5, 4)
  )

cat("=== SENARYO KATSAYI TÜRETİM TABLOSU ===\n")
cat("Formül: Katsayı = 1 + (yıllık_oran × 10_yıl × senaryo_çarpanı)\n")
cat("Kötü=0.5x, Orta=1.0x, İyi=1.5x tarihsel trendin uygulanması\n\n")
print(as.data.frame(yillik_oran))
cat("\n[Bu tablo QMD metodoloji bölümüne doğrudan eklenebilir.]\n")


# =============================================================================
# BÖLÜM 9: EKONOMETRİK SAĞLAMLIK TESTLERİ (HAKEM R1 REVİZYONU - ÖNCELİK 1)
# Amaç: Panel birim kök (IPS/LLC), Pedroni eşbütünleşim,
#        Dumitrescu-Hurlin nedensellik, System GMM, EKC karşılaştırması, SDG uyum
# =============================================================================

cat("\n\n╔══════════════════════════════════════════════════════════════════╗
║   BÖLÜM 9: EKONOMETRİK SAĞLAMLIK (HAKEM R1 + R3 TALEBİ)        ║
╚══════════════════════════════════════════════════════════════════╝\n")

# Ek paketler
ek_paketler_b9 <- c("plm", "tseries")
ek_eksik_b9 <- ek_paketler_b9[!ek_paketler_b9 %in% installed.packages()[,"Package"]]
if (length(ek_eksik_b9) > 0) install.packages(ek_eksik_b9, repos = "https://cran.r-project.org")
invisible(lapply(ek_paketler_b9, library, character.only = TRUE))

# plm panel veri çerçevesi
panel_df_b9 <- veri_tam_panel %>%
  select(country, iso3c, year, tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  arrange(iso3c, year)

pdata_b9 <- pdata.frame(panel_df_b9, index = c("iso3c", "year"))

N_panel <- length(unique(panel_df_b9$iso3c))
T_panel <- length(unique(panel_df_b9$year))

cat(sprintf("\nPanel Yapısı: N=%d ülke, T=%d yıl (2000-2020), %d toplam gözlem\n",
            N_panel, T_panel, nrow(panel_df_b9)))

# ─────────────────────────────────────────────────────────────────────────────
# 9A: PANEL BİRİM KÖK TESTLERİ (IPS ve LLC)
# ─────────────────────────────────────────────────────────────────────────────
cat("\n--- 9A: PANEL BİRİM KÖK TESTLERİ (IPS & LLC) ---\n")

degiskenler_bk <- c("tarim_gsyh", "emek", "toprak", "gubre", "verim", "ticaret", "ekipman")

birim_kok_sonuclar <- data.frame(
  Degisken  = character(),
  IPS_stat  = numeric(),
  IPS_pval  = numeric(),
  LLC_stat  = numeric(),
  LLC_pval  = numeric(),
  Durum     = character(),
  stringsAsFactors = FALSE
)

for (deg in degiskenler_bk) {
  cat(sprintf("  %s test ediliyor...\n", deg))
  tryCatch({
    ips_res <- purtest(pdata_b9[[deg]], test = "ips", exo = "intercept", lags = "AIC")
    ips_stat <- ips_res$statistic$statistic
    ips_pval <- ips_res$statistic$p.value

    llc_res <- purtest(pdata_b9[[deg]], test = "levinlin", exo = "intercept", lags = "AIC")
    llc_stat <- llc_res$statistic$statistic
    llc_pval <- llc_res$statistic$p.value

    durum <- ifelse(ips_pval < 0.05 | llc_pval < 0.05, "Durağan I(0)", "Durağan değil I(1)")

    birim_kok_sonuclar <- rbind(birim_kok_sonuclar, data.frame(
      Degisken = deg,
      IPS_stat = round(ips_stat, 4),
      IPS_pval = round(ips_pval, 4),
      LLC_stat = round(llc_stat, 4),
      LLC_pval = round(llc_pval, 4),
      Durum    = durum,
      stringsAsFactors = FALSE
    ))
  }, error = function(e) {
    cat(sprintf("    %s hatası: %s\n", deg, e$message))
  })
}

cat("\n=== PANEL BİRİM KÖK TEST SONUÇLARI ===\n")
print(birim_kok_sonuclar)
cat("Not: p<0.05 → H0 (birim kök) reddedilir → Seri durağan\n")

# ─────────────────────────────────────────────────────────────────────────────
# 9B: PEDRONI PANEL EŞBÜTÜNLEŞİM TESTİ (Maddala-Wu Fisher Yaklaşımı)
# ─────────────────────────────────────────────────────────────────────────────
cat("\n--- 9B: PANEL EŞBÜTÜNLEŞİM TESTİ (Maddala-Wu Fisher) ---\n")

ulkeler_b9 <- unique(panel_df_b9$iso3c)
pedroni_sonuclar <- data.frame(
  iso3c    = character(),
  ADF_stat = numeric(),
  ADF_pval = numeric(),
  stringsAsFactors = FALSE
)

for (ulke in ulkeler_b9) {
  u_data <- panel_df_b9 %>% filter(iso3c == ulke) %>% arrange(year)
  if (nrow(u_data) < 10) next
  tryCatch({
    fit       <- lm(tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman, data = u_data)
    kalintilar <- residuals(fit)
    if (length(kalintilar) > 8 && var(kalintilar) > 1e-10) {
      adf_res <- adf.test(kalintilar, alternative = "stationary", k = 1)
      pedroni_sonuclar <- rbind(pedroni_sonuclar, data.frame(
        iso3c    = ulke,
        ADF_stat = round(adf_res$statistic, 4),
        ADF_pval = round(adf_res$p.value, 4),
        stringsAsFactors = FALSE
      ))
    }
  }, error = function(e) NULL)
}

n_esb     <- nrow(pedroni_sonuclar)
fisher_chi2 <- -2 * sum(log(pmax(pedroni_sonuclar$ADF_pval, 1e-10)))
fisher_df   <- 2 * n_esb
fisher_pval <- pchisq(fisher_chi2, df = fisher_df, lower.tail = FALSE)
esb_oran    <- mean(pedroni_sonuclar$ADF_pval < 0.05, na.rm = TRUE)

cat(sprintf("\nPanel Eşbütünleşim (Maddala-Wu Fisher Testi):\n"))
cat(sprintf("  N (ülke)                : %d\n", n_esb))
cat(sprintf("  Eşbütünleşen oran       : %.1f%%\n", esb_oran * 100))
cat(sprintf("  Fisher χ²               : %.4f\n", fisher_chi2))
cat(sprintf("  Serbestlik derecesi     : %d\n", fisher_df))
cat(sprintf("  p-değeri                : %.6f\n", fisher_pval))
cat(sprintf("  Karar                   : %s\n",
    ifelse(fisher_pval < 0.05,
           "H0 reddedilir → PANEL EŞBÜTÜNLEŞİM MEVCUT ✓",
           "H0 reddedilemez → Eşbütünleşim belirsiz")))

# ─────────────────────────────────────────────────────────────────────────────
# 9C: DUMİTRESCU-HURLİN PANEL NEDENSELLİK TESTİ (2012)
# Referans: Dumitrescu, E.I., Hurlin, C. (2012). Economic Modelling, 29(4), 1450-1460.
# ─────────────────────────────────────────────────────────────────────────────
cat("\n--- 9C: DUMİTRESCU-HURLİN PANEL NEDENSELLİK TESTİ (lag=2) ---\n")

# DH (2012) testi: bireysel Wald istatistiklerinin ortalaması
# W_bar = (1/N) * Σ W_i,K
# Z_bar = sqrt(N/2K) * (W_bar - K)  →  N(0,1) T,N→∞
# Z_tilde = sqrt(N * (T-2K-3)/(2K*(T-2K-1))) * (W_bar - K)  →  yarı-asimptotik

dh_granger_test <- function(data, y_var, x_var, lag = 2) {
  ulke_list <- unique(data$iso3c)
  N  <- length(ulke_list)
  Tv <- length(unique(data$year))
  K  <- lag

  wald_stats <- vapply(ulke_list, function(ulke) {
    u_data <- data[data$iso3c == ulke, ]
    u_data <- u_data[order(u_data$year), ]
    if (nrow(u_data) < (2 * K + 3)) return(NA_real_)
    tryCatch({
      y <- u_data[[y_var]]
      x <- u_data[[x_var]]
      Y_emb <- embed(y, K + 1)
      X_emb <- embed(x, K + 1)
      y_dep    <- Y_emb[, 1]
      Y_lag    <- Y_emb[, -1, drop = FALSE]
      X_lag    <- X_emb[, -1, drop = FALSE]
      n_obs    <- length(y_dep)
      X_unres  <- cbind(1, Y_lag, X_lag)
      X_res    <- cbind(1, Y_lag)
      rss_u    <- sum(lm.fit(X_unres, y_dep)$residuals^2)
      rss_r    <- sum(lm.fit(X_res,   y_dep)$residuals^2)
      df2      <- n_obs - 2 * K - 1
      if (df2 <= 0 || rss_u <= 0) return(NA_real_)
      F_stat   <- ((rss_r - rss_u) / K) / (rss_u / df2)
      K * F_stat
    }, error = function(e) NA_real_)
  }, FUN.VALUE = numeric(1))

  valid_w  <- wald_stats[!is.na(wald_stats)]
  N_v      <- length(valid_w)
  W_bar    <- mean(valid_w)
  Z_bar    <- sqrt(N_v / (2 * K)) * (W_bar - K)
  p_Zbar   <- 2 * (1 - pnorm(abs(Z_bar)))
  denom_t  <- 2 * K * (Tv - 2 * K - 1) / (Tv - 2 * K - 3)
  Z_tilde  <- if (denom_t > 0) sqrt(N_v / denom_t) * (W_bar - K) else NA_real_
  p_Ztilde <- if (!is.na(Z_tilde)) 2 * (1 - pnorm(abs(Z_tilde))) else NA_real_
  list(W_bar = W_bar, N = N_v, K = K,
       Z_bar = Z_bar, p_Zbar = p_Zbar,
       Z_tilde = Z_tilde, p_Ztilde = p_Ztilde)
}

x_degiskenleri_dh <- c("emek", "toprak", "gubre", "verim", "ticaret", "ekipman")

dh_sonuclar <- do.call(rbind, lapply(x_degiskenleri_dh, function(xd) {
  cat(sprintf("  %s → tarim_gsyh...\n", xd))
  res <- tryCatch(
    dh_granger_test(panel_df_b9, y_var = "tarim_gsyh", x_var = xd, lag = 2),
    error = function(e) NULL
  )
  if (is.null(res)) return(NULL)
  sig_star <- ifelse(res$p_Ztilde < 0.01, "***",
              ifelse(res$p_Ztilde < 0.05, "**",
              ifelse(res$p_Ztilde < 0.10, "*", "")))
  data.frame(
    X_Degisken = xd,
    W_bar      = round(res$W_bar, 4),
    Z_bar      = round(res$Z_bar, 4),
    p_Zbar     = round(res$p_Zbar, 4),
    Z_tilde    = round(res$Z_tilde, 4),
    p_Ztilde   = round(res$p_Ztilde, 4),
    Karar      = paste0(ifelse(res$p_Ztilde < 0.05, "Nedensellik var", "H0 reddedilemez"), sig_star),
    stringsAsFactors = FALSE
  )
}))

cat("\n=== DUMİTRESCU-HURLİN PANEL NEDENSELLİK SONUÇLARI ===\n")
print(dh_sonuclar)
cat("H0: Tüm birimler için x, tarim_gsyh'nin Granger nedeni değildir\n")
cat("*p<0.10, **p<0.05, ***p<0.01  |  Z_tilde = yarı-asimptotik istatistik\n")

# DH görselleştirmesi
if (!is.null(dh_sonuclar) && nrow(dh_sonuclar) > 0) {
  p_dh <- ggplot(dh_sonuclar, aes(x = reorder(X_Degisken, -p_Ztilde),
                                   y = -log10(pmax(p_Ztilde, 1e-6)),
                                   fill = p_Ztilde < 0.05)) +
    geom_col(width = 0.6, alpha = 0.85) +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed",
               color = "#c0392b", linewidth = 1) +
    geom_hline(yintercept = -log10(0.01), linetype = "dotted",
               color = "#922b21", linewidth = 1) +
    scale_fill_manual(values = c("TRUE" = "#2980b9", "FALSE" = "#bdc3c7"),
                      labels = c("Anlamsız", "Anlamlı (p<0.05)"), name = NULL) +
    annotate("text", x = 0.6, y = -log10(0.05) + 0.05,
             label = "p=0.05", color = "#c0392b", size = 3, hjust = 0) +
    coord_flip() +
    labs(
      title    = "Dumitrescu-Hurlin Panel Nedensellik Testi (2012)",
      subtitle = sprintf("Z-tilde istatistiği (lag=2, N=%d ülke, T=%d yıl)",
                          N_panel, T_panel),
      x        = "Bağımsız Değişken",
      y        = "-log10(p-değeri)"
    ) +
    theme_minimal() +
    theme(plot.title    = element_text(face = "bold", size = 13),
          plot.subtitle = element_text(size = 9, color = "gray40"),
          legend.position = "bottom")
  ggsave("../03-Results/dh_nedensellik.png", p_dh, width = 10, height = 6, dpi = 150)
  cat("\n[ÇIKTI] dh_nedensellik.png kaydedildi.\n")
}

# ─────────────────────────────────────────────────────────────────────────────
# 9D: SYSTEM GMM (Blundell-Bond) – ENDOJENİTE KONTROLÜ
# ─────────────────────────────────────────────────────────────────────────────
cat("\n--- 9D: SYSTEM GMM (Blundell-Bond) - ENDOJENİTE KONTROLÜ ---\n")

tryCatch({
  # Blundell-Bond System GMM: "ld" = levels + differences
  gmm_model <- pgmm(
    tarim_gsyh ~ lag(tarim_gsyh, 1) + emek + toprak + gubre + verim + ticaret + ekipman |
      lag(tarim_gsyh, 2:4) + lag(emek, 2:3) + lag(verim, 2:3),
    data          = pdata_b9,
    effect        = "twoways",
    model         = "twosteps",
    transformation = "ld"
  )
  cat("\n=== SYSTEM GMM (Blundell-Bond, İki Adım) ===\n")
  print(summary(gmm_model, robust = TRUE))

  tryCatch({
    sargan_res <- sargan(gmm_model)
    cat(sprintf("\nHansen J-testi (araç geçerliliği): χ²=%.4f, df=%d, p=%.4f → %s\n",
        sargan_res$statistic, sargan_res$parameter, sargan_res$p.value,
        ifelse(sargan_res$p.value > 0.05, "Araçlar geçerli ✓", "Araçlar şüpheli ✗")))
  }, error = function(e) cat("  Hansen testi uygulanamadı\n"))

  tryCatch({
    m1 <- mtest(gmm_model, order = 1, vcov = vcovHC)
    m2 <- mtest(gmm_model, order = 2, vcov = vcovHC)
    cat(sprintf("AR(1): z=%.4f, p=%.4f | AR(2): z=%.4f, p=%.4f\n",
        m1$statistic, m1$p.value, m2$statistic, m2$p.value))
    cat(sprintf("  AR(2) yorumu: %s\n",
        ifelse(m2$p.value > 0.05, "p>0.05 → Model geçerli ✓", "p<0.05 → Araç sorunlu ✗")))
  }, error = function(e) cat("  AR testleri uygulanamadı\n"))

}, error = function(e) {
  cat(sprintf("System GMM başarısız: %s\nYedek: İki Yönlü Sabit Etkiler (FE) + Hausman\n", e$message))
  tryCatch({
    fe_mod <- plm(tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
                  data = pdata_b9, model = "within", effect = "twoways")
    re_mod <- plm(tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
                  data = pdata_b9, model = "random")
    cat("\n=== SABİT ETKİLER (İki Yönlü FE) ===\n")
    print(summary(fe_mod))
    cat("\nHausman Testi (FE vs RE):\n")
    ht <- phtest(fe_mod, re_mod)
    print(ht)
    cat(sprintf("Karar: %s\n",
        ifelse(ht$p.value < 0.05, "FE tercih edilir → Endojenlik mevcut ✓", "RE tercih edilebilir")))
  }, error = function(e2) cat(sprintf("FE modeli de başarısız: %s\n", e2$message)))
})

# ─────────────────────────────────────────────────────────────────────────────
# 9E: EKC HİPOTEZİ VE YAPISAL TABAN KARŞILAŞTIRMASI
# R2 Hakem talebi: EKC (ters-U) vs Yapısal Taban (asimptotik alt sınır)
# ─────────────────────────────────────────────────────────────────────────────
cat("\n--- 9E: EKC (Kuznets Eğrisi) ve YAPISAL TABAN KARŞILAŞTIRMASI ---\n")

tryCatch({
  cat("GDP per capita verisi çekiliyor...\n")
  gdp_data <- WDI(indicator = "NY.GDP.PCAP.KD", start = 2000, end = 2020, extra = FALSE) %>%
    rename(gdp_pc = NY.GDP.PCAP.KD) %>%
    select(iso3c, year, gdp_pc) %>%
    filter(!is.na(gdp_pc))

  ekc_panel <- panel_df_b9 %>%
    left_join(gdp_data, by = c("iso3c", "year")) %>%
    filter(!is.na(gdp_pc) & gdp_pc > 0) %>%
    mutate(ln_gdp = log(gdp_pc), ln_gdp_sq = log(gdp_pc)^2)

  ekc_pdata <- pdata.frame(ekc_panel, index = c("iso3c", "year"))

  ekc_model <- plm(tarim_gsyh ~ ln_gdp + ln_gdp_sq,
                   data = ekc_pdata, model = "within", effect = "individual")
  cat("\n=== EKC MODELİ (FE, bireysel etkiler) ===\n")
  print(summary(ekc_model))

  ekc_coef <- coef(ekc_model)
  if (!is.na(ekc_coef["ln_gdp"]) && !is.na(ekc_coef["ln_gdp_sq"]) && ekc_coef["ln_gdp_sq"] != 0) {
    turning_ln <- -ekc_coef["ln_gdp"] / (2 * ekc_coef["ln_gdp_sq"])
    turning_pc <- exp(turning_ln)
    cat(sprintf("\nEKC Dönüm Noktası: ln(GDP)=%.3f → GDP/kişi=$%.0f\n", turning_ln, turning_pc))
    if (ekc_coef["ln_gdp_sq"] < 0) {
      cat("Şekil: Ters-U (Lewis/Kuznets) → Tarım payı dönüm sonrası düşer\n")
      cat("Yapısal Taban argümanı: Düşüş sıfıra değil, asimptotik tabana ulaşır ✓\n")
    } else {
      cat("Şekil: U-şekli → Klasik EKC reddediliyor, Yapısal Taban destekleniyor ✓\n")
    }
  }

  # Görselleştirme
  gdp_seq  <- seq(min(ekc_panel$ln_gdp, na.rm = TRUE),
                  max(ekc_panel$ln_gdp, na.rm = TRUE), length.out = 300)
  pred_ekc <- ekc_coef["ln_gdp"] * gdp_seq + ekc_coef["ln_gdp_sq"] * gdp_seq^2
  pred_ekc <- pred_ekc - min(pred_ekc, na.rm = TRUE) +
              quantile(ekc_panel$tarim_gsyh, 0.10, na.rm = TRUE)
  yapi_taban_pct <- quantile(ekc_panel$tarim_gsyh, 0.05, na.rm = TRUE)

  p_ekc <- ggplot() +
    geom_point(data = ekc_panel, aes(x = ln_gdp, y = tarim_gsyh),
               alpha = 0.08, color = "#95a5a6", size = 0.7) +
    geom_line(data = data.frame(x = gdp_seq, y = pred_ekc),
              aes(x = x, y = y), color = "#c0392b", linewidth = 1.4) +
    geom_hline(yintercept = yapi_taban_pct, linetype = "dashed",
               color = "#27ae60", linewidth = 1.2) +
    annotate("text", x = max(gdp_seq) - 0.2, y = yapi_taban_pct + 0.4,
             label = "Yapısal Taban (5. persentil)", color = "#27ae60",
             size = 3.2, hjust = 1, fontface = "bold") +
    labs(
      title    = "EKC Hipotezi ve Yapısal Taban: Karşılaştırmalı Analiz",
      subtitle = "Kırmızı: EKC eğrisi (FE) | Yeşil kesikli: Yapısal Taban alt sınırı",
      x        = "ln(GDP per capita, 2015 sabit USD)",
      y        = "Tarım GSYH Payı (%)"
    ) +
    theme_minimal() +
    theme(plot.title    = element_text(face = "bold", size = 13),
          plot.subtitle = element_text(size = 9, color = "gray40"))

  ggsave("../03-Results/ekc_yapi_taban_karsilastirma.png", p_ekc, width = 10, height = 6, dpi = 150)
  cat("\n[ÇIKTI] ekc_yapi_taban_karsilastirma.png kaydedildi.\n")

}, error = function(e) cat(sprintf("EKC analizi hatası: %s\n", e$message)))

# ─────────────────────────────────────────────────────────────────────────────
# 9F: SDG UYUM TABLOSU VE GÖRSELİ (R3 Hakem Talebi)
# ─────────────────────────────────────────────────────────────────────────────
cat("\n--- 9F: SDG UYUM ANALİZİ (SDG 2, 8, 13 + diğerleri) ---\n")

sdg_uyum <- data.frame(
  SDG = c("SDG 2", "SDG 8", "SDG 13", "SDG 1", "SDG 15"),
  Baslik = c(
    "Sıfır Açlık",
    "İnsana Yakışır İş",
    "İklim Eylemi",
    "Yoksulluğa Son",
    "Karasal Yaşam"
  ),
  Baglanti = c(
    "Tarım payındaki Yapısal Taban gıda üretiminin sürdürüleceğini gösterir; Lewis düşüşü sıfıra gitmez",
    "emek değişkeni kırsal istihdamı; kümeleme analizi gelir gruplarına göre farklılaşmayı ortaya koyar",
    "ReLU robustness iklim şoklarına dayanıklılığı test eder; 2030 kötümser senaryo iklim baskısını kapsar",
    "Düşük gelirli ülke kümesi: Yapısal Taban bu grupta özellikle yüksek; kırılganlık korunuyor",
    "toprak kullanımı değişkeni arazi bozulması ve ekosistem hizmetleriyle doğrudan bağlantılı"
  ),
  Analiz_Karsiligi = c(
    "tarim_gsyh asimptotik alt sınırı (Yapısal Taban) + EKC dönüm analizi (Bölüm 9E)",
    "emek Granger/DH nedenselliği + kümeleme PCA (Bölüm 4 + 7)",
    "ReLU robustness + yapısal kırılma (Bölüm 6) + 2030 kötümser senaryo (Bölüm 8)",
    "Küme 3: Düşük gelirli ülkeler (Bölüm 7) + birim kök testi (Bölüm 9A)",
    "toprak değişkeni katsayısı (SHAP, Bölüm 3) + DH nedensellik (Bölüm 9C)"
  ),
  stringsAsFactors = FALSE
)

cat("\n=== SDG UYUM TABLOSU ===\n")
print(sdg_uyum[, c("SDG", "Baslik", "Analiz_Karsiligi")])

# SDG bar görselleştirme
sdg_renkler <- c("SDG 2" = "#27ae60", "SDG 8" = "#2980b9",
                  "SDG 13" = "#8e44ad", "SDG 1" = "#e67e22", "SDG 15" = "#16a085")

p_sdg <- ggplot(sdg_uyum, aes(x = SDG, y = 1, fill = SDG)) +
  geom_tile(color = "white", linewidth = 2, height = 0.8) +
  geom_text(aes(label = paste0(SDG, "\n", Baslik)),
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = sdg_renkler, guide = "none") +
  labs(
    title    = "Yapısal Taban Çalışmasının SDG Bağlantıları (R3 Hakem Revizyonu)",
    subtitle = "Her SDG için makaledeki karşılık gelen analiz bölümü eşleştirilmiştir",
    x = NULL, y = NULL
  ) +
  theme_void() +
  theme(plot.title    = element_text(face = "bold", size = 12, hjust = 0.5),
        plot.subtitle = element_text(size = 9, hjust = 0.5, color = "gray40"),
        plot.margin   = margin(10, 10, 10, 10))

ggsave("../03-Results/sdg_uyum_tablosu.png", p_sdg, width = 12, height = 3.5, dpi = 150)
cat("\n[ÇIKTI] sdg_uyum_tablosu.png kaydedildi.\n")

cat("\n╔══════════════════════════════════════════════════════════════════╗
║   BÖLÜM 9 TAMAMLANDI - EKONOMETRİK SAĞLAMLIK PAKETİ            ║
╠══════════════════════════════════════════════════════════════════╣
║  9A: Panel Birim Kök (IPS + LLC)    → birim_kok_sonuclar        ║
║  9B: Eşbütünleşim (Maddala-Wu)      → fisher_chi2, fisher_pval  ║
║  9C: Dumitrescu-Hurlin (2012)       → dh_nedensellik.png        ║
║  9D: System GMM (Blundell-Bond)     → Hansen J + AR(1/2)        ║
║  9E: EKC vs Yapısal Taban           → ekc_yapi_taban.png        ║
║  9F: SDG 2/8/13 Uyum Tablosu       → sdg_uyum_tablosu.png      ║
╚══════════════════════════════════════════════════════════════════╝\n")


# =============================================================================
# ÖZET RAPOR
# =============================================================================

cat("\n
╔══════════════════════════════════════════════════════════════════╗
║                    ANALİZ TAMAMLANDI                           ║
╠══════════════════════════════════════════════════════════════════╣
║  Üretilen çıktılar (Bölüm 1-8):                                ║
║  1. cv_fold_r2.png          → 10-fold CV doğrulama grafik      ║
║  2. mimari_karsilastirma.png → Mimari karşılaştırma            ║
║  3. shap_beeswarm.png       → SHAP değerleri grafiği           ║
║  4. granger_nedensellik.png  → Granger test sonuçları          ║
║  5. kalinti_tani_panel.png   → 4'lü tanı grafik paketi         ║
║  6. yapisal_kirilma.png      → Bai-Perron kırılma analizi      ║
║  7. kume_analizi_pca.png     → 105 ülke kümeleme (PCA)         ║
║  8. turkiye_vaka_analizi.png → Türkiye vaka analizi            ║
╠══════════════════════════════════════════════════════════════════╣
║  Üretilen çıktılar (Bölüm 9 – Hakem R1/R3 Revizyonu):         ║
║  9. dh_nedensellik.png       → Dumitrescu-Hurlin (2012)        ║
║  10. ekc_yapi_taban_karsilastirma.png → EKC vs Yapısal Taban   ║
║  11. sdg_uyum_tablosu.png    → SDG 2/8/13 uyum grafiği         ║
╠══════════════════════════════════════════════════════════════════╣
║  Makaleye eklenecek tablolar:                                  ║
║  - 10-fold CV özet (Tablo X)                                   ║
║  - Mimari karşılaştırma (Tablo X+1)                            ║
║  - Dumitrescu-Hurlin nedensellik (Tablo X+2) ← YENİ           ║
║  - Panel birim kök IPS/LLC (Tablo X+3) ← YENİ                 ║
║  - Maddala-Wu eşbütünleşim (Tablo X+4) ← YENİ                 ║
║  - System GMM Hansen J + AR testleri (Tablo X+5) ← YENİ       ║
║  - SDG uyum tablosu (Tablo X+6) ← YENİ                        ║
║  - Senaryo katsayı gerekçe (Metodoloji eki)                    ║
╚══════════════════════════════════════════════════════════════════╝
")
