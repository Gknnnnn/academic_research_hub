## ============================================================
## Script 02 — M1: Mikro Birey-Düzeyi TWFE + Bartik IV
## Author : Dr. M. Gökhan Özdemir | 2026-04-07
## Input  : 400-Data/processed/CBI_micro.rds
## Output : 600-Results/CE_pilot/M1_twfe.rds, M1_iv.rds
## ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(modelsummary); library(broom)
})

micro <- readRDS("400-Data/processed/CBI_micro.rds")

## ---- 1. Bağımlı değişken: ≥1 CE davranışı (ikili) ----
##   onarım, ikinci-el alım, kiralama, geri-dönüşüm
##   (her wave için q-kodlar codebook'tan çekilecek; placeholder)
micro <- micro %>%
  mutate(
    CE_Action = as.integer(ce_repair == 1 | ce_secondhand == 1 |
                           ce_rent    == 1 | ce_recycle    == 1),
    age_grp   = cut(age, breaks = c(15,25,35,45,55,65,99), right = FALSE),
    cohort    = paste(country, age_grp, sep = "_")
  )

## ---- 2. M1a: Linear Probability TWFE ----
m1a <- feols(
  CE_Action ~ CBI_pca_z + age + female + educ_years + log1p(hh_income_q) +
              urban + employed + polit_left_right + internet_use
            | country^wave_yr,
  data    = micro,
  weights = ~weight,
  cluster = ~country
)

## ---- 2b. M1b: Logit + cluster-robust SE ----
m1b <- feglm(
  CE_Action ~ CBI_pca_z + age + female + educ_years + log1p(hh_income_q) +
              urban + employed + polit_left_right + internet_use
            | country^wave_yr,
  data    = micro,
  family  = binomial("logit"),
  weights = ~weight,
  cluster = ~country
)

## ---- 3. Bartik shift-share IV ----
##   Z = (başlangıç-yılı eğitim payı) × (ulusal yeşil-medya yoğunluğu büyümesi)
##   Burada placeholder: green_media_idx zaman-değişen ulusal endeks
micro <- micro %>%
  group_by(country) %>%
  mutate(
    educ_share_2021 = mean(educ_years[wave_yr == 2021], na.rm = TRUE),
    bartik_z        = educ_share_2021 * green_media_idx
  ) %>% ungroup()

m1_iv <- feols(
  CE_Action ~ age + female + log1p(hh_income_q) + urban + employed
            | country^wave_yr
            | CBI_pca_z ~ bartik_z,
  data    = micro,
  weights = ~weight,
  cluster = ~country
)

## ---- 4. Kohort robustness ----
m1c <- feols(
  CE_Action ~ CBI_pca_z + age + female + educ_years + hh_income_q
            | cohort + wave_yr,
  data    = micro,
  weights = ~weight,
  cluster = ~cohort
)

## ---- 5. Kayıt + tablolaştırma ----
saveRDS(list(m1a = m1a, m1b = m1b, m1c = m1c, m1_iv = m1_iv),
        "600-Results/CE_pilot/M1_models.rds")

modelsummary(
  list("LPM-TWFE" = m1a, "Logit" = m1b, "Cohort FE" = m1c, "Bartik-IV" = m1_iv),
  stars  = c('*' = .1, '**' = .05, '***' = .01),
  gof_omit = "AIC|BIC|Log|R2 Within|R2 Pseudo|Std",
  output = "600-Results/CE_pilot/Table_M1.tex",
  title  = "Table 1. CBI ve CE davranışı — birey düzeyi tahminler",
  notes  = "Cluster-robust standart hatalar ülke düzeyinde. CBI standardize."
)

cat("\n=== M1 complete ===\n")
