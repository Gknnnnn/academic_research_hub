## ============================================================
## Script 02c — M1: Mikro Birey-Düzeyi Analiz (DÜZELTME)
## Author : Dr. M. Gökhan Özdemir | 2026-04-09
## Input  : 400-Data/processed/CBI_micro.rds
## Output : 600-Results/CE_pilot_v3/micro_*
## Fark   : 02_micro_TWFE.R'ın hatalı sütun adları düzeltildi
##          (educ_years→edu_age, polit_left_right→polit_lr,
##           hh_income_q/employed/internet_use → mevcut değil, çıkarıldı)
## ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(modelsummary)
})
set.seed(20260409)

PROJ <- "."
PROC <- file.path(PROJ, "400-Data/processed")
RESU <- file.path(PROJ, "600-Results/CE_pilot_v3")
dir.create(RESU, showWarnings = FALSE, recursive = TRUE)

## ---- 1. Veri yükle ----
cat("CBI_micro yükleniyor...\n")
micro <- readRDS(file.path(PROC, "CBI_micro.rds"))
cat("N =", nrow(micro), " | ülke =", n_distinct(micro$country), "\n")
cat("Sütunlar:", paste(names(micro), collapse=", "), "\n\n")

## ---- 2. Temizleme ----
micro_clean <- micro |>
  filter(!is.na(CE_Action), !is.na(CBI_pca_z)) |>
  mutate(
    urban_bin = as.integer(urban >= 3),  # 3=büyük şehir
    edu_age_c = edu_age - mean(edu_age, na.rm = TRUE)  # merkez
  )
cat("Analiz N =", nrow(micro_clean), "\n\n")

## ---- 3. Tanımlayıcı istatistikler ----
cat("=== TABLO: Tanımlayıcı İstatistikler ===\n")
desc_vars <- micro_clean |>
  select(CE_Action, CBI_pca_z, CBI_eq_z, SQ, LA1, LA2, BC, PB, OP,
         age, edu_age, female, urban_bin, polit_lr)

desc_stats <- data.frame(
  Variable = names(desc_vars),
  N        = sapply(desc_vars, function(x) sum(!is.na(x))),
  Mean     = round(sapply(desc_vars, mean, na.rm=TRUE), 3),
  SD       = round(sapply(desc_vars, sd,   na.rm=TRUE), 3),
  Min      = round(sapply(desc_vars, min,  na.rm=TRUE), 3),
  Max      = round(sapply(desc_vars, max,  na.rm=TRUE), 3)
)
print(desc_stats)
write.csv(desc_stats, file.path(RESU, "micro_desc_stats.csv"), row.names=FALSE)

# CE_Action ülke dağılımı
ce_country <- micro_clean |>
  group_by(country) |>
  summarise(
    N = n(),
    CE_rate   = weighted.mean(CE_Action,  weight, na.rm=TRUE),
    CBI_mean  = weighted.mean(CBI_pca_z,  weight, na.rm=TRUE),
    .groups = "drop"
  ) |> arrange(desc(CE_rate))
write.csv(ce_country, file.path(RESU, "micro_country_CE_rates.csv"), row.names=FALSE)
cat("\nCE_Action ülke ortalamaları (ilk 5):\n")
print(head(ce_country, 5))

## ---- 4. M1a: LPM + Ülke FE ----
cat("\n=== M1a: LPM + Ülke FE ===\n")
m1a <- feols(
  CE_Action ~ CBI_pca_z + age + edu_age + female + urban_bin + polit_lr
            | country,
  data    = micro_clean,
  weights = ~weight,
  cluster = ~country,
  lean    = FALSE
)
summary(m1a)

## ---- 5. M1b: Logit + Ülke FE ----
cat("\n=== M1b: Logit + Ülke FE ===\n")
m1b <- feglm(
  CE_Action ~ CBI_pca_z + age + edu_age + female + urban_bin + polit_lr
            | country,
  data    = micro_clean,
  family  = binomial("logit"),
  weights = ~weight,
  cluster = ~country
)
summary(m1b)

## ---- 6. M1c: Eşit-ağırlıklı CBI ----
cat("\n=== M1c: LPM + CBI_eq_z ===\n")
m1c <- feols(
  CE_Action ~ CBI_eq_z + age + edu_age + female + urban_bin + polit_lr
            | country,
  data    = micro_clean,
  weights = ~weight,
  cluster = ~country
)
summary(m1c)

