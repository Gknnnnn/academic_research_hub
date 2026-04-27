# =============================================================================
# prepare_rds.R
# Amaç: Tüm analizi çalıştır, sonuçları data/rds/ klasörüne kaydet.
# Kullanım: /usr/local/bin/Rscript prepare_rds.R
# Çıktılar: data/rds/*.rds  +  *.png figürler
# Bu script bir kez çalıştırılır; MGO_HBI_Tarim_Konya_v3.qmd render sırasında
# sadece readRDS() ile yükler, tekrar hesaplamaz.
# =============================================================================

cat("
╔══════════════════════════════════════════════════════════════════╗
║              prepare_rds.R — BAŞLADI                            ║
╚══════════════════════════════════════════════════════════════════╝\n")

if (!require("here")) install.packages("here"); # setwd(here())
dir.create("data/rds", recursive = TRUE, showWarnings = FALSE)

# ─── Paketler ────────────────────────────────────────────────────────────────
paketler <- c("WDI", "dplyr", "purrr", "readr", "countrycode", "zoo",
              "neuralnet", "NeuralNetTools", "ggplot2", "tidyr",
              "caret", "fastshap", "lmtest", "sandwich",
              "strucchange", "panelvar", "ggpubr", "scales",
              "cluster", "factoextra", "corrplot", "Metrics", "ggrepel",
              "plm", "tseries", "knitr", "kableExtra")

eksik <- paketler[!paketler %in% installed.packages()[, "Package"]]
if (length(eksik) > 0) {
  cat(sprintf("Eksik paketler yükleniyor: %s\n", paste(eksik, collapse = ", ")))
  install.packages(eksik, repos = "https://cran.r-project.org")
}
invisible(lapply(paketler, library, character.only = TRUE))

# --- PATH STABILIZATION (Nexus Reproducibility Protocol) ---
# Use Env Var if provided (from run_all.sh), else fall back to relative path discovery
DATA_HUB <- Sys.getenv("DATA_HUB")
if (DATA_HUB == "") {
  METHODS_DIR <- getwd() 
  PROJECT_NAME <- "2026-HBI-Tarim-Konya"
  DATA_HUB <- normalizePath(file.path(METHODS_DIR, "../../../../400-Data", PROJECT_NAME), mustWork = FALSE)
}
cat(sprintf("DEBUG: DATA_HUB is %s\n", DATA_HUB))

# Centralized Data Link
backup_panel <- normalizePath(file.path(DATA_HUB, "backup", "veri_tam_panel.csv"), mustWork = FALSE)
backup_model <- normalizePath(file.path(DATA_HUB, "backup", "model_verisi.csv"), mustWork = FALSE)
rds_out_dir  <- normalizePath(file.path(DATA_HUB, "rds"), mustWork = FALSE)

dir.create(rds_out_dir, recursive = TRUE, showWarnings = FALSE)
# ---------------------------------------------------------

# ─── 0. VERİ HAZIRLAMA ───────────────────────────────────────────────────────
cat("\n[0/9] Veri hazırlanıyor (yedek CSV'den)...\n")

# Önce yedek CSV'den yükle; WDI API yoksa sorun yaşanmasın

if (file.exists(backup_panel)) {
  cat(sprintf("  → %s yükleniyor...\n", backup_panel))
  veri_tam_panel <- read_csv(backup_panel, show_col_types = FALSE) %>%
    mutate(year = as.integer(year))
} else {
  cat("  → Yedek bulunamadı; WDI'dan indiriliyor...\n")
  gostergeler <- c(tarim_gsyh = "NV.AGR.TOTL.ZS",
                   emek       = "SL.AGR.EMPL.ZS",
                   toprak     = "AG.LND.AGRI.ZS",
                   gubre      = "AG.CON.FERT.ZS",
                   verim      = "AG.YLD.CREL.KG",
                   ticaret    = "TX.VAL.FOOD.ZS.UN")
  veri_raw_list <- lapply(names(gostergeler), function(n)
    WDI(indicator = gostergeler[n], start = 2000, end = 2020, extra = TRUE))
  veri_raw <- veri_raw_list %>% reduce(left_join, by = c("iso3c", "year", "country"))
  veri_wdi_temiz <- veri_raw %>%
    filter(!is.na(region.x) & region.x != "Aggregates") %>%
    select(country, iso3c, year, region = region.x, all_of(names(gostergeler))) %>%
    na.omit() %>% group_by(iso3c) %>% filter(n() == 21) %>% ungroup()
  fao_ham_veri  <- read_csv("fao_makine.csv", show_col_types = FALSE)
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
  # Yedek kaydet
  write_csv(veri_tam_panel, backup_panel)
}

# Gelir grubu metadata (WDI_data ya da sabit tanım)
ulke_gelir_tanim <- data.frame(
  iso3c = c(
    # Yüksek gelirli (örneklem)
    "AUS","AUT","BEL","CAN","CHE","CZE","DEU","DNK","ESP","EST","FIN","FRA","GBR",
    "GRC","HUN","IRL","ISL","ISR","ITA","JPN","KOR","LTU","LUX","LVA","NLD","NOR",
    "NZL","POL","PRT","SVK","SVN","SWE","USA","CHL","HRV","CYP","MLT","SGP","ARE",
    "BHR","KWT","OMN","QAT","SAU","URY","PAN","TTO","BRB","ATG","BHS"
  ),
  Gelir_Grubu = "Yüksek Gelirli",
  stringsAsFactors = FALSE
)
# Geri kalanları orta/düşük olarak sınıflandır
tum_iso <- unique(veri_tam_panel$iso3c)
diger_iso <- setdiff(tum_iso, ulke_gelir_tanim$iso3c)
# WDI_data ile zenginleştir (mevcutsa)
ulke_meta_final <- tryCatch({
  WDI_data$country %>% as.data.frame() %>%
    select(iso3c, income, region) %>% filter(region != "Aggregates") %>%
    mutate(Gelir_Grubu = case_when(
      income == "High income"                                       ~ "Yüksek Gelirli",
      income %in% c("Upper middle income", "Lower middle income")  ~ "Orta Gelirli",
      income == "Low income"                                        ~ "Düşük Gelirli",
      TRUE                                                          ~ "Orta Gelirli"
    )) %>% distinct(iso3c, .keep_all = TRUE)
}, error = function(e) {
  # WDI_data yoksa basit tanım
  data.frame(
    iso3c = tum_iso,
    Gelir_Grubu = ifelse(tum_iso %in% ulke_gelir_tanim$iso3c, "Yüksek Gelirli", "Orta Gelirli"),
    stringsAsFactors = FALSE
  )
})

ulke_gruplari_listesi <- veri_tam_panel %>%
  filter(year == 2020) %>%
  select(country, iso3c) %>%
  distinct() %>%
  left_join(ulke_meta_final, by = "iso3c")

cat(sprintf("  Panel: %d ülke, %d yıl, %d gözlem\n",
    n_distinct(veri_tam_panel$iso3c),
    n_distinct(veri_tam_panel$year),
    nrow(veri_tam_panel)))

# ─── 1. MODEL EĞİTİMİ ────────────────────────────────────────────────────────
cat("\n[1/9] YSA modeli eğitiliyor...\n")

model_verisi <- veri_tam_panel %>%
  select(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  mutate(across(everything(),
                function(x) (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))))

set.seed(44)
indeks     <- sample(1:nrow(model_verisi), round(0.8 * nrow(model_verisi)))
train_data <- model_verisi[indeks, ]
test_data  <- model_verisi[-indeks, ]

ysa_modeli <- neuralnet(
  tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
  data          = train_data,
  hidden        = c(7, 5),
  act.fct       = "logistic",
  linear.output = TRUE,
  stepmax       = 1e6,
  threshold     = 0.01
)

pred_train <- compute(ysa_modeli, train_data %>% select(-tarim_gsyh))$net.result
pred_test  <- compute(ysa_modeli, test_data  %>% select(-tarim_gsyh))$net.result
R2_train   <- cor(pred_train, train_data$tarim_gsyh)^2
R2_test    <- cor(pred_test,  test_data$tarim_gsyh)^2
tahminler  <- as.vector(pred_test)
gercekler  <- test_data$tarim_gsyh

cat(sprintf("  Train R²=%.4f  Test R²=%.4f\n", R2_train, R2_test))

# ─── 2. OLDEN ANALİZİ ────────────────────────────────────────────────────────
cat("\n[2/9] Olden analizi...\n")
tryCatch({
  olden_sonuc <- olden(ysa_modeli, bar_plot = FALSE)
  olden_df    <- data.frame(
    Degisken = rownames(olden_sonuc$data),
    Onem     = olden_sonuc$data[, 1]
  ) %>% arrange(desc(abs(Onem)))
}, error = function(e) {
  cat("Olden hatası:", e$message, "\n")
  olden_df <<- data.frame(Degisken = character(), Onem = numeric())
})

# ─── 3. SHAP DEĞERLERİ ───────────────────────────────────────────────────────
cat("\n[3/9] SHAP değerleri hesaplanıyor...\n")
test_X      <- test_data %>% select(emek, toprak, gubre, verim, ticaret, ekipman)
predict_fn  <- function(model, newdata) as.vector(compute(model, newdata)$net.result)

set.seed(42)
shap_sonuclar <- tryCatch(
  fastshap::explain(object = ysa_modeli, X = test_X,
                    pred_wrapper = predict_fn, nsim = 50, adjust = TRUE),
  error = function(e) { cat("SHAP hatası:", e$message, "\n"); NULL }
)
shap_df <- if (!is.null(shap_sonuclar)) as.data.frame(shap_sonuclar) else data.frame()

# SHAP beeswarm figürü
if (nrow(shap_df) > 0) {
  shap_uzun  <- shap_df %>% mutate(obs = row_number()) %>%
    pivot_longer(-obs, names_to = "Degisken", values_to = "SHAP")
  shap_X_uzun <- test_X %>% mutate(obs = row_number()) %>%
    pivot_longer(-obs, names_to = "Degisken", values_to = "Deger")
  shap_tam <- left_join(shap_uzun, shap_X_uzun, by = c("obs", "Degisken"))

  p_shap <- ggplot(shap_tam, aes(x = SHAP, y = reorder(Degisken, abs(SHAP)), color = Deger)) +
    geom_jitter(height = 0.25, alpha = 0.4, size = 1.5) +
    geom_vline(xintercept = 0, linewidth = 0.6) +
    scale_color_gradient2(low = "#2980b9", mid = "gray80", high = "#c0392b",
                          midpoint = 0.5, name = "Değer (norm.)") +
    labs(title = "SHAP: Gözlem Bazlı Değişken Önem Analizi",
         x = "SHAP Değeri", y = "Değişken") +
    theme_minimal()
  ggsave("../03-Results/shap_beeswarm.png", p_shap, width = 11, height = 7, dpi = 150)
}

# ─── 4. PANEL GRANGER ────────────────────────────────────────────────────────
cat("\n[4/9] Panel Granger nedensellik...\n")
degiskenler  <- c("emek", "toprak", "gubre", "verim", "ticaret", "ekipman")
panel_granger <- veri_tam_panel %>%
  select(iso3c, year, tarim_gsyh, all_of(degiskenler)) %>% arrange(iso3c, year)

granger_sonuclar <- do.call(rbind, lapply(degiskenler, function(deg) {
  ulkeler <- unique(panel_granger$iso3c)
  p_vals  <- vapply(ulkeler, function(u) {
    d <- panel_granger %>% filter(iso3c == u)
    if (nrow(d) < 5) return(NA_real_)
    tryCatch({
      y <- d$tarim_gsyh; x <- d[[deg]]
      df_g <- data.frame(
        y     = y,
        y_l1  = c(NA, head(y, -1)), y_l2 = c(NA, NA, head(y, -2)),
        x_l1  = c(NA, head(x, -1)), x_l2 = c(NA, NA, head(x, -2))
      ) %>% na.omit()
      if (nrow(df_g) < 4) return(NA_real_)
      f_test <- anova(lm(y ~ y_l1 + y_l2, data = df_g),
                      lm(y ~ y_l1 + y_l2 + x_l1 + x_l2, data = df_g))
      f_test$`Pr(>F)`[2]
    }, error = function(e) NA_real_)
  }, FUN.VALUE = numeric(1))
  p_vals <- p_vals[!is.na(p_vals)]
  if (length(p_vals) == 0) return(NULL)
  chi_sq <- -2 * sum(log(pmax(p_vals, 1e-10)))
  p_comb <- pchisq(chi_sq, df = 2 * length(p_vals), lower.tail = FALSE)
  data.frame(Degisken = deg, Chi_Sq = round(chi_sq, 2),
             p_degeri = round(p_comb, 4),
             Yorum = ifelse(p_comb < 0.05, "NEDENSELDİR ✓", "Nedensel değil"),
             stringsAsFactors = FALSE)
}))

p_granger <- ggplot(granger_sonuclar,
                    aes(x = reorder(Degisken, -log10(p_degeri)),
                        y = -log10(p_degeri), fill = p_degeri < 0.05)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_hline(yintercept = -log10(0.05), color = "#c0392b",
             linetype = "dashed", linewidth = 1) +
  scale_fill_manual(values = c("TRUE" = "#2980b9", "FALSE" = "#bdc3c7"), guide = "none") +
  coord_flip() +
  labs(title = "Panel Granger Nedensellik Testi",
       x = "Değişken", y = "-log10(p)") +
  theme_minimal()
ggsave("../03-Results/granger_nedensellik.png", p_granger, width = 10, height = 6, dpi = 150)

# ─── 5. BÖLÜM 9A: PANEL BİRİM KÖK ───────────────────────────────────────────
cat("\n[5/9] Panel birim kök (IPS + LLC)...\n")

panel_df_b9 <- veri_tam_panel %>%
  select(country, iso3c, year, tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  arrange(iso3c, year)
pdata_b9 <- pdata.frame(panel_df_b9, index = c("iso3c", "year"))
N_panel  <- length(unique(panel_df_b9$iso3c))
T_panel  <- length(unique(panel_df_b9$year))

degiskenler_bk <- c("tarim_gsyh", "emek", "toprak", "gubre", "verim", "ticaret", "ekipman")
birim_kok_sonuclar <- do.call(rbind, lapply(degiskenler_bk, function(deg) {
  tryCatch({
    # pseries doğrudan oluştur (pdata.frame köprüsü olmadan)
    ps <- plm::pseries(panel_df_b9[[deg]],
                  index = list(panel_df_b9$iso3c, panel_df_b9$year))
    ips <- plm::purtest(ps, test = "ips",      exo = "intercept", lags = "AIC")
    llc <- plm::purtest(ps, test = "levinlin", exo = "intercept", lags = "AIC")
    data.frame(
      Degisken = deg,
      IPS_stat = round(ips$statistic$statistic, 4),
      IPS_pval = round(ips$statistic$p.value,   4),
      LLC_stat = round(llc$statistic$statistic, 4),
      LLC_pval = round(llc$statistic$p.value,   4),
      Durum = ifelse(ips$statistic$p.value < 0.05 | llc$statistic$p.value < 0.05,
                     "Durağan I(0)", "I(1)")
    )
  }, error = function(e) { cat("  birim kök hatası:", deg, "-", e$message, "\n"); NULL })
}))
cat("  Birim kök testleri tamamlandı.\n")

# ─── 6. BÖLÜM 9B: EŞBÜTÜNLEŞİM ──────────────────────────────────────────────
cat("\n[6/9] Maddala-Wu eşbütünleşim...\n")
ulkeler_b9 <- unique(panel_df_b9$iso3c)

pedroni_sonuclar <- do.call(rbind, lapply(ulkeler_b9, function(ulke) {
  u_data <- panel_df_b9 %>% filter(iso3c == ulke) %>% arrange(year)
  if (nrow(u_data) < 10) return(NULL)
  tryCatch({
    fit       <- lm(tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman, data = u_data)
    kal       <- residuals(fit)
    if (length(kal) < 8 || var(kal) < 1e-10) return(NULL)
    adf_res   <- adf.test(kal, alternative = "stationary", k = 1)
    data.frame(iso3c = ulke,
               ADF_stat = round(adf_res$statistic, 4),
               ADF_pval = round(adf_res$p.value,   4))
  }, error = function(e) NULL)
}))

n_esb       <- nrow(pedroni_sonuclar)
fisher_chi2 <- -2 * sum(log(pmax(pedroni_sonuclar$ADF_pval, 1e-10)))
fisher_df   <- 2 * n_esb
fisher_pval <- pchisq(fisher_chi2, df = fisher_df, lower.tail = FALSE)
esb_oran    <- mean(pedroni_sonuclar$ADF_pval < 0.05, na.rm = TRUE)
cat(sprintf("  Fisher χ²=%.2f  p=%.6f  Eşbütünleşen: %.1f%%\n",
            fisher_chi2, fisher_pval, esb_oran * 100))

# ─── 7. BÖLÜM 9C: DUMİTRESCU-HURLİN ─────────────────────────────────────────
cat("\n[7/9] Dumitrescu-Hurlin (2012)...\n")

dh_granger_test <- function(data, y_var, x_var, lag = 2) {
  ulke_list <- unique(data$iso3c); N <- length(ulke_list); Tv <- length(unique(data$year)); K <- lag
  wald_stats <- vapply(ulke_list, function(ulke) {
    u <- data[data$iso3c == ulke, ]; u <- u[order(u$year), ]
    if (nrow(u) < (2 * K + 3)) return(NA_real_)
    tryCatch({
      y <- u[[y_var]]; x <- u[[x_var]]
      Y_emb <- embed(y, K + 1); X_emb <- embed(x, K + 1)
      y_dep <- Y_emb[, 1]; Y_lag <- Y_emb[, -1, drop = FALSE]; X_lag <- X_emb[, -1, drop = FALSE]
      n_obs <- length(y_dep)
      rss_u <- sum(lm.fit(cbind(1, Y_lag, X_lag), y_dep)$residuals^2)
      rss_r <- sum(lm.fit(cbind(1, Y_lag),         y_dep)$residuals^2)
      df2   <- n_obs - 2 * K - 1
      if (df2 <= 0 || rss_u <= 0) return(NA_real_)
      K * ((rss_r - rss_u) / K) / (rss_u / df2)
    }, error = function(e) NA_real_)
  }, FUN.VALUE = numeric(1))
  valid_w  <- wald_stats[!is.na(wald_stats)]; N_v <- length(valid_w); W_bar <- mean(valid_w)
  Z_bar    <- sqrt(N_v / (2 * K)) * (W_bar - K);  p_Zbar <- 2 * (1 - pnorm(abs(Z_bar)))
  denom_t  <- 2 * K * (Tv - 2 * K - 1) / (Tv - 2 * K - 3)
  Z_tilde  <- if (denom_t > 0) sqrt(N_v / denom_t) * (W_bar - K) else NA_real_
  p_Ztilde <- if (!is.na(Z_tilde)) 2 * (1 - pnorm(abs(Z_tilde))) else NA_real_
  list(W_bar = W_bar, N = N_v, K = K, Z_bar = Z_bar, p_Zbar = p_Zbar,
       Z_tilde = Z_tilde, p_Ztilde = p_Ztilde)
}

dh_sonuclar <- do.call(rbind, lapply(c("emek","toprak","gubre","verim","ticaret","ekipman"), function(xd) {
  cat(sprintf("  DH: %s → tarim_gsyh\n", xd))
  res <- tryCatch(dh_granger_test(panel_df_b9, "tarim_gsyh", xd, 2), error = function(e) NULL)
  if (is.null(res)) return(NULL)
  sig <- ifelse(res$p_Ztilde < 0.01, "***", ifelse(res$p_Ztilde < 0.05, "**",
         ifelse(res$p_Ztilde < 0.10, "*", "")))
  data.frame(X_Degisken = xd, W_bar = round(res$W_bar, 4),
             Z_bar = round(res$Z_bar, 4), p_Zbar = round(res$p_Zbar, 4),
             Z_tilde = round(res$Z_tilde, 4), p_Ztilde = round(res$p_Ztilde, 4),
             Karar = paste0(ifelse(res$p_Ztilde < 0.05, "Nedensellik var", "H0 reddedilemez"), sig))
}))

p_dh <- ggplot(dh_sonuclar, aes(x = reorder(X_Degisken, -p_Ztilde),
                                  y = -log10(pmax(p_Ztilde, 1e-6)),
                                  fill = p_Ztilde < 0.05)) +
  geom_col(width = 0.6, alpha = 0.85) +
  geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "#c0392b", linewidth = 1) +
  scale_fill_manual(values = c("TRUE" = "#2980b9", "FALSE" = "#bdc3c7"), guide = "none") +
  coord_flip() +
  labs(title = "Dumitrescu-Hurlin (2012) Panel Nedensellik",
       subtitle = sprintf("Z-tilde istatistiği, lag=2, N=%d, T=%d", N_panel, T_panel),
       x = "Bağımsız Değişken", y = "-log10(p-değeri)") +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 13))
