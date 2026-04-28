## ============================================================
## IERFM v13 KONGRE — TAM VERİ + TABLO + METİN DOĞRULAMA
## Çalıştırma tarihi: 2026-04-30
## ============================================================

setwd("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-MGO-OB-Currency-Misalignment-CA/04-Manuscript")

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(tidyr); library(WDI)
  library(countrycode); library(fixest); library(plm); library(broom)
  library(strucchange)
})

cat("====================================================\n")
cat("IERFM v13 KONGRE — DATA CHECK RAPORU\n")
cat("====================================================\n\n")

## ---- 1. VERİ YÜKLEMESİ ----
cat(">> [1] Veri yükleniyor...\n")
df_panel <- read_excel("MIS_REER_approach_panel.xls")
df_clean <- df_panel %>%
  mutate(MIS_percent = Mis_TV * 100) %>%
  select(Country, Year, MIS_percent) %>%
  drop_na(MIS_percent) %>%
  mutate(iso3c = countrycode(Country, origin = 'country.name', destination = 'iso3c')) %>%
  filter(!is.na(iso3c))

em_iso <- c("BRA","CHL","CHN","COL","CZE","EGY","GRC","HUN","IND","IDN",
            "KOR","MYS","MEX","PER","PHL","POL","RUS","ZAF","THA","TUR")

wdi_cache_file <- "wdi_cache_v4.rds"
if (file.exists(wdi_cache_file)) {
  wdi_data <- readRDS(wdi_cache_file)
  cat("   WDI cache yüklendi:", wdi_cache_file, "\n")
} else {
  cat("   WDI çekiliyor (internet gerekli)...\n")
  wdi_data <- WDI(
    indicator = c(
      Current_Account = "BN.CAB.XOKA.GD.ZS",
      GDP_per_Capita  = "NY.GDP.PCAP.KD",
      GDP_Growth      = "NY.GDP.PCAP.KD.ZG",
      Inflation       = "FP.CPI.TOTL.ZG",
      Trade_Openness  = "NE.TRD.GNFS.ZS",
      FDI_Inflows     = "BX.KLT.DINV.WD.GD.ZS",
      Gov_Expenditure = "NE.CON.GOVT.ZS",
      FX_Reserves     = "FI.RES.XGLD.CD",
      External_Debt   = "DT.DOD.DECT.CD",
      Domestic_Credit = "FS.AST.DOMS.GD.ZS"
    ),
    country = "all", start = 1973, end = 2021, extra = TRUE
  )
  saveRDS(wdi_data, wdi_cache_file)
}

df_wdi <- wdi_data %>%
  filter(iso3c %in% em_iso) %>%
  rename_with(~ gsub("\\.", "_", .x)) %>%
  mutate(Year = as.integer(year)) %>%
  select(any_of(c("iso3c","Year","Current_Account","GDP_per_Capita","GDP_Growth",
                  "Inflation","Trade_Openness","Gov_Expenditure","FDI_Inflows",
                  "FX_Reserves","External_Debt","Domestic_Credit")))

df_emerging_full <- df_clean %>%
  inner_join(df_wdi, by = c("iso3c","Year")) %>%
  filter(!is.na(Current_Account), !is.na(MIS_percent))

max_yr <- max(df_emerging_full$Year, na.rm = TRUE)
df_emerging <- df_emerging_full %>% filter(Year <= max_yr - 4)

cat("   Birleşik panel satır sayısı:", nrow(df_emerging_full), "\n")
cat("   Ülke sayısı:", n_distinct(df_emerging_full$iso3c), "\n")
cat("   Yıl aralığı:", min(df_emerging_full$Year), "–", max(df_emerging_full$Year), "\n\n")

## ---- 2. TEMEL MODEL ----
cat(">> [2] TWFE temel model...\n")
model_em <- feols(
  Current_Account ~ l(MIS_percent, 1) + log(GDP_per_Capita) + Inflation +
    Trade_Openness + Gov_Expenditure | iso3c + Year,
  data = df_emerging_full, panel.id = ~iso3c + Year, cluster = ~iso3c
)