## ---- 7. M1d: Her CBI boyutu ayrı ayrı ----
cat("\n=== M1d: CBI Boyut Analizleri ===\n")
dims <- c("SQ","LA1","LA2","BC","PB","OP")
dim_results <- lapply(dims, function(d) {
  f <- as.formula(paste0("CE_Action ~ ", d, " + age + edu_age + female + urban_bin + polit_lr | country"))
  tryCatch(
    feols(f, data=micro_clean, weights=~weight, cluster=~country),
    error = function(e) NULL
  )
})
names(dim_results) <- dims
for(d in dims) {
  if (!is.null(dim_results[[d]])) {
    coef_d <- coef(dim_results[[d]])[d]
    se_d   <- se(dim_results[[d]])[d]
    p_d    <- pvalue(dim_results[[d]])[d]
    cat(sprintf("%-4s: β=%.4f  SE=%.4f  p=%.3f\n", d, coef_d, se_d, p_d))
  }
})

## ---- 8. Sonuçları tablola ----
cat("\n=== ÖZET TABLO (modelsummary) ===\n")
models_list <- list(
  "M1a: LPM (PCA)"  = m1a,
  "M1b: Logit (PCA)" = m1b,
  "M1c: LPM (Eq.Wt)" = m1c
)

tbl <- modelsummary(
  models_list,
  stars      = c('*'=.1, '**'=.05, '***'=.01),
  coef_rename = c(
    CBI_pca_z  = "CBI (PCA, std.)",
    CBI_eq_z   = "CBI (Eq.Wt., std.)",
    age        = "Age",
    edu_age    = "Education (leaving age)",
    female     = "Female (=1)",
    urban_bin  = "Urban (large city=1)",
    polit_lr   = "Political orientation (L→R)"
  ),
  gof_map    = c("nobs", "r.squared", "rmse"),
  gof_omit   = "AIC|BIC|Log|R2 Within|R2 Pseudo|Std|F",
  output     = "dataframe"
)
print(tbl)

modelsummary(
  models_list,
  stars      = c('*'=.1, '**'=.05, '***'=.01),
  coef_rename = c(
    CBI_pca_z  = "CBI (PCA, std.)",
    CBI_eq_z   = "CBI (Eq.Wt., std.)",
    age        = "Age",
    edu_age    = "Education (leaving age)",
    female     = "Female (=1)",
    urban_bin  = "Urban (large city=1)",
    polit_lr   = "Political orientation (L→R)"
  ),
  gof_map    = c("nobs","r.squared","rmse"),
  gof_omit   = "AIC|BIC|Log|R2 Within|R2 Pseudo|Std|F",
  title      = "Table M1. CBI and CE Behaviour — Individual-Level Estimates (EU-27, 2021)",
  notes      = "Cluster-robust standard errors at country level (N_c=27). Country fixed effects absorbed. CBI standardised (mean=0, SD=1). Dependent variable: CE_Action (binary, =1 if respondent reduces waste or avoids disposables). Data: Eurobarometer 95.1 (ZA7781, N≈26,600).",
  output     = file.path(RESU, "Table_M1_micro.tex")
)

## ---- 9. Boyut tablosu ----
dim_df <- lapply(dims, function(d) {
  if (is.null(dim_results[[d]])) return(NULL)
  data.frame(
    Dimension = d,
    beta      = round(coef(dim_results[[d]])[d], 4),
    se        = round(se(dim_results[[d]])[d], 4),
    p         = round(pvalue(dim_results[[d]])[d], 3),
    sig       = ifelse(pvalue(dim_results[[d]])[d]<.01,"***",
                ifelse(pvalue(dim_results[[d]])[d]<.05,"**",
                ifelse(pvalue(dim_results[[d]])[d]<.10,"*","")))
  )
}) |> bind_rows()
print(dim_df)
write.csv(dim_df, file.path(RESU, "micro_dim_results.csv"), row.names=FALSE)

## ---- 10. Anahtar sayılar ----
cat("\n=== MANUSCRIPT İÇİN ANAHTAR SAYILAR ===\n")
b_cbi  <- coef(m1a)["CBI_pca_z"]
se_cbi <- se(m1a)["CBI_pca_z"]
p_cbi  <- pvalue(m1a)["CBI_pca_z"]
cat(sprintf("M1a CBI_pca_z: β=%.4f  SE=%.4f  p=%.3f\n", b_cbi, se_cbi, p_cbi))
cat(sprintf("CE_Action oranı: %.1f%%\n", mean(micro_clean$CE_Action)*100))
cat(sprintf("N analiz: %d | ülke: %d | dalga: %s\n",
            nrow(micro_clean), n_distinct(micro_clean$country),
            paste(unique(micro_clean$wave_yr), collapse=",")))

cat("\n=== 02c tamamlandı ===\n")
cat("Çıktılar:", RESU, "\n")
