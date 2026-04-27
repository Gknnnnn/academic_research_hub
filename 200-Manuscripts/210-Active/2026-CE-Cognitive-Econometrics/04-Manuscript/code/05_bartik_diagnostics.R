## ============================================================
## Script 05 — M5: Bartik Shift-Share IV + Rotemberg Diagnostics
## Author : Dr. M. Gökhan Özdemir | 2026-04-07
## Reference: Goldsmith-Pinkham, Sorkin & Swift (2020, AER)
## Input  : 400-Data/processed/CBI_micro.rds
##          400-Data/processed/green_media_index.csv  (national, t)
## Output : 600-Results/CE_pilot/M5_bartik.rds
##          600-Results/CE_pilot/Table_M5_Rotemberg.tex
## ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(fixest); library(ShiftShareSE)
  library(bartik.weight); library(modelsummary)
})

micro <- readRDS("400-Data/processed/CBI_micro.rds")
gmi   <- read.csv("400-Data/processed/green_media_index.csv")  # country, year, gmi

## ---- 1. Sektör payları (S=8 NACE düzey-1) — başlangıç yılı 2010 ----
##   Eurostat lfsa_egan2 (Employment by NACE Rev. 2) ile birleştirilmiş
shares <- read.csv("400-Data/processed/eurostat_emp_shares_2010.csv")
##   shares: country, sector, eta_c_s_2010   (∑_s eta = 1)

## ---- 2. Ulusal-mean sektör büyüme oranları (shifts g_{s,t}) ----
shifts <- read.csv("400-Data/processed/sector_green_growth.csv")
##   shifts: sector, year, g_s_t   (national average; leave-one-out optional)

## ---- 3. Bartik aleti Z_{c,t} = Σ_s eta_{c,s,2010} * g_{s,t} ----
bartik <- shares %>%
  inner_join(shifts, by = "sector", relationship = "many-to-many") %>%
  group_by(country, year) %>%
  summarise(bartik_z = sum(eta_c_s_2010 * g_s_t, na.rm = TRUE),
            .groups = "drop")

micro <- micro %>%
  left_join(bartik, by = c("country", "wave_yr" = "year"))

## ---- 4. 2SLS (M5 main): CBI ⟵ bartik_z ----
m5 <- feols(
  CE_Action ~ age + female + log1p(hh_income_q) + urban + employed
            | country^wave_yr
            | CBI_pca_z ~ bartik_z,
  data    = micro,
  weights = ~weight,
  cluster = ~country
)

## First-stage F statistic (Stock-Yogo eşiği = 10)
fs_F <- fitstat(m5, "ivf1")
cat("First-stage F :", round(fs_F[[1]]$stat, 2), "\n")

## ---- 5. Rotemberg (1983) Ağırlıkları (G-P-S-S 2020 §3.2) ----
##   α_{c,s} = eta_{c,s,2010} * g_{s,t} * Cov-pay
rot <- bartik.weight::bw(
  zeta   = shares,                # eta_{c,s,t0}
  Bartik = bartik,                # bartik instrument df
  weight = "country",             # cluster level
  X      = micro %>% select(country, wave_yr, CBI_pca_z, CE_Action)
)

## Top-5 sectors driving identification (positive Rotemberg weight)
top5 <- rot %>% arrange(desc(alpha)) %>% head(5)
print(top5)

## ---- 6. Pre-trend falsification (placebo) ----
##   2010-2019 dönemi (CE Action Plan öncesi) için Z_{c,t} → ΔCMU_{c,t}
##   Anlamlı olmamalı.
placebo <- read.csv("400-Data/processed/eurostat_macro_pre2020.csv") %>%
  left_join(bartik, by = c("country", "year"))

m5_placebo <- feols(
  d_lnCMU ~ bartik_z | country + year,
  data    = placebo,
  cluster = ~country
)
print(summary(m5_placebo))

## ---- 7. AKM-style cluster-robust SE (G-P-S-S 2020) ----
m5_akm <- ShiftShareSE::ivreg_ss(
  formula     = CE_Action ~ CBI_pca_z + age + female + log1p(hh_income_q),
  X           = "CBI_pca_z",
  data        = micro,
  W           = shares %>% pivot_wider(names_from = sector, values_from = eta_c_s_2010),
  method      = "akm0",
  beta0       = 0
)
print(m5_akm)

## ---- 8. Kayıt + LaTeX tablolar ----
saveRDS(list(m5 = m5, fs_F = fs_F, rotemberg = rot, top5 = top5,
             placebo = m5_placebo, akm = m5_akm),
        "600-Results/CE_pilot/M5_bartik.rds")

modelsummary(
  list("Bartik 2SLS" = m5, "Placebo (pre-2020)" = m5_placebo),
  stars  = c('*' = .1, '**' = .05, '***' = .01),
  gof_omit = "AIC|BIC|Log|R2 Within",
  output = "600-Results/CE_pilot/Table_M5.tex",
  title  = "Table 5. Bartik shift--share IV and pre-trend falsification",
  notes  = paste0(
    "First-stage F = ", round(fs_F[[1]]$stat, 2),
    " (Stock-Yogo 10\\% threshold = 16.4 for single endogenous regressor). ",
    "Placebo specification uses 2010--2019 (pre-CEAP 2020). ",
    "Rotemberg top-5 sectors reported separately."
  )
)

# Top-5 Rotemberg ağırlıkları için ayrı tablo
modelsummary::datasummary_df(
  top5,
  output = "600-Results/CE_pilot/Table_M5_Rotemberg.tex",
  title  = "Table 6. Top-5 sectors driving Bartik identification (Rotemberg weights)"
)

cat("\n=== M5 Bartik diagnostics complete ===\n")