mis_coef     <- round(coef(model_em)[["l(MIS_percent, 1)"]], 4)
mis_coef_abs <- abs(mis_coef)
effect_10    <- round(mis_coef_abs * 10, 2)
mis_tidy     <- broom::tidy(model_em) %>% filter(term == "l(MIS_percent, 1)")
mis_pval     <- mis_tidy$p.value
n_obs        <- nobs(model_em)
n_country    <- n_distinct(df_emerging_full$iso3c)
yr_min       <- min(df_emerging_full$Year)
yr_max       <- max(df_emerging_full$Year)

cat("   METİN KONTROLÜ — Temel bulgular:\n")
cat(sprintf("   mis_coef        = %s\n", mis_coef))
cat(sprintf("   effect_10       = %s  (metinde: 'yaklaşık X puan')\n", effect_10))
cat(sprintf("   mis_pval        = %.4f  %s\n", mis_pval, ifelse(mis_pval < 0.01, "***", ifelse(mis_pval < 0.05, "**", ifelse(mis_pval < 0.10, "*", "NS")))))
cat(sprintf("   n_obs           = %s\n", n_obs))
cat(sprintf("   n_country       = %s  (metinde: 20 yükselen piyasa)\n", n_country))
cat(sprintf("   yr_min/yr_max   = %s – %s\n", yr_min, yr_max))

if (n_country != 20) cat("   ⚠️ UYARI: n_country ≠ 20!\n")
if (mis_pval >= 0.10) cat("   ⚠️ UYARI: mis_coef anlamsız! (p >= 0.10)\n")

## ---- 3. POLY-KRİZ MODELİ ----
cat("\n>> [3] Poly-Crisis etkileşim modeli...\n")
df_emerging_full$PolyCrisis <- as.integer(df_emerging_full$Year %in% c(2008,2009,2020,2021))
model_em_polycrisis <- feols(
  Current_Account ~ l(MIS_percent,1)*PolyCrisis + log(GDP_per_Capita) +
    Inflation + Trade_Openness + Gov_Expenditure | iso3c + Year,
  data = df_emerging_full, panel.id = ~iso3c+Year, cluster = ~iso3c
)

poly_tidy <- broom::tidy(model_em_polycrisis) %>% filter(term == "l(MIS_percent, 1):PolyCrisis")
poly_coef <- if(nrow(poly_tidy)>0) round(poly_tidy$estimate, 4) else NA
poly_pval <- if(nrow(poly_tidy)>0) poly_tidy$p.value else NA

cat(sprintf("   poly_coef = %s\n", poly_coef))
cat(sprintf("   poly_pval = %.4f  %s\n", ifelse(is.na(poly_pval), NA, poly_pval),
            ifelse(is.na(poly_pval), "NA", ifelse(poly_pval<0.01,"***",ifelse(poly_pval<0.05,"**",ifelse(poly_pval<0.10,"*","NS"))))))
if (!is.na(poly_coef) && poly_coef > 0) {
  cat("   ⚠️ UYARI: poly_coef POZİTİF — metinde 'negatif yönde' deniyor!\n")
} else {
  cat("   ✓ poly_coef negatif (metinle uyumlu)\n")
}

## ---- 4. GECIKME 2-3 ----
cat("\n>> [4] Gecikme 2 ve 3 modelleri...\n")
model_em_lag2 <- feols(Current_Account ~ l(MIS_percent,2) + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c+Year, data=df_emerging_full, panel.id=~iso3c+Year, cluster=~iso3c)
model_em_lag3 <- feols(Current_Account ~ l(MIS_percent,3) + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c+Year, data=df_emerging_full, panel.id=~iso3c+Year, cluster=~iso3c)

