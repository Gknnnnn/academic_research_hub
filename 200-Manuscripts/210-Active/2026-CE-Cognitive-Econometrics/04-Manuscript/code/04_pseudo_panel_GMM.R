## ============================================================
## Script 04 — M2: Deaton Pseudo-Panel + Blundell-Bond System GMM
## Author : Dr. M. Gökhan Özdemir | 2026-04-07
## Input  : 400-Data/processed/CBI_micro.rds
## Output : 600-Results/CE_pilot/M2_sysGMM.rds
##          600-Results/CE_pilot/Table_M2.tex
## ============================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(plm); library(pdynmc)
  library(modelsummary); library(broom)
})

micro <- readRDS("400-Data/processed/CBI_micro.rds")

## ---- 1. Kohort tanımı: ülke × doğum on-yılı × cinsiyet ----
micro <- micro %>%
  mutate(
    birth_year   = wave_yr - age,
    birth_decade = floor(birth_year / 10) * 10,
    cohort_id    = paste(country, birth_decade, female, sep = "_")
  ) %>%
  filter(!is.na(birth_decade), birth_decade >= 1940, birth_decade <= 2000)

## ---- 2. Hücre ortalamaları (Deaton 1985 ağırlıklı) ----
cohort <- micro %>%
  group_by(cohort_id, country, birth_decade, female, wave_yr) %>%
  summarise(
    y_bar      = weighted.mean(CE_Action, weight, na.rm = TRUE),
    CBI_bar    = weighted.mean(CBI_pca_z, weight, na.rm = TRUE),
    income_bar = weighted.mean(hh_income_q, weight, na.rm = TRUE),
    educ_bar   = weighted.mean(educ_years,  weight, na.rm = TRUE),
    urban_bar  = weighted.mean(urban,       weight, na.rm = TRUE),
    n_cell     = n(),
    .groups    = "drop"
  ) %>%
  filter(n_cell >= 100)        # Verbeek (1992) eşiği

cat("Kohort hücre sayısı:", nrow(cohort), "\n")
cat("Ortalama hücre büyüklüğü:", round(mean(cohort$n_cell), 1), "\n")

pdat <- pdata.frame(cohort, index = c("cohort_id", "wave_yr"))

## ---- 3. M2a: pgmm — Blundell-Bond Sistem-GMM ----
m2a <- plm::pgmm(
  y_bar ~ lag(y_bar, 1) + CBI_bar + income_bar + educ_bar + urban_bar
        | lag(y_bar, 2:4) + lag(CBI_bar, 2:3),
  data        = pdat,
  effect      = "twoways",
  model       = "twosteps",
  transformation = "ld",        # SYSTEM GMM (level + diff)
  collapse    = TRUE             # Roodman (2009) instrument proliferation kontrolü
)

s2a <- summary(m2a, robust = TRUE)
print(s2a)

## ---- 4. Diagnostics: Hansen-J + Arellano-Bond AR(1)/AR(2) ----
hansen <- plm::sargan(m2a)
ar1 <- plm::mtest(m2a, order = 1)
ar2 <- plm::mtest(m2a, order = 2)

cat("Hansen J p-value :", signif(hansen$p.value, 3), "\n")
cat("AR(1) p-value    :", signif(ar1$p.value, 3), "\n")
cat("AR(2) p-value    :", signif(ar2$p.value, 3),
    " (>0.10 ⇒ no 2nd-order serial correlation, GMM valid)\n")

## ---- 5. M2b: pdynmc alternatif tahminci (cross-check) ----
##   Windmeijer (2005) küçük örnek düzeltmesi
m2b <- pdynmc::pdynmc(
  dat       = as.data.frame(cohort),
  varname.i = "cohort_id", varname.t = "wave_yr",
  use.mc.diff = TRUE, use.mc.lev = TRUE,
  include.y = TRUE, varname.y = "y_bar",
  fur.con = TRUE, fur.con.diff = TRUE, fur.con.lev = TRUE,
  varname.reg.fur = c("CBI_bar","income_bar","educ_bar","urban_bar"),
  lagTerms.y = 1, lagTerms.reg.fur = c(0,0,0,0),
  w.mat = "iid.err", std.err = "corrected",
  estimation = "twostep", opt.meth = "none"
)
summary(m2b)

## ---- 6. Kayıt + LaTeX tablo ----
saveRDS(list(m2a = m2a, m2b = m2b, hansen = hansen, ar1 = ar1, ar2 = ar2),
        "600-Results/CE_pilot/M2_sysGMM.rds")

modelsummary(
  list("System-GMM (plm)" = m2a),
  stars  = c('*' = .1, '**' = .05, '***' = .01),
  gof_omit = "AIC|BIC|Log",
  output = "600-Results/CE_pilot/Table_M2.tex",
  title  = "Table 2. Pseudo-panel system GMM (Blundell--Bond 1998)",
  notes  = paste0(
    "Hansen J p = ", signif(hansen$p.value, 3),
    "; AR(1) p = ", signif(ar1$p.value, 3),
    "; AR(2) p = ", signif(ar2$p.value, 3),
    ". Cohorts = country × birth-decade × gender; cells with n<100 dropped."
  )
)

cat("\n=== M2 complete ===\n")