ggsave("../03-Results/dh_nedensellik.png", p_dh, width = 10, height = 6, dpi = 150)

# ─── 8. BÖLÜM 9D: SYSTEM GMM ─────────────────────────────────────────────────
cat("\n[8/9] System GMM (Blundell-Bond)...\n")

gmm_ozet <- tryCatch({
  gmm_model <- pgmm(
    tarim_gsyh ~ lag(tarim_gsyh, 1) + emek + toprak + gubre + verim + ticaret + ekipman |
      lag(tarim_gsyh, 2:4) + lag(emek, 2:3) + lag(verim, 2:3),
    data = pdata_b9, effect = "twoways", model = "twosteps", transformation = "ld"
  )
  smry   <- summary(gmm_model, robust = TRUE)
  coefs  <- smry$coefficients
  sargan <- tryCatch(sargan(gmm_model), error = function(e) NULL)
  m1     <- tryCatch(mtest(gmm_model, order = 1, vcov = vcovHC), error = function(e) NULL)
  m2     <- tryCatch(mtest(gmm_model, order = 2, vcov = vcovHC), error = function(e) NULL)
  list(coefs = coefs, sargan = sargan, m1 = m1, m2 = m2, basarili = TRUE)
}, error = function(e) {
  cat("  System GMM başarısız:", e$message, "\n  FE yedek kullanılıyor...\n")
  tryCatch({
    fe_mod <- plm(tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
                  data = pdata_b9, model = "within", effect = "twoways")
    re_mod <- plm(tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman,
                  data = pdata_b9, model = "random")
    ht <- phtest(fe_mod, re_mod)
    list(fe_coefs = coef(fe_mod), hausman = ht, basarili = FALSE)
  }, error = function(e2) list(basarili = FALSE, hata = e2$message))
})