lag2_p <- broom::tidy(model_em_lag2) %>% filter(grepl("MIS", term)) %>% pull(p.value)
lag3_p <- broom::tidy(model_em_lag3) %>% filter(grepl("MIS", term)) %>% pull(p.value)
lag2_b <- coef(model_em_lag2)[grep("MIS", names(coef(model_em_lag2)))]
lag3_b <- coef(model_em_lag3)[grep("MIS", names(coef(model_em_lag3)))]

cat(sprintf("   Lag2: β = %.4f, p = %.4f  %s\n", lag2_b, lag2_p, ifelse(lag2_p<0.10,"*","NS")))
cat(sprintf("   Lag3: β = %.4f, p = %.4f  %s\n", lag3_b, lag3_p, ifelse(lag3_p<0.10,"*","NS")))
if (lag2_p < 0.05 || lag3_p < 0.05) {
  cat("   ⚠️ UYARI: Lag2/Lag3 anlamlı — metinde 'anlamsız' deniyorsa tutarsızlık var!\n")
} else {
  cat("   ✓ Lag2/Lag3 anlamsız (metinle uyumlu)\n")
}

## ---- 5. ASİMETRİ ----
cat("\n>> [5] Asimetri (OV/UV) modeli...\n")
df_emerging_full <- df_emerging_full %>%
  mutate(MIS_over  = pmax(MIS_percent, 0),
         MIS_under = pmax(-MIS_percent, 0))
model_em_asym <- feols(Current_Account ~ l(MIS_over,1) + l(MIS_under,1) + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c+Year, data=df_emerging_full, panel.id=~iso3c+Year, cluster=~iso3c)
ov_b <- coef(model_em_asym)["l(MIS_over, 1)"]
uv_b <- coef(model_em_asym)["l(MIS_under, 1)"]
ov_p <- broom::tidy(model_em_asym) %>% filter(term=="l(MIS_over, 1)") %>% pull(p.value)
uv_p <- broom::tidy(model_em_asym) %>% filter(term=="l(MIS_under, 1)") %>% pull(p.value)
cat(sprintf("   OV: β = %.4f, p = %.4f  %s\n", ov_b, ov_p, ifelse(ov_p<0.10,"*","NS")))
cat(sprintf("   UV: β = %.4f, p = %.4f  %s\n", uv_b, uv_p, ifelse(uv_p<0.10,"*","NS")))
if (ov_b > 0) cat("   ⚠️ UYARI: OV katsayısı POZİTİF — 'negatif' beklentisiyle çelişiyor!\n")
if (uv_b > 0) cat("   ⚠️ UYARI: UV katsayısı POZİTİF — teorik beklenti negatif!\n")

## ---- 6. EŞİK MODEL ----
cat("\n>> [6] Eşik model (±%15)...\n")
df_emerging_full <- df_emerging_full %>%
  mutate(MIS_mod    = sign(MIS_percent) * pmin(abs(MIS_percent), 15),
         MIS_excess = sign(MIS_percent) * pmax(abs(MIS_percent) - 15, 0))
model_em_threshold <- feols(Current_Account ~ l(MIS_mod,1) + l(MIS_excess,1) + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c+Year, data=df_emerging_full, panel.id=~iso3c+Year, cluster=~iso3c)
thr_mod_b <- coef(model_em_threshold)["l(MIS_mod, 1)"]
thr_exc_b <- coef(model_em_threshold)["l(MIS_excess, 1)"]
thr_mod_p <- broom::tidy(model_em_threshold) %>% filter(term=="l(MIS_mod, 1)") %>% pull(p.value)
thr_exc_p <- broom::tidy(model_em_threshold) %>% filter(term=="l(MIS_excess, 1)") %>% pull(p.value)
cat(sprintf("   MIS_mod (ılımlı, ≤±15): β = %.4f, p = %.4f  %s\n", thr_mod_b, thr_mod_p, ifelse(thr_mod_p<0.10,"*","NS")))
cat(sprintf("   MIS_excess (aşırı, >±15): β = %.4f, p = %.4f  %s\n", thr_exc_b, thr_exc_p, ifelse(thr_exc_p<0.10,"*","NS")))
if (!is.na(thr_exc_b) && !is.na(thr_mod_b)) {
  cat(sprintf("   Aşırı/Ilımlı oran: %.2fx\n", abs(thr_exc_b)/abs(thr_mod_b)))
  cat(sprintf("   Metinde 'excess belirgin biçimde büyük' → %s\n",
              ifelse(abs(thr_exc_b) > abs(thr_mod_b), "✓ UYUMLU", "⚠️ TUTARSIZ")))
}

