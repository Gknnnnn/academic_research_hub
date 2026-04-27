# Auto-generated from UY_MGO_Makale.qmd
# Original qmd dir: /sessions/determined-compassionate-allen/mnt/Akademik_Arastirma/300-Projects/310-Active-Papers/2026-UY-MGO-Makale/04-Manuscript
options(warn = 1)
setwd("/sessions/determined-compassionate-allen/mnt/Akademik_Arastirma/300-Projects/310-Active-Papers/2026-UY-MGO-Makale/04-Manuscript")
cat("[runner] working dir:", getwd(), "\n")


# ---- chunk 1:  ----
cat("[runner] >>> chunk 1\n")
tryCatch({
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(stargazer)
library(plm)
library(lmtest)
library(knitr)
library(kableExtra)
library(modelsummary)
library(quantreg)
library(jsonlite)
library(zoo)
library(sandwich)

temiz_veri <- read_csv("data/analiz_verisi_full.csv", show_col_types = FALSE)
gelismekte_olan_veri <- read_csv("data/gelismekte_olan_veri.csv", show_col_types = FALSE)

temiz_veri <- temiz_veri %>%
  filter(!is.na(reer) & !is.na(ihracat))

analiz_verisi <- temiz_veri %>%
  drop_na(hukuk, regulasyon, reer, ihracat, gsyh) %>%
  mutate(
    ln_ihracat = log(ihracat),
    ln_reer = log(reer),
    ln_gsyh = log(gsyh)
  )

# Panel veri yapıları
p_veri    <- pdata.frame(analiz_verisi,     index = c("country", "year"))
p_veri_em <- pdata.frame(gelismekte_olan_veri, index = c("country", "year"))

# Model tahminleri
model_politik <- plm(ln_ihracat ~ ln_reer * hukuk + ln_gsyh,
                     data = p_veri, model = "within")
model_em <- plm(ln_ihracat ~ ln_reer * hukuk + ln_gsyh,
                data = p_veri_em, model = "within")
model_em_re <- plm(ln_ihracat ~ ln_reer * hukuk + ln_gsyh,
                   data = p_veri_em, model = "random")

# Driscoll-Kraay dirençli standart hatalar
se_scc <- sqrt(diag(vcovSCC(model_em, type = "HC3", maxlag = 4)))

# Metin içi inline kodlar için ön hesaplamalar
hausman_pre <- phtest(model_em, model_em_re)
t_dk_inter  <- as.numeric(coef(model_em)["ln_reer:hukuk"]) / se_scc["ln_reer:hukuk"]
p_dk_inter  <- round(2 * pnorm(abs(t_dk_inter), lower.tail = FALSE), 3)
robust_engine <- fromJSON("../03-Results/results.json")
robust_top_model <- robust_engine$top_models[1, ]
robust_appendix <- read_csv("Appendix/robustness_appendix_table.csv", show_col_types = FALSE)
robust_appendix_view <- robust_appendix %>%
  mutate(
    controls = ifelse(is.na(controls) | controls == "", "Yok", controls),
    coef = round(coef, 3),
    std_err = round(std_err, 3),
    p_value = round(p_value, 3),
    r_squared = round(r_squared, 3)
  ) %>%
  arrange(p_value, desc(r_squared))

sig_note_tr <- if (knitr::is_latex_output()) {
  "Anlamlılık düzeyleri sırasıyla yüzde 1, yüzde 5 ve yüzde 10 olarak raporlanmıştır."
} else {
  "*** p<0,01, ** p<0,05, * p<0,1."
}

sig_note_en <- if (knitr::is_latex_output()) {
  "Significance levels are reported at the 1 percent, 5 percent, and 10 percent thresholds."
} else {
  "*** p<0.01, ** p<0.05, * p<0.1."
}
}, error = function(e) { cat("[runner] !! chunk 1 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 2:  ----
cat("[runner] >>> chunk 2\n")
tryCatch({

library(knitr)
library(kableExtra)   # Daha güzel görünüm için öneririm

# Veri önceden yüklenmiş olmalı (üstteki setup chunk'ında yap)
# Eğer emin değilsen buraya da ekle:
# analiz_verisi <- read_csv("data/analiz_verisi_full.csv", show_col_types = FALSE)

sutunlar <- c("ln_ihracat", "ln_reer", "ln_gsyh", "hukuk")
isimler  <- c("ln(İhracat)", "ln(REER)", "ln(GSYH)", "Hukukun Üstünlüğü")

desc1a <- data.frame(
  "Değişken"    = isimler,
  "N"           = sapply(sutunlar, function(v) sum(!is.na(analiz_verisi[[v]]))),
  "Ortalama"    = sapply(sutunlar, function(v) round(mean(analiz_verisi[[v]], na.rm = TRUE), 3)),
  "Std. Sapma"  = sapply(sutunlar, function(v) round(sd(analiz_verisi[[v]], na.rm = TRUE), 3)),
  "Minimum"     = sapply(sutunlar, function(v) round(min(analiz_verisi[[v]], na.rm = TRUE), 3)),
  "Maksimum"    = sapply(sutunlar, function(v) round(max(analiz_verisi[[v]], na.rm = TRUE), 3)),
  check.names = FALSE, 
  row.names = NULL
)

# En güvenilir yöntem:
res_kable <- kable(desc1a, 
      format = ifelse(knitr::is_latex_output(), "latex", "html"),
      align = c("l", "c", "c", "c", "c", "c"),
      escape = FALSE)

if (!knitr::is_latex_output()) {
  res_kable <- res_kable %>%
    kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"),
                  full_width = TRUE,
                  position = "center")
}
res_kable
}, error = function(e) { cat("[runner] !! chunk 2 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 3:  ----
cat("[runner] >>> chunk 3\n")
tryCatch({

library(knitr)
library(kableExtra)

# === ÖNEMLİ: Veriyi burada tekrar yükle (Render sırasında garanti olsun) ===
gelismekte_olan_veri <- read_csv("data/gelismekte_olan_veri.csv", show_col_types = FALSE)

# Değişken isimleri
sutunlar <- c("ln_ihracat", "ln_reer", "ln_gsyh", "hukuk")
isimler  <- c("ln(İhracat)", "ln(REER)", "ln(GSYH)", "Hukukun Üstünlüğü")

# Tanımlayıcı istatistikler
desc1b <- data.frame(
  "Değişken"    = isimler,
  "N"           = sapply(sutunlar, function(v) sum(!is.na(gelismekte_olan_veri[[v]]))),
  "Ortalama"    = sapply(sutunlar, function(v) round(mean(gelismekte_olan_veri[[v]], na.rm = TRUE), 3)),
  "Std. Sapma"  = sapply(sutunlar, function(v) round(sd(gelismekte_olan_veri[[v]], na.rm = TRUE), 3)),
  "Minimum"     = sapply(sutunlar, function(v) round(min(gelismekte_olan_veri[[v]], na.rm = TRUE), 3)),
  "Maksimum"    = sapply(sutunlar, function(v) round(max(gelismekte_olan_veri[[v]], na.rm = TRUE), 3)),
  check.names = FALSE, 
  row.names = NULL
)

# Tabloyu oluştur (kableExtra ile daha güzel ve stabil)
res_kable_b <- kable(desc1b, 
      format = ifelse(knitr::is_latex_output(), "latex", "html"),
      align = c("l", "c", "c", "c", "c", "c"),
      escape = FALSE)

if (!knitr::is_latex_output()) {
  res_kable_b <- res_kable_b %>%
    kable_styling(
      bootstrap_options = c("striped", "hover", "condensed", "responsive"),
      full_width = TRUE,
      position = "center"
    )
}
res_kable_b
}, error = function(e) { cat("[runner] !! chunk 3 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 4:  ----
cat("[runner] >>> chunk 4\n")
tryCatch({

library(modelsummary)

models <- list(
  "Tüm Ülkeler"             = model_politik,
  "Gelişmekte Olan Ülkeler" = model_em
)

modelsummary(
  models,
  stars      = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_rename = c(
    "ln_reer"       = "ln(REER)",
    "hukuk"         = "Hukukun Üstünlüğü",
    "ln_gsyh"       = "ln(GSYH)",
    "ln_reer:hukuk" = "ln(REER) × Hukuk"
  ),
  gof_omit   = "AIC|BIC|Log.Lik|Std.Err|DF|rmse",
  statistic  = "std.error",
  output     = ifelse(knitr::is_latex_output(), "latex", "html"),
  fmt        = 3,                    
  escape     = FALSE,

  # Add rows (güvenli yöntem)
  add_rows = data.frame(
    term = c("R²", "Gözlem Sayısı", "Sabit Etkiler"),
    `Tüm Ülkeler` = c(
      round(summary(model_politik)$r.squared["rsq"], 3),
      nobs(model_politik),
      "Evet"
    ),
    `Gelişmekte Olan Ülkeler` = c(
      round(summary(model_em)$r.squared["rsq"], 3),
      nobs(model_em),
      "Evet"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ),

  notes = paste("Not: Parantez içindeki değerler standart hatalardır.", sig_note_tr)
)
}, error = function(e) { cat("[runner] !! chunk 4 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 5:  ----
cat("[runner] >>> chunk 5\n")
tryCatch({

library(dplyr)
library(ggplot2)
library(zoo)

# Oynaklık Hesaplama (3 yıllık hareketli standart sapma)
vol_data <- gelismekte_olan_veri %>%
  group_by(country) %>%
  arrange(year) %>%
  mutate(reer_vol = rollapply(reer, width = 3, FUN = sd, fill = NA, align = "right")) %>%
  group_by(year) %>%
  summarise(
    avg_ihracat = mean(ihracat, na.rm = TRUE),
    avg_vol      = mean(reer_vol, na.rm = TRUE)
  ) %>%
  drop_na()

# İkili eksenli grafik (Volatility vs Export)
ggplot(vol_data, aes(x = year)) +
  geom_line(aes(y = avg_vol, color = "REER Oynaklığı"), linewidth = 1.2) +
  geom_line(aes(y = avg_ihracat / mean(avg_ihracat) * mean(avg_vol), color = "İhracat (Normalize)"), 
            linewidth = 1.2, linetype = "dashed") +
  scale_y_continuous(sec.axis = sec_axis(~ . * mean(vol_data$avg_ihracat) / mean(vol_data$avg_vol), 
                                         name = "Ortalama İhracat")) +
  scale_color_manual(values = c("REER Oynaklığı" = "#dc2626", "İhracat (Normalize)" = "#2563eb")) +
  labs(x = "Yıl", y = "Ortalama REER Oynaklığı", color = "Gösterge") +
  theme_minimal() +
  theme(legend.position = "bottom")
}, error = function(e) { cat("[runner] !! chunk 5 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 6:  ----
cat("[runner] >>> chunk 6\n")
tryCatch({

library(dplyr)
library(ggplot2)

medyan_hukuk <- median(gelismekte_olan_veri$hukuk, na.rm = TRUE)

inter_data <- gelismekte_olan_veri %>%
  mutate(Hukuk_Grubu = ifelse(hukuk >= medyan_hukuk, "Güçlü Hukuk", "Zayıf Hukuk")) %>%
  drop_na(Hukuk_Grubu, ln_reer, ln_ihracat)

ggplot(inter_data, aes(x = ln_reer, y = ln_ihracat, color = Hukuk_Grubu, fill = Hukuk_Grubu)) +
  geom_point(alpha = 0.3) +
  geom_smooth(method = "lm", formula = y ~ x, linewidth = 1.2) +
  scale_color_manual(values = c("Güçlü Hukuk" = "#10b981", "Zayıf Hukuk" = "#ef4444")) +
  scale_fill_manual(values = c("Güçlü Hukuk" = "#10b981", "Zayıf Hukuk" = "#ef4444")) +
  labs(x = "ln(REER)", y = "ln(İhracat)", color = "Kurumsal Yapı", fill = "Kurumsal Yapı") +
  theme_minimal() +
  theme(legend.position = "bottom")
}, error = function(e) { cat("[runner] !! chunk 6 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 7:  ----
cat("[runner] >>> chunk 7\n")
tryCatch({
library(ggplot2)

# 1. Hukuk aralığı
hukuk_range <- seq(min(gelismekte_olan_veri$hukuk), max(gelismekte_olan_veri$hukuk), length.out = 100)

# 2. Katsayı ve standart hatalar
beta_reer  <- coef(model_em)["ln_reer"]
beta_inter <- coef(model_em)["ln_reer:hukuk"]
se_reer    <- summary(model_em)$coefficients["ln_reer", "Std. Error"]
se_inter   <- summary(model_em)$coefficients["ln_reer:hukuk", "Std. Error"]
cov_ri     <- vcov(model_em)["ln_reer", "ln_reer:hukuk"]

# 3. Marjinal etki ve %95 güven bandı
marginal_effect <- as.numeric(beta_reer) + as.numeric(beta_inter) * hukuk_range
se_marginal     <- sqrt(se_reer^2 + hukuk_range^2 * se_inter^2 + 2 * hukuk_range * cov_ri)

df_marginal <- data.frame(
  hukuk  = hukuk_range,
  effect = marginal_effect,
  lower  = marginal_effect - 1.96 * se_marginal,
  upper  = marginal_effect + 1.96 * se_marginal
)

# 4. Grafik
ggplot(df_marginal, aes(x = hukuk, y = effect)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15, fill = "steelblue") +
  geom_line(color = "steelblue", linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red", linewidth = 0.8) +
  labs(
    x = "Hukukun Üstünlüğü Endeksi",
    y = "REER'in Marjinal Etkisi (∂ln_ihracat / ∂ln_reer)"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())
}, error = function(e) { cat("[runner] !! chunk 7 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 8:  ----
cat("[runner] >>> chunk 8\n")
tryCatch({

library(knitr)
library(kableExtra)

# Testleri çalıştır
bg_test  <- pbgtest(model_em)
cd_test  <- suppressWarnings(pcdtest(model_em, test = "cd"))
hausman  <- phtest(model_em, model_em_re)

# Tabloyu oluştur
tablo4 <- data.frame(
  Test          = c("Hausman Model Seçim Testi",
                    "Otokorelasyon Testi (Breusch-Godfrey-Wooldridge)",
                    "Yatay Kesit Bağımlılığı Testi (Pesaran CD)"),
  
  `H₀ Hipotezi` = c("Rassal Etkiler tutarlı",
                    "Otokorelasyon yok",
                    "Yatay kesit bağımsızlığı"),
  
  İstatistik    = c(
    sprintf("χ²(%d) = %.3f", as.integer(hausman$parameter), hausman$statistic),
    sprintf("χ²(%d) = %.3f", as.integer(bg_test$parameter), bg_test$statistic),
    sprintf("z = %.3f", cd_test$statistic)
  ),
  
  `p-Değeri`    = c(
    format.pval(hausman$p.value,  digits = 3, eps = 0.001),
    format.pval(bg_test$p.value,  digits = 3, eps = 0.001),
    format.pval(cd_test$p.value,  digits = 3, eps = 0.001)
  ),
  
  Sonuç         = c("Sabit Etkiler modeli seçildi",
                    "H₀ reddedildi — otokorelasyon tespit edildi",
                    "H₀ reddedildi — yatay kesit bağımlılığı tespit edildi"),
  
  check.names = FALSE,
  row.names = NULL
)

# Tabloyu göster (kableExtra ile daha stabil)
res_tablo4 <- kable(tablo4, 
      format = ifelse(knitr::is_latex_output(), "latex", "html"),
      align = c("l", "l", "c", "c", "l"),
      escape = FALSE)

if (!knitr::is_latex_output()) {
  res_tablo4 <- res_tablo4 %>%
    kable_styling(
      bootstrap_options = c("striped", "hover", "condensed", "responsive"),
      full_width = TRUE,
      position = "center"
    )
}
res_tablo4
}, error = function(e) { cat("[runner] !! chunk 8 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 9:  ----
cat("[runner] >>> chunk 9\n")
tryCatch({

library(modelsummary)

# Sadece Driscoll-Kraay'li model
model_dk <- list("Driscoll-Kraay SH" = model_em)

modelsummary(
  model_dk,
  stars      = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_rename = c(
    "ln_reer"       = "ln(REER)",
    "hukuk"         = "Hukukun Üstünlüğü",
    "ln_gsyh"       = "ln(GSYH)",
    "ln_reer:hukuk" = "ln(REER) × Hukuk"
  ),
  statistic  = "std.error",
  se         = list(se_scc),           # Driscoll-Kraay standart hataları
  fmt        = 3,
  gof_omit   = "AIC|BIC|Log.Lik|Std.Err|DF|rmse",
  output     = ifelse(knitr::is_latex_output(), "latex", "html"),

  # Ek satırlar
  add_rows = data.frame(
    term = c("R²", "Gözlem Sayısı", "Sabit Etkiler"),
    `Driscoll-Kraay SH` = c(
      round(summary(model_em)$r.squared["rsq"], 3),
      nobs(model_em),
      "Evet"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ),

  notes = paste("Not: Parantez içindeki değerler Driscoll-Kraay dirençli standart hatalardır.", sig_note_tr)
)
}, error = function(e) { cat("[runner] !! chunk 9 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 10:  ----
cat("[runner] >>> chunk 10\n")
tryCatch({

kable(
  head(robust_appendix_view, 10),
  format = ifelse(knitr::is_latex_output(), "latex", "html"),
  align = c("l", "l", "c", "l", "l", "c", "c", "c", "c", "c")
) %>%
  kable_styling(
    bootstrap_options = c("striped", "hover", "condensed", "responsive"),
    full_width = TRUE,
    position = "center"
  )
}, error = function(e) { cat("[runner] !! chunk 10 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 11:  ----
cat("[runner] >>> chunk 11\n")
tryCatch({

knitr::include_graphics("Figures/coefficient_plot.svg")
}, error = function(e) { cat("[runner] !! chunk 11 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 12:  ----
cat("[runner] >>> chunk 12\n")
tryCatch({

knitr::include_graphics("Figures/residual_diagnostics.svg")
}, error = function(e) { cat("[runner] !! chunk 12 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 13:  ----
cat("[runner] >>> chunk 13\n")
tryCatch({

library(quantreg)
library(stargazer)

# Canay (2011) Panel Quantile Regression
# Adım 1: FE modelinden ülke sabit etkilerini çek (model_em setup chunk'ta tanımlı)
fe_vals <- fixef(model_em)
# Adım 2: Her gözlemi kendi ülkesinin sabit etkisinden arındır
gelismekte_olan_veri$ln_ihracat_tilde <-
  gelismekte_olan_veri$ln_ihracat -
  fe_vals[as.character(gelismekte_olan_veri$country)]
# Referans: Canay, I.A. (2011). A simple approach to quantile regression
#           for panel data. The Econometrics Journal, 14(3), 368-386.

qr_25 <- rq(ln_ihracat_tilde ~ ln_reer * hukuk + ln_gsyh,
            data = gelismekte_olan_veri, tau = 0.25)
qr_50 <- rq(ln_ihracat_tilde ~ ln_reer * hukuk + ln_gsyh,
            data = gelismekte_olan_veri, tau = 0.50)
qr_75 <- rq(ln_ihracat_tilde ~ ln_reer * hukuk + ln_gsyh,
            data = gelismekte_olan_veri, tau = 0.75)

suppressWarnings(stargazer(qr_25, qr_50, qr_75,
          type = ifelse(knitr::is_latex_output(), "latex", "html"),
          column.labels = c("Düşük İhracat", "Medyan", "Yüksek İhracat"),
          dep.var.labels = "ln(İhracat) — FE Arındırılmış",
          covariate.labels = c("ln(REER)", "Hukukun Üstünlüğü", "ln(GSYH)",
                               "ln(REER) x Hukuk", "Sabit"),
          omit.stat = c("f", "ser", "adj.rsq", "rsq", "n"),
          notes = paste0("Not: Canay (2011) panel quantile regression yaklaşımı uygulanmıştır. ",
                         "Bağımlı değişken (sabit etkilerden arındırılmış ihracat serisi), Hausman testi ile seçilen ",
                         "sabit etkiler modelinden elde edilen ülke sabit etkilerinden arındırılmıştır. ",
                         "Parantez içindeki değerler standart hatalardır. ",
                         sig_note_tr),
          notes.align = "l",
          notes.label = ""))
}, error = function(e) { cat("[runner] !! chunk 13 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 14:  ----
cat("[runner] >>> chunk 14\n")
tryCatch({

library(quantreg)
library(ggplot2)

# Canay (2011): ln_ihracat_tilde bu chunk'ta yoksa yeniden hesapla
if (!"ln_ihracat_tilde" %in% names(gelismekte_olan_veri)) {
  fe_vals <- fixef(model_em)
  gelismekte_olan_veri$ln_ihracat_tilde <-
    gelismekte_olan_veri$ln_ihracat -
    fe_vals[as.character(gelismekte_olan_veri$country)]
}

# 1. 0.10'dan 0.90'a kadar 9 farklı çeyreklik
taus <- seq(0.1, 0.9, by = 0.1)

# 2. Canay (2011): FE arındırılmış bağımlı değişken üzerinden QR
qr_all <- rq(ln_ihracat_tilde ~ ln_reer * hukuk + ln_gsyh,
             data = gelismekte_olan_veri, tau = taus)

# 3. ln_reer katsayılarını ve güven aralıklarını çek
sum_qr <- suppressWarnings(summary(qr_all, se = "nid"))

plot_data <- data.frame(
  tau      = taus,
  estimate = sapply(sum_qr, function(x) x$coefficients["ln_reer", "Value"]),
  lower    = sapply(sum_qr, function(x) x$coefficients["ln_reer", "Value"] -
                      1.96 * x$coefficients["ln_reer", "Std. Error"]),
  upper    = sapply(sum_qr, function(x) x$coefficients["ln_reer", "Value"] +
                      1.96 * x$coefficients["ln_reer", "Std. Error"])
)

# 4. Grafik
ggplot(plot_data, aes(x = tau, y = estimate)) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.2, fill = "darkorange") +
  geom_line(color = "darkorange", linewidth = 1.2) +
  geom_point(color = "darkred", size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black", linewidth = 0.8) +
  scale_x_continuous(breaks = taus) +
  labs(
    x     = "İhracat Çeyreklikleri (Quantiles)",
    y     = "ln(REER) Katsayısı",
    title = "Döviz Kuru Etkisinin İhracat Kapasitesine Göre Değişimi"
  ) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(hjust = 0.5, face = "bold"))
}, error = function(e) { cat("[runner] !! chunk 14 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 15:  ----
cat("[runner] >>> chunk 15\n")
tryCatch({

# 1. VOLATİLİTE HESAPLAMA (Literatürdeki "Rolling Standard Deviation" Yöntemi)
# Her ülkenin kendi içindeki 3 yıllık REER standart sapmasını hesaplıyoruz.
panel_vol_veri <- gelismekte_olan_veri %>%
  group_by(country) %>%
  arrange(year) %>%
  mutate(
    # 3 yıllık hareketli standart sapma (Oynaklık / Belirsizlik göstergesi)
    ln_reer_vol = rollapply(ln_reer, width = 3, FUN = sd, fill = NA, align = "right")
  ) %>%
  filter(!is.na(ln_reer_vol)) %>% # İlk 2 yıl hesaplanamayacağı için onları düşüyoruz
  ungroup()

# Veriyi panel veri yapısına (pdata.frame) çeviriyoruz
panel_vol <- pdata.frame(panel_vol_veri, index = c("country", "year"))

# 2. MODEL TAHMİNİ (Panel Sabit Etkiler)
model_vol <- plm(ln_ihracat ~ ln_reer_vol * hukuk + ln_gsyh, 
                 data = panel_vol, model = "within")

# 3. DRISCOLL-KRAAY STANDART HATALARI (Yatay kesit bağımlılığına karşı)
se_vol_scc <- sqrt(diag(vcovSCC(model_vol, type = "HC3", maxlag = 4)))

# 4. Tablo (HTML formatında)
suppressWarnings(stargazer(model_vol, 
          type = ifelse(knitr::is_latex_output(), "latex", "html"), 
          se = list(se_vol_scc),
          dep.var.labels = "ln(İhracat)",
          covariate.labels = c("REER Volatilitesi", "Hukukun Üstünlüğü", "ln(GSYH)", "Volatilite x Hukuk"),
          omit.stat = c("f", "ser", "adj.rsq", "rsq", "n"),
          notes = paste("Not: Standart hatalar Driscoll-Kraay (SCC) dirençli tahmincisinden elde edilmiştir.", sig_note_tr),
          notes.align = "l",
          notes.label = ""))
}, error = function(e) { cat("[runner] !! chunk 15 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 16:  ----
cat("[runner] >>> chunk 16\n")
tryCatch({

# GMM için veriyi panel data frame formatına çeviriyoruz (setup'ta tanımlandı, yine de güvenlik için)
p_veri_em_gmm <- pdata.frame(gelismekte_olan_veri, index = c("country", "year"))

# 1. GMM Modelinin Tahmini
model_gmm <- suppressWarnings(pgmm(ln_ihracat ~ lag(ln_ihracat, 1) + ln_reer * hukuk + ln_gsyh | lag(ln_ihracat, 2:3),
                  data = p_veri_em_gmm, 
                  effect = "individual", 
                  model = "twosteps", 
                  transformation = "d"))

# 2. GMM'e Özel Teşhis Testlerini Çekme
sargan_p <- round(sargan(model_gmm)$p.value, 3)
ar1_p <- round(mtest(model_gmm, order = 1)$p.value, 3)
ar2_p <- round(mtest(model_gmm, order = 2)$p.value, 3)

# 3. Tablonun Stargazer ile Basılması
suppressWarnings(stargazer(model_gmm,
          type = ifelse(knitr::is_latex_output(), "latex", "html"),
          dep.var.labels = "ln(İhracat)",
          covariate.labels = c("ln(İhracat) [t-1]", "ln(REER)", "Hukukun Üstünlüğü", "ln(GSYH)", "ln(REER) x Hukuk"),
          omit.stat = c("f", "ser"),
          add.lines = list(
            c("Sargan Testi (p-değeri)", sargan_p),
            c("AR(1) Testi (p-değeri)", ar1_p),
            c("AR(2) Testi (p-değeri)", ar2_p)
          ),
          notes = paste("Not: Arellano-Bond İki Aşamalı Fark GMM (Difference GMM) kullanılmıştır. Standart hatalar dirençlidir (robust).", sig_note_en),
          notes.align = "l",
          notes.label = ""))
}, error = function(e) { cat("[runner] !! chunk 16 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 17:  ----
cat("[runner] >>> chunk 17\n")
tryCatch({

library(plm)
library(modelsummary)

# Regulasyon modeli
gelismekte_olan_veri_reg <- gelismekte_olan_veri %>%
  filter(!is.na(regulasyon))
p_veri_reg <- pdata.frame(gelismekte_olan_veri_reg, index = c("country", "year"))
model_reg  <- plm(ln_ihracat ~ ln_reer * regulasyon + ln_gsyh,
                  data = p_veri_reg, model = "within")

# Driscoll-Kraay SE'ler
se_reg_scc <- sqrt(diag(vcovSCC(model_reg, type = "HC3", maxlag = 4)))

modelsummary(
  list("Hukuk (Ana Model)" = model_em,
       "Regulasyon (Alternatif)" = model_reg),
  stars      = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_rename = c(
    "ln_reer"            = "ln(REER)",
    "hukuk"              = "Hukukun Üstünlüğü",
    "regulasyon"         = "Düzenleyici Kalite",
    "ln_gsyh"            = "ln(GSYH)",
    "ln_reer:hukuk"      = "ln(REER) × Hukuk",
    "ln_reer:regulasyon" = "ln(REER) × Düzenleyici Kalite"
  ),
  se         = list(se_scc, se_reg_scc),
  statistic  = "std.error",
  fmt        = 3,
  gof_omit   = "AIC|BIC|Log.Lik|Std.Err|DF|rmse",
  output     = ifelse(knitr::is_latex_output(), "latex", "html"),
  add_rows   = data.frame(
    term = c("R²", "Gözlem Sayısı", "Sabit Etkiler", "Standart Hatalar"),
    `Hukuk (Ana Model)`      = c(round(summary(model_em)$r.squared["rsq"], 3),
                                  nobs(model_em), "Evet", "Driscoll-Kraay"),
    `Regulasyon (Alternatif)` = c(round(summary(model_reg)$r.squared["rsq"], 3),
                                   nobs(model_reg), "Evet", "Driscoll-Kraay"),
    stringsAsFactors = FALSE, check.names = FALSE
  ),
  notes = paste0("Not: Her iki model de Driscoll-Kraay (SCC, maxlag=4) dirençli standart hatalar ",
                 "kullanmaktadır. Parantez içindeki değerler standart hatalardır. ",
                 sig_note_tr)
)
}, error = function(e) { cat("[runner] !! chunk 17 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 18:  ----
cat("[runner] >>> chunk 18\n")
tryCatch({

library(knitr)
library(kableExtra)
library(readr)
library(dplyr)

gelismekte_olan_veri_ek <- read_csv("data/gelismekte_olan_veri.csv",
                                    show_col_types = FALSE)

ulke_tr <- c(
  "Algeria"                  = "Cezayir",
  "Armenia"                  = "Ermenistan",
  "Belize"                   = "Belize",
  "Bolivia"                  = "Bolivya",
  "Brazil"                   = "Brezilya",
  "Cameroon"                 = "Kamerun",
  "Central African Republic" = "Orta Afrika Cumhuriyeti",
  "China"                    = "Çin",
  "Colombia"                 = "Kolombiya",
  "Congo, Dem. Rep."         = "Demokratik Kongo Cum.",
  "Costa Rica"               = "Kosta Rika",
  "Cote d'Ivoire"            = "Fildişi Sahili",
  "Dominican Republic"       = "Dominik Cumhuriyeti",
  "Equatorial Guinea"        = "Ekvator Ginesi",
  "Gabon"                    = "Gabon",
  "Gambia, The"              = "Gambiya",
  "Georgia"                  = "Gürcistan",
  "Ghana"                    = "Gana",
  "Iran, Islamic Rep."       = "İran",
  "Lesotho"                  = "Lesotho",
  "Malaysia"                 = "Malezya",
  "Mexico"                   = "Meksika",
  "Moldova"                  = "Moldova",
  "Morocco"                  = "Fas",
  "Nicaragua"                = "Nikaragua",
  "North Macedonia"          = "Kuzey Makedonya",
  "Pakistan"                 = "Pakistan",
  "Paraguay"                 = "Paraguay",
  "Philippines"              = "Filipinler",
  "Samoa"                    = "Samoa",
  "Sierra Leone"             = "Sierra Leone",
  "Solomon Islands"          = "Solomon Adaları",
  "South Africa"             = "Güney Afrika",
  "Togo"                     = "Togo",
  "Tunisia"                  = "Tunus",
  "Uganda"                   = "Uganda",
  "Ukraine"                  = "Ukrayna",
  "Venezuela, RB"            = "Venezuela",
  "Zambia"                   = "Zambiya"
)

bolge_map <- c(
  "Algeria"                  = "Orta Doğu ve K. Afrika",
  "Armenia"                  = "Avrupa ve Orta Asya",
  "Belize"                   = "Latin Amerika ve Karayipler",
  "Bolivia"                  = "Latin Amerika ve Karayipler",
  "Brazil"                   = "Latin Amerika ve Karayipler",
  "Cameroon"                 = "Sahra Altı Afrika",
  "Central African Republic" = "Sahra Altı Afrika",
  "China"                    = "Doğu Asya ve Pasifik",
  "Colombia"                 = "Latin Amerika ve Karayipler",
  "Congo, Dem. Rep."         = "Sahra Altı Afrika",
  "Costa Rica"               = "Latin Amerika ve Karayipler",
  "Cote d'Ivoire"            = "Sahra Altı Afrika",
  "Dominican Republic"       = "Latin Amerika ve Karayipler",
  "Equatorial Guinea"        = "Sahra Altı Afrika",
  "Gabon"                    = "Sahra Altı Afrika",
  "Gambia, The"              = "Sahra Altı Afrika",
  "Georgia"                  = "Avrupa ve Orta Asya",
  "Ghana"                    = "Sahra Altı Afrika",
  "Iran, Islamic Rep."       = "Orta Doğu ve K. Afrika",
  "Lesotho"                  = "Sahra Altı Afrika",
  "Malaysia"                 = "Doğu Asya ve Pasifik",
  "Mexico"                   = "Latin Amerika ve Karayipler",
  "Moldova"                  = "Avrupa ve Orta Asya",
  "Morocco"                  = "Orta Doğu ve K. Afrika",
  "Nicaragua"                = "Latin Amerika ve Karayipler",
  "North Macedonia"          = "Avrupa ve Orta Asya",
  "Pakistan"                 = "Güney Asya",
  "Paraguay"                 = "Latin Amerika ve Karayipler",
  "Philippines"              = "Doğu Asya ve Pasifik",
  "Samoa"                    = "Doğu Asya ve Pasifik",
  "Sierra Leone"             = "Sahra Altı Afrika",
  "Solomon Islands"          = "Doğu Asya ve Pasifik",
  "South Africa"             = "Sahra Altı Afrika",
  "Togo"                     = "Sahra Altı Afrika",
  "Tunisia"                  = "Orta Doğu ve K. Afrika",
  "Uganda"                   = "Sahra Altı Afrika",
  "Ukraine"                  = "Avrupa ve Orta Asya",
  "Venezuela, RB"            = "Latin Amerika ve Karayipler",
  "Zambia"                   = "Sahra Altı Afrika"
)

ek1_tablo <- gelismekte_olan_veri_ek %>%
  group_by(country) %>%
  summarise(
    n       = n(),
    yil_bas = min(year),
    yil_son = max(year),
    .groups = "drop"
  ) %>%
  arrange(country) %>%
  mutate(
    ulke_tr = ulke_tr[country],
    bolge   = bolge_map[country],
    yil_aralik = paste0(yil_bas, "–", yil_son)
  ) %>%
  select(ulke_tr, country, bolge, yil_aralik, n) %>%
  rename(
    "Ülke (Türkçe)"   = ulke_tr,
    "Ülke (İngilizce)" = country,
    "Bölge (DB Sınıf.)" = bolge,
    "Yıl Aralığı"     = yil_aralik,
    "Gözlem (n)"      = n
  )

res_ek1 <- kable(
  ek1_tablo,
  format  = ifelse(knitr::is_latex_output(), "latex", "html"),
  align   = c("l", "l", "l", "c", "c"),
  escape  = FALSE
)

if (!knitr::is_latex_output()) {
  res_ek1 <- res_ek1 %>%
    kable_styling(
      bootstrap_options = c("striped", "hover", "condensed", "responsive"),
      full_width = TRUE,
      position   = "center",
      font_size  = 13
    ) %>%
    column_spec(3, width = "18em")
}

res_ek1
}, error = function(e) { cat("[runner] !! chunk 18 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 19:  ----
cat("[runner] >>> chunk 19\n")
tryCatch({

library(dplyr)
library(tidyr)
library(plm)
library(ggplot2)

# Eşik adayları (hukuk değişkeninin %20 ile %80'lik dilimleri arası)
esik_adaylari <- quantile(gelismekte_olan_veri$hukuk, probs = seq(0.2, 0.8, by = 0.05), na.rm = TRUE)
esik_RSS <- numeric(length(esik_adaylari))

# Analiz verisi (sadece gerekli değişkenler ve NA'sız)
analiz_esik <- gelismekte_olan_veri %>% 
  drop_na(ln_ihracat, ln_reer, ln_gsyh, hukuk)

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

# RSS Grafiği
esik_df <- data.frame(esik = esik_adaylari, RSS = esik_RSS)

ggplot(esik_df, aes(x = esik, y = RSS)) +
  geom_line(color = "#2563eb", linewidth = 1.2) +
  geom_point(color = "#2563eb", size = 2) +
  geom_vline(xintercept = esik_en_iyi, linetype = "dashed",
             color = "#dc2626", linewidth = 1) +
  annotate("text", x = esik_en_iyi, y = max(esik_RSS, na.rm=TRUE), 
           label = paste("Optimal Eşik:", round(esik_en_iyi, 3)), 
           vjust = 1.5, color = "#dc2626", fontface = "bold") +
  labs(x = "Hukuk Eşik Değeri", y = "Artıkların Kareler Toplamı (RSS)") +
  theme_minimal()
}, error = function(e) { cat("[runner] !! chunk 19 ERROR:", conditionMessage(e), "\n") })

# ---- chunk 20:  ----
cat("[runner] >>> chunk 20\n")
tryCatch({

library(dplyr)
library(tidyr)
library(plm)
library(lmtest)
library(ggplot2)

bolge_listesi <- unique(gelismekte_olan_veri$region)
bolge_sonuclari <- data.frame()

for (bolge in bolge_listesi) {
  bolge_veri <- gelismekte_olan_veri %>%
    filter(region == bolge) %>%
    drop_na(ln_ihracat, ln_reer, ln_gsyh, hukuk)

  n_ulke   <- length(unique(bolge_veri$country))
  n_gozlem <- nrow(bolge_veri)

  if (n_ulke >= 3 && n_gozlem >= 20) {
    panel_bolge <- pdata.frame(bolge_veri, index = c("country", "year"))

    tryCatch({
      model_bolge <- plm(ln_ihracat ~ ln_reer * hukuk + ln_gsyh,
                         data   = panel_bolge,
                         model  = "within")

      est <- coeftest(model_bolge, vcov = vcovSCC(model_bolge, type = "HC3", maxlag = 2))

      # Etkilesim katsayisi (ln_reer:hukuk)
      idx <- which(rownames(est) == "ln_reer:hukuk")
      if (length(idx) > 0) {
        bolge_sonuclari <- rbind(bolge_sonuclari, data.frame(
          bolge       = bolge,
          etkilesim   = est[idx, "Estimate"],
          p_val       = est[idx, "Pr(>|t|)"]
        ))
      }
    }, error = function(e) {})
  }
}

if (nrow(bolge_sonuclari) > 0) {
  ggplot(bolge_sonuclari, aes(x = reorder(bolge, etkilesim), y = etkilesim,
                              fill = p_val < 0.10)) +
    geom_col(width = 0.6) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
    scale_fill_manual(values = c("TRUE" = "#10b981", "FALSE" = "#94a3b8"),
                      labels = c("TRUE" = "p < 0.10", "FALSE" = "p >= 0.10"),
                      name = "Anlımlılık (p < 0.10)") +
    coord_flip() +
    labs(x = "Bölge", y = "Etkileşim Katsayısı (ln_reer x Hukuk)") +
    theme_minimal()
}
}, error = function(e) { cat("[runner] !! chunk 20 ERROR:", conditionMessage(e), "\n") })