# ─── 9. EKC + SDG ────────────────────────────────────────────────────────────
cat("\n[9/9] EKC analizi ve SDG...\n")

ekc_sonuc <- tryCatch({
  # GDP/kişi: Lokal yedek kullanılıyor (Nexus Reproducibility Protocol)
  gdp_backup <- normalizePath(file.path(DATA_HUB, "backup", "gdp_pc.csv"), mustWork = FALSE)
  if (!file.exists(gdp_backup)) stop("KRİTİK HATA: gdp_pc.csv yedeği bulunamadı!")
  gdp_data <- read_csv(gdp_backup, show_col_types = FALSE)
  
  ekc_panel <- panel_df_b9 %>%
    left_join(gdp_data, by = c("iso3c", "year")) %>%
    filter(!is.na(gdp_pc) & gdp_pc > 0) %>%
    mutate(ln_gdp = log(gdp_pc), ln_gdp_sq = log(gdp_pc)^2)
  ekc_pdata  <- pdata.frame(ekc_panel, index = c("iso3c", "year"))
  ekc_model  <- plm(tarim_gsyh ~ ln_gdp + ln_gdp_sq,
                    data = ekc_pdata, model = "within", effect = "individual")
  ekc_coef   <- coef(ekc_model)
  turning_ln <- -ekc_coef["ln_gdp"] / (2 * ekc_coef["ln_gdp_sq"])
  turning_pc <- exp(turning_ln)

  gdp_seq    <- seq(min(ekc_panel$ln_gdp, na.rm = TRUE),
                    max(ekc_panel$ln_gdp, na.rm = TRUE), length.out = 300)
  pred_ekc   <- ekc_coef["ln_gdp"] * gdp_seq + ekc_coef["ln_gdp_sq"] * gdp_seq^2
  pred_ekc   <- pred_ekc - min(pred_ekc, na.rm = TRUE) +
                quantile(ekc_panel$tarim_gsyh, 0.10, na.rm = TRUE)
  yapi_taban <- quantile(ekc_panel$tarim_gsyh, 0.05, na.rm = TRUE)

  p_ekc <- ggplot() +
    geom_point(data = ekc_panel, aes(x = ln_gdp, y = tarim_gsyh),
               alpha = 0.08, color = "#95a5a6", size = 0.7) +
    geom_line(data = data.frame(x = gdp_seq, y = pred_ekc),
              aes(x = x, y = y), color = "#c0392b", linewidth = 1.4) +
    geom_hline(yintercept = yapi_taban, linetype = "dashed",
               color = "#27ae60", linewidth = 1.2) +
    annotate("text", x = max(gdp_seq) - 0.2, y = yapi_taban + 0.4,
             label = "Yapısal Taban (5. persentil)", color = "#27ae60",
             size = 3.2, hjust = 1, fontface = "bold") +
    labs(title = "EKC Hipotezi ve Yapısal Taban: Karşılaştırmalı Analiz",
         subtitle = "Kırmızı: EKC (FE) | Yeşil kesikli: Yapısal Taban alt sınırı",
         x = "ln(GDP per capita, 2015 sabit USD)", y = "Tarım GSYH Payı (%)") +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold", size = 13))
  ggsave("../03-Results/ekc_yapi_taban_karsilastirma.png", p_ekc, width = 10, height = 6, dpi = 150)

  list(coef = ekc_coef, turning_ln = turning_ln, turning_pc = turning_pc,
       sekil = "ekc_yapi_taban_karsilastirma.png")
}, error = function(e) {
  cat("  EKC hatası:", e$message, "\n")
  list(coef = NULL)
})