## ---- 7. ALT DÖNEM ----
cat("\n>> [7] Alt dönem: pre/post-2000...\n")
model_em_pre2000  <- feols(Current_Account ~ l(MIS_percent,1) + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c+Year, data=df_emerging_full %>% filter(Year < 2000), panel.id=~iso3c+Year, cluster=~iso3c)
model_em_post2000 <- feols(Current_Account ~ l(MIS_percent,1) + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c+Year, data=df_emerging_full %>% filter(Year >= 2000), panel.id=~iso3c+Year, cluster=~iso3c)
pre_b <- coef(model_em_pre2000)["l(MIS_percent, 1)"]
pre_p <- broom::tidy(model_em_pre2000) %>% filter(grepl("MIS",term)) %>% pull(p.value)
post_b <- coef(model_em_post2000)["l(MIS_percent, 1)"]
post_p <- broom::tidy(model_em_post2000) %>% filter(grepl("MIS",term)) %>% pull(p.value)
cat(sprintf("   Pre-2000:  β = %.4f, p = %.4f  %s\n", pre_b, pre_p, ifelse(pre_p<0.10,"*","NS")))
cat(sprintf("   Post-2000: β = %.4f, p = %.4f  %s\n", post_b, post_p, ifelse(post_p<0.10,"*","NS")))
cat(sprintf("   Metinde 'modern dönemde istatistiksel anlamlılık görece zayıfladı' → %s\n",
            ifelse(post_p > pre_p, "✓ UYUMLU", "⚠️ KONTROL ET")))

## ---- 8. ECM MODELİ ----
cat("\n>> [8] MG-ECM modeli...\n")
df_ecm <- df_emerging_full %>%
  arrange(iso3c, Year) %>%
  mutate(CA_num=as.numeric(Current_Account), MIS_num=as.numeric(MIS_percent),
         GDP_num=as.numeric(GDP_per_Capita), INF_num=as.numeric(Inflation),
         TRD_num=as.numeric(Trade_Openness), GOV_num=as.numeric(Gov_Expenditure)) %>%
  group_by(iso3c) %>%
  mutate(L_CA=dplyr::lag(CA_num,1), L_MIS=dplyr::lag(MIS_num,1),
         L_log_GDP=dplyr::lag(log(GDP_num),1), L_Inflation=dplyr::lag(INF_num,1),
         L_Trade_Open=dplyr::lag(TRD_num,1), L_Gov_Exp=dplyr::lag(GOV_num,1),
         d_CA=CA_num-dplyr::lag(CA_num,1), d_MIS=MIS_num-dplyr::lag(MIS_num,1)) %>%
  ungroup() %>%
  filter(!is.na(L_CA), !is.na(d_CA), !is.na(d_MIS),
         !is.na(L_Gov_Exp), !is.na(L_Trade_Open), !is.na(L_Inflation),
         is.finite(d_CA), is.finite(L_CA))

pdata_ecm <- pdata.frame(df_ecm, index = c("iso3c","Year"))
ect_coef <- NA; n_ecm <- NA; r2_ecm <- NA
tryCatch({
  model_mg_ecm <- pmg(d_CA ~ L_CA + L_MIS + L_log_GDP + L_Inflation + L_Trade_Open + L_Gov_Exp + d_MIS,
                      data = pdata_ecm, model = "mg")
  s_ecm <- summary(model_mg_ecm)
  # Robust extraction: coeftest-style, handle different pmg summary formats
  ct_raw <- s_ecm$CoefTable
  if (is.matrix(ct_raw)) {
    ct_ecm <- as.data.frame(ct_raw)
  } else {
    ct_ecm <- as.data.frame(ct_raw)
  }
  colnames(ct_ecm) <- make.names(colnames(ct_ecm))
  # Use numeric column index for safety
  ect_coef  <- round(ct_ecm["L_CA",  1], 3)
  n_ecm     <- length(residuals(model_mg_ecm))
  r2_ecm    <- round(s_ecm$rsqr, 3)
  l_mis_ecm <- ct_ecm["L_MIS", 1]
  d_mis_ecm <- ct_ecm["d_MIS", 1]
  ect_p     <- ct_ecm["L_CA",  4]   # column 4 = p-value in pmg CoefTable
  cat(sprintf("   ECT (L_CA): β = %.3f, p = %.4f  %s\n", ect_coef, ect_p, ifelse(ect_p<0.01,"***",ifelse(ect_p<0.05,"**",ifelse(ect_p<0.10,"*","NS")))))
  cat(sprintf("   n_ecm = %s | r2_ecm = %s\n", n_ecm, r2_ecm))
  cat(sprintf("   Ayarlama hızı: |ECT|*100 = %.0f%%\n", abs(ect_coef)*100))
  cat(sprintf("   L_MIS (uzun dönem kur): β = %.4f\n", l_mis_ecm))
  cat(sprintf("   d_MIS (kısa dönem kur): β = %.4f\n", d_mis_ecm))
  if (ect_coef >= 0) cat("   ⚠️ UYARI: ECT POZİTİF — uzun dönem yakınsama yok!\n")
  if (abs(ect_coef) > 1) cat("   ⚠️ UYARI: ECT > 1 mutlak değerde — aşırı ayarlama!\n")
  cat(sprintf("   Metindeki 'yaklaşık %%X kadarı bir yıl içinde düzelir' = %.0f%% → %s\n",
              abs(ect_coef)*100,
              ifelse(abs(ect_coef) < 1 & ect_coef < 0, "✓ UYUMLU", "⚠️ KONTROL ET")))
}, error = function(e) cat("   ⚠️ ECM HATASI:", conditionMessage(e), "\n"))

## ---- 9. TANI TESTLERİ ----
cat("\n>> [9] Tanı testleri (CD, Maddala-Wu, CIPS, DH)...\n")
pdata_diag <- pdata.frame(df_emerging_full, index = c("iso3c","Year"))

# CD testi
cd_result <- tryCatch(
  pesaran.test(plm(Current_Account ~ MIS_percent + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure,
                   data=pdata_diag, model="within"), alternative="two.sided"),
  error=function(e) NULL)
if (!is.null(cd_result)) {
  cd_stat <- round(as.numeric(cd_result$statistic), 3)
  cd_pval <- as.numeric(cd_result$p.value)
  cat(sprintf("   CD testi: stat = %.3f, p = %.4f  %s\n", cd_stat, cd_pval, ifelse(cd_pval<0.05,"✓ CSD Var","⚠️ CSD Yok")))
  if (cd_pval >= 0.05) cat("   ⚠️ UYARI: CSD bulunamadı — metinde 'güçlü CSD mevcut' deniyor!\n")
} else {
  cat("   ⚠️ CD testi çalışmadı\n")
}