# SDG tablosu
sdg_uyum <- data.frame(
  SDG     = c("SDG 2", "SDG 8", "SDG 13", "SDG 1", "SDG 15"),
  Baslik  = c("Sıfır Açlık", "İnsana Yakışır İş", "İklim Eylemi",
              "Yoksulluğa Son", "Karasal Yaşam"),
  Baglanti = c(
    "Yapısal Taban gıda üretim tabanını korur; Lewis/Kuznets sıfır yakınsama reddedilir",
    "emek Granger/DH nedenselliği kırsal istihdamı doğrular",
    "ReLU robustness + Bölüm 9C iklim dayanıklılığını test eder",
    "Düşük gelirli ülke kümesinde tarım payı %29'da stabilize",
    "toprak değişkeni arazi bozulması ile doğrudan ilişkili"
  ),
  Analiz_Ref = c("Bölüm 9B Yapısal Taban", "Bölüm 4+9C DH",
                 "Bölüm 4.4 ReLU", "Bölüm 7 Kümeleme", "Bölüm 3 SHAP"),
  stringsAsFactors = FALSE
)

p_sdg <- ggplot(sdg_uyum, aes(x = SDG, y = 1, fill = SDG)) +
  geom_tile(color = "white", linewidth = 2, height = 0.8) +
  geom_text(aes(label = paste0(SDG, "\n", Baslik)),
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = c("SDG 2" = "#27ae60", "SDG 8" = "#2980b9",
                                "SDG 13" = "#8e44ad", "SDG 1" = "#e67e22",
                                "SDG 15" = "#16a085"), guide = "none") +
  labs(title = "Yapısal Taban Çalışmasının SDG Bağlantıları",
       subtitle = "SDG 2, 8 ve 13 öncelikli eşleşmeler",
       x = NULL, y = NULL) +
  theme_void() +
  theme(plot.title    = element_text(face = "bold", size = 12, hjust = 0.5),
        plot.subtitle = element_text(size = 9, hjust = 0.5, color = "gray40"),
        plot.margin   = margin(10, 10, 10, 10))