# Maddala-Wu
madwu_ca  <- tryCatch(purtest(pdata_diag$Current_Account, test="madwu", exo="intercept"), error=function(e) NULL)
madwu_mis <- tryCatch(purtest(pdata_diag$MIS_percent,     test="madwu", exo="intercept"), error=function(e) NULL)
if (!is.null(madwu_ca)) {
  mw_ca_p <- as.numeric(madwu_ca$statistic$p.value)
  cat(sprintf("   Maddala-Wu CA:  p = %.4f  → %s\n", mw_ca_p, ifelse(mw_ca_p<0.05,"Durağan I(0)","Birim Kök")))
}
if (!is.null(madwu_mis)) {
  mw_mis_p <- as.numeric(madwu_mis$statistic$p.value)
  cat(sprintf("   Maddala-Wu MIS: p = %.4f  → %s\n", mw_mis_p, ifelse(mw_mis_p<0.05,"Durağan I(0)","Birim Kök")))
}

# CIPS (custom)
cips_test <- function(mat) {
  tryCatch({
    n <- ncol(mat); tt <- nrow(mat)
    mean(sapply(1:n, function(i) {
      y <- mat[,i]; ycross <- rowMeans(mat[,-i, drop=FALSE])
      dy <- diff(y); ly <- y[-tt]; dcross <- diff(ycross)
      fit <- lm(dy ~ ly + ycross[-tt] + dcross)
      summary(fit)$coefficients[2, 3]
    }), na.rm=TRUE)
  }, error=function(e) NA)
}
mat_maker <- function(var) {
  df_emerging_full %>% select(iso3c, Year, all_of(var)) %>%
    arrange(Year, iso3c) %>% pivot_wider(names_from=iso3c, values_from=all_of(var)) %>%
    arrange(Year) %>% select(-Year) %>% as.matrix()
}
cips_ca_stat  <- cips_test(mat_maker("Current_Account"))
cips_mis_stat <- cips_test(mat_maker("MIS_percent"))
cat(sprintf("   CIPS CA:  stat = %.3f  (kritik: -2.14)  → %s\n", cips_ca_stat,  ifelse(cips_ca_stat  < -2.14, "Durağan","Birim Kök")))
cat(sprintf("   CIPS MIS: stat = %.3f  (kritik: -2.14)  → %s\n", cips_mis_stat, ifelse(cips_mis_stat < -2.14, "Durağan","Birim Kök")))

# DH Granger
granger_1 <- tryCatch(pgrangertest(Current_Account ~ MIS_percent,    data=pdata_diag, order=1), error=function(e) NULL)
granger_2 <- tryCatch(pgrangertest(MIS_percent ~ Current_Account,    data=pdata_diag, order=1), error=function(e) NULL)
if (!is.null(granger_1) && !is.null(granger_2)) {
  g1_stat <- round(as.numeric(granger_1$statistic), 3)
  g2_stat <- round(as.numeric(granger_2$statistic), 3)
  g1_p    <- granger_1$p.value
  g2_p    <- granger_2$p.value
  cat(sprintf("   DH MIS→CA: stat = %.3f, p = %.4f  %s\n", g1_stat, g1_p, ifelse(g1_p<0.10,"*","NS")))
  cat(sprintf("   DH CA→MIS: stat = %.3f, p = %.4f  %s\n", g2_stat, g2_p, ifelse(g2_p<0.10,"*","NS")))
  cat(sprintf("   Metinde 'tek yönlü MIS→CA' → %s\n",
              ifelse(g1_p < 0.10 && g2_p >= 0.10, "✓ UYUMLU",
                     ifelse(g1_p >= 0.10, "⚠️ MIS→CA anlamsız",
                            ifelse(g2_p < 0.10, "⚠️ Çift yönlü — metinle çelişiyor", "KONTROL ET")))))
}

## ---- 10. LOCAL PROJECTION ----
cat("\n>> [10] Local Projection (Jordà h=0..4)...\n")
lp_results <- list()
for (h in 0:4) {
  df_lp <- df_emerging_full %>%
    arrange(iso3c, Year) %>%
    group_by(iso3c) %>%
    mutate(CA_lead = dplyr::lead(Current_Account, h)) %>%
    ungroup() %>%
    filter(!is.na(CA_lead))
  tryCatch({
    m <- feols(CA_lead ~ MIS_percent + log(GDP_per_Capita) + Inflation + Trade_Openness + Gov_Expenditure | iso3c + Year,
               data=df_lp, panel.id=~iso3c+Year, cluster=~iso3c)
    lp_results[[h+1]] <- data.frame(
      Horizon = h,
      Coef    = coef(m)["MIS_percent"],
      SE      = se(m)["MIS_percent"],
      p       = pvalue(m)["MIS_percent"]
    )
  }, error=function(e) NULL)
}
df_irf <- do.call(rbind, lp_results)
cat("   Yerel Projeksiyon katsayıları:\n")
for (i in 1:nrow(df_irf)) {
  cat(sprintf("   h=%d: β = %.4f (SE=%.4f, p=%.3f)  %s\n",
              df_irf$Horizon[i], df_irf$Coef[i], df_irf$SE[i], df_irf$p[i],
              ifelse(df_irf$p[i]<0.01,"***",ifelse(df_irf$p[i]<0.05,"**",ifelse(df_irf$p[i]<0.10,"*","NS")))))
}

# Metinde: "h=1'de zirve, h=3-4'te pozitif"
if (nrow(df_irf) >= 5) {
  h1_coef <- df_irf$Coef[df_irf$Horizon==1]
  h3_coef <- df_irf$Coef[df_irf$Horizon==3]
  h4_coef <- df_irf$Coef[df_irf$Horizon==4]
  cat(sprintf("\n   KONTROL — h=1 zirve (en negatif): %s\n",
              ifelse(h1_coef == min(df_irf$Coef[df_irf$Horizon %in% 0:2]), "✓ UYUMLU", "⚠️ KONTROL ET")))
  cat(sprintf("   KONTROL — h=3 pozitif: %s\n", ifelse(h3_coef > 0, "✓ UYUMLU", "⚠️ NEGATİF — metinle çelişiyor")))
  cat(sprintf("   KONTROL — h=4 pozitif: %s\n", ifelse(h4_coef > 0, "✓ UYUMLU", "⚠️ NEGATİF — metinle çelişiyor")))
}

## ---- 11. MARSHALL-LERNER ----
cat("\n>> [11] Marshall-Lerner esneklik testi...\n")
wdi_ml_file <- "wdi_cache_ml.rds"
if (file.exists(wdi_ml_file)) {
  wdi_ml <- readRDS(wdi_ml_file)
} else {
  wdi_ml <- WDI(indicator=c(Exports_pct="NE.EXP.GNFS.ZS", Imports_pct="NE.IMP.GNFS.ZS"),
                country="all", start=1973, end=2021, extra=TRUE)
  saveRDS(wdi_ml, wdi_ml_file)
}
df_ml <- wdi_ml %>%
  filter(iso3c %in% em_iso) %>%
  rename_with(~gsub("\\.","_",.x)) %>%
  mutate(Year=as.integer(year)) %>%
  select(iso3c, Year, Exports_pct, Imports_pct) %>%
  inner_join(df_emerging_full, by=c("iso3c","Year")) %>%
  filter(!is.na(Exports_pct), !is.na(Imports_pct), Exports_pct>0, Imports_pct>0) %>%
  mutate(ln_X=log(Exports_pct), ln_M=log(Imports_pct))

model_ml_x <- tryCatch(feols(ln_X ~ l(MIS_percent,1) + log(GDP_per_Capita) + Inflation + Gov_Expenditure | iso3c+Year, data=df_ml, panel.id=~iso3c+Year, cluster=~iso3c), error=function(e) NULL)
model_ml_m <- tryCatch(feols(ln_M ~ l(MIS_percent,1) + log(GDP_per_Capita) + Inflation + Gov_Expenditure | iso3c+Year, data=df_ml, panel.id=~iso3c+Year, cluster=~iso3c), error=function(e) NULL)