ggsave("../03-Results/sdg_uyum_tablosu.png", p_sdg, width = 12, height = 3.5, dpi = 150)

# ─── RDS KAYIT ───────────────────────────────────────────────────────────────
cat("\n[RDS] Tüm objeler kaydediliyor...\n")

saveRDS(veri_tam_panel,         file.path(rds_out_dir, "veri_tam_panel.rds"))
saveRDS(model_verisi,           file.path(rds_out_dir, "model_verisi.rds"))
saveRDS(train_data,             file.path(rds_out_dir, "train_data.rds"))
saveRDS(test_data,              file.path(rds_out_dir, "test_data.rds"))
saveRDS(ysa_modeli,             file.path(rds_out_dir, "ysa_modeli.rds"))
saveRDS(indeks,                 file.path(rds_out_dir, "indeks.rds"))
saveRDS(tahminler,              file.path(rds_out_dir, "tahminler.rds"))
saveRDS(gercekler,              file.path(rds_out_dir, "gercekler.rds"))
saveRDS(R2_train,               file.path(rds_out_dir, "R2_train.rds"))
saveRDS(R2_test,                file.path(rds_out_dir, "R2_test.rds"))
saveRDS(ulke_gruplari_listesi,  file.path(rds_out_dir, "ulke_gruplari_listesi.rds"))
saveRDS(olden_df,               file.path(rds_out_dir, "olden_df.rds"))
saveRDS(shap_df,                file.path(rds_out_dir, "shap_df.rds"))
saveRDS(granger_sonuclar,       file.path(rds_out_dir, "granger_sonuclar.rds"))
saveRDS(birim_kok_sonuclar,     file.path(rds_out_dir, "birim_kok_sonuclar.rds"))
saveRDS(pedroni_sonuclar,       file.path(rds_out_dir, "pedroni_sonuclar.rds"))
saveRDS(list(chi2 = fisher_chi2, pval = fisher_pval, oran = esb_oran, n = n_esb), 
        file.path(rds_out_dir, "fisher_esb.rds"))
saveRDS(dh_sonuclar,            file.path(rds_out_dir, "dh_sonuclar.rds"))
saveRDS(gmm_ozet,               file.path(rds_out_dir, "gmm_ozet.rds"))
saveRDS(ekc_sonuc,              file.path(rds_out_dir, "ekc_sonuc.rds"))
saveRDS(sdg_uyum,               file.path(rds_out_dir, "sdg_uyum.rds"))
saveRDS(list(N = N_panel, T = T_panel), file.path(rds_out_dir, "panel_meta.rds"))

cat("
╔══════════════════════════════════════════════════════════════════╗
║              prepare_rds.R — TAMAMLANDI                         ║
╠══════════════════════════════════════════════════════════════════╣
║  data/rds/ klasörüne 21 RDS dosyası kaydedildi.                 ║
║  PNG figürler kök dizine yazıldı.                               ║
║  Sonraki adım:                                                   ║
║  quarto render MGO_HBI_Tarim_Konya_v3.qmd --to docx             ║
╚══════════════════════════════════════════════════════════════════╝\n")