beta_X <- if(!is.null(model_ml_x)) coef(model_ml_x)["l(MIS_percent, 1)"] else NA
beta_M <- if(!is.null(model_ml_m)) coef(model_ml_m)["l(MIS_percent, 1)"] else NA
pval_X <- if(!is.null(model_ml_x)) pvalue(model_ml_x)["l(MIS_percent, 1)"] else NA
pval_M <- if(!is.null(model_ml_m)) pvalue(model_ml_m)["l(MIS_percent, 1)"] else NA
eta_X  <- if(!is.na(beta_X)) round(-beta_X*100, 3) else NA
eta_M  <- if(!is.na(beta_M)) round( beta_M*100, 3) else NA
ml_sum <- if(!is.na(eta_X) && !is.na(eta_M)) round(eta_X + eta_M, 3) else NA
ml_met <- if(!is.na(ml_sum)) ml_sum > 1 else NA

cat(sprintf("   beta_X = %.4f (p=%.4f)  %s\n", beta_X, pval_X, ifelse(pval_X<0.10,"*","NS")))
cat(sprintf("   beta_M = %.4f (p=%.4f)  %s\n", beta_M, pval_M, ifelse(pval_M<0.10,"*","NS")))
cat(sprintf("   eta_X  = %.3f\n", eta_X))
cat(sprintf("   eta_M  = %.3f\n", eta_M))
cat(sprintf("   ml_sum = %.3f  → M-L Koşulu: %s\n", ml_sum, ifelse(isTRUE(ml_met), "✓ SAĞLANIYOR (>1)", "✗ SAĞLANMIYOR (<1)")))

# Metinde "eta_M teorik beklentinin aksine sıfırın altında" kontrol
if (!is.na(eta_M)) {
  cat(sprintf("   KONTROL — eta_M < 0 (yapısal ithalat katılığı): %s\n",
              ifelse(eta_M < 0, "✓ Metinle uyumlu", "⚠️ eta_M POZİTİF — metinle çelişiyor")))
}
# Metinde "ml_sum SAĞLANMIYOR" kontrol
if (!is.na(ml_met)) {
  cat(sprintf("   KONTROL — ml_sum < 1 (SAĞLANMIYOR): %s\n",
              ifelse(!ml_met, "✓ Metinle uyumlu", "⚠️ M-L SAĞLANIYOR — metin güncellenmeli!")))
}

## ---- 12. ÖZET RAPOR ----
cat("\n====================================================\n")
cat("ÖZET: KRİTİK METİN-TABLO UYUM KONTROLÜ\n")
cat("====================================================\n")
cat(sprintf("  yr_min = %d, yr_max = %d\n", yr_min, yr_max))
cat(sprintf("  n_country = %d (beklenen: 20)\n", n_country))
cat(sprintf("  mis_coef = %.4f  |  effect_10 = %.2f puan\n", mis_coef, effect_10))
cat(sprintf("  mis_pval = %.4f  %s\n", mis_pval,
            ifelse(mis_pval<0.01,"***",ifelse(mis_pval<0.05,"**",ifelse(mis_pval<0.10,"*","NS — ⚠️SORUN")))))
cat(sprintf("  poly_coef = %.4f  (beklenen: negatif)\n", ifelse(is.na(poly_coef), NA, poly_coef)))
cat(sprintf("  ect_coef = %.3f  (beklenen: negatif, |ECT|<1)\n", ifelse(is.na(ect_coef), NA, ect_coef)))
cat(sprintf("  ml_sum = %.3f  (beklenen: <1, SAĞLANMIYOR)\n", ifelse(is.na(ml_sum), NA, ml_sum)))
if (nrow(df_irf) >= 5) {
  cat(sprintf("  LP h=0: %.4f  h=1: %.4f  h=2: %.4f  h=3: %.4f  h=4: %.4f\n",
              df_irf$Coef[1], df_irf$Coef[2], df_irf$Coef[3], df_irf$Coef[4], df_irf$Coef[5]))
}
cat("\n  Tüm ⚠️ UYARI satırlarını yukarıda inceleyin.\n")
cat("====================================================\n")
