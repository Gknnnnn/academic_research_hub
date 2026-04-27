## ============================================================
## Script 05b — M5: Bartik Shift-Share IV (Working version)
## Author  : Dr. M. Gökhan Özdemir | 2026-04-25
## Note    : Uses bartik_green_emp.csv (pre-computed cross-section bartik_z)
##           Single wave (2021); GR+MT excluded (bartik missing)
##           bartik.weight not installed → Rotemberg skipped
##           pre-2020 placebo data not available → placebo skipped
## Reference: Goldsmith-Pinkham, Sorkin & Swift (2020, AER)
## Input   : processed/CBI_micro.rds
##           processed/bartik_green_emp.csv
## Output  : 600-Results/CE_pilot/M5_bartik.rds
##           600-Results/CE_pilot/Table_M5.tex
##           600-Results/CE_pilot/Table_M5.docx
## ============================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
  library(modelsummary)
})

## ---- Paths --------------------------------------------------
BASE <- file.path(
  "/Users/mehmetgokhanozdemir/Library/CloudStorage",
  "OneDrive-Ki\u015fisel/Akademik_Arastirma/200-Manuscripts/210-Active",
  "2026-CE-Cognitive-Econometrics"
)
PROC  <- file.path(BASE, "02-Methods/400-Data/processed")
ROUT  <- file.path(BASE, "03-Results/600-Results/CE_pilot")

## ---- 1. Load data -------------------------------------------
micro   <- readRDS(file.path(PROC, "CBI_micro.rds"))
bartik  <- read.csv(file.path(PROC, "bartik_green_emp.csv"),
                    stringsAsFactors = FALSE)

cat("Micro: N =", nrow(micro), "countries =", length(unique(micro$country)),
    "wave(s) =", paste(unique(micro$wave_yr), collapse = ", "), "\n")
cat("Bartik: N_country =", nrow(bartik),
    "| NA bartik_z:", sum(is.na(bartik$bartik_z)), "\n")

## ---- 2. Merge: drop GR (not in bartik), MT (NA bartik_z) ----
micro <- micro %>%
  left_join(bartik %>% select(country, eta_D, eta_E, bartik_z),
            by = "country") %>%
  filter(!is.na(bartik_z))

cat("Analysis sample after merge: N =", nrow(micro),
    "countries =", length(unique(micro$country)), "\n")
excluded <- setdiff(unique(read.csv(file.path(PROC, "CBI_micro.csv"))$country),
                    unique(micro$country))
cat("Excluded countries:", paste(excluded, collapse = ", "), "\n")

## ---- 3. Drop incomplete observations ------------------------
micro_m5 <- micro %>%
  filter(!is.na(CBI_pca_z), !is.na(CE_Action),
         !is.na(age), !is.na(female), !is.na(urban))

cat("Complete-case M5 sample: N =", nrow(micro_m5), "\n")

## NOTE: bartik_z is country-level (single cross-section 2021).
## Country FE would absorb the instrument entirely.
## Correct specification: individual-level micro with individual controls,
## cluster SE by country. Country-level between-estimator provided separately.

## ---- 4. M5a — OLS baseline (country FE + individual controls) ----
##   This absorbs country-level variation; provides within-country benchmark.
m5_ols <- feols(
  CE_Action ~ CBI_pca_z + age + female + urban + edu_age + polit_lr
            | country,
  data    = micro_m5,
  weights = ~weight,
  cluster = ~country
)

## ---- 4b. OLS without country FE (between + within variation) ---
m5_ols_bc <- feols(
  CE_Action ~ CBI_pca_z + age + female + urban + edu_age + polit_lr,
  data    = micro_m5,
  weights = ~weight,
  cluster = ~country
)

## ---- 5. First stage: CBI_pca_z ~ bartik_z (no country FE) -----
##   bartik_z is country-level; country FE would be collinear.
m5_fs <- feols(
  CBI_pca_z ~ bartik_z + age + female + urban + edu_age + polit_lr,
  data    = micro_m5,
  weights = ~weight,
  cluster = ~country
)

fs_coef  <- coef(m5_fs)["bartik_z"]
fs_se    <- se(m5_fs)["bartik_z"]
fs_t     <- fs_coef / fs_se
fs_F     <- round(fs_t^2, 2)
cat("\nFirst stage — bartik_z coefficient:", round(fs_coef, 4),
    " SE:", round(fs_se, 4), " F:", round(fs_F, 2), "\n")

if (!is.na(fs_F) && fs_F < 10) {
  warning("First-stage F < 10 (Stock-Yogo 10% threshold = 16.4) — weak instrument.")
} else if (!is.na(fs_F) && fs_F < 16.4) {
  cat("NOTE: F >= 10 but < 16.4 (Stock-Yogo 10% critical value) — borderline.\n")
} else if (!is.na(fs_F)) {
  cat("First stage: STRONG instrument (F >= 16.4).\n")
}

## ---- 6. 2SLS: CE_Action ← CBI_pca_z ← bartik_z (no country FE) --
m5_iv <- feols(
  CE_Action ~ age + female + urban + edu_age + polit_lr
            | CBI_pca_z ~ bartik_z,
  data    = micro_m5,
  weights = ~weight,
  cluster = ~country
)

cat("\n2SLS result:\n")
print(summary(m5_iv))

## ---- 6b. LIML robustness (Anderson-Rubin robust to weak instruments) ------
## LIML is recommended when first-stage F < 16.4 (Stock-Yogo threshold).
## fixest supports LIML via estimator = "liml"
m5_liml <- tryCatch(
  feols(
    CE_Action ~ age + female + urban + edu_age + polit_lr
              | CBI_pca_z ~ bartik_z,
    data       = micro_m5,
    weights    = ~weight,
    cluster    = ~country,
    estimator  = "liml"
  ),
  error = function(e) {
    cat("fixest LIML failed:", e$message, "— trying ivreg LIML\n")
    if (requireNamespace("ivreg", quietly = TRUE)) {
      ivreg::ivreg(
        CE_Action ~ CBI_pca_z + age + female + urban + edu_age + polit_lr
                  | bartik_z + age + female + urban + edu_age + polit_lr,
        data   = micro_m5,
        weights = micro_m5$weight,
        method = "LIML"
      )
    } else NULL
  }
)

if (!is.null(m5_liml)) {
  cat("\nLIML robustness (weak-instrument correction):\n")
  liml_coef <- tryCatch(coef(m5_liml)[["fit_CBI_pca_z"]], error = function(e) coef(m5_liml)[["CBI_pca_z"]])
  liml_p    <- tryCatch(pvalue(m5_liml)[["fit_CBI_pca_z"]], error = function(e) NA)
  cat("  LIML CBI coef:", round(liml_coef, 4), "p =", round(liml_p, 3), "\n")
  cat("  2SLS CBI coef:", round(tryCatch(coef(m5_iv)[["fit_CBI_pca_z"]], error = function(e) NA), 4), "\n")
  cat("  Sign consistency 2SLS vs LIML:", sign(liml_coef) == sign(tryCatch(coef(m5_iv)[["fit_CBI_pca_z"]], error = function(e) NA)), "\n")
} else {
  cat("LIML not available — install fixest >= 0.12 or ivreg package\n")
  m5_liml <- NULL
}

## ---- 7. Reduced form: CE_Action ~ bartik_z (intent-to-treat) --
m5_rf <- feols(
  CE_Action ~ bartik_z + age + female + urban + edu_age + polit_lr,
  data    = micro_m5,
  weights = ~weight,
  cluster = ~country
)

## ---- 7b. Country-level aggregated IV (between estimator, N=25) --
micro_c <- micro_m5 %>%
  group_by(country, bartik_z) %>%
  summarise(
    CBI_mean  = weighted.mean(CBI_pca_z, weight, na.rm = TRUE),
    CE_mean   = weighted.mean(CE_Action,  weight, na.rm = TRUE),
    age_mean  = weighted.mean(age,        weight, na.rm = TRUE),
    female_m  = weighted.mean(female,     weight, na.rm = TRUE),
    urban_m   = weighted.mean(urban,      weight, na.rm = TRUE),
    .groups   = "drop"
  )

m5_c_ols <- feols(CE_mean ~ CBI_mean + age_mean + female_m + urban_m,
                  data = micro_c)
m5_c_iv  <- feols(CE_mean ~ age_mean + female_m + urban_m | CBI_mean ~ bartik_z,
                  data = micro_c)
cat("\nCountry-level (between) 2SLS — N countries =", nrow(micro_c), "\n")
print(summary(m5_c_iv))

## ---- 8. Instrument validity: correlation check ---------------
##   bartik_z should correlate with CBI_pca_z but NOT directly with
##   pre-determined outcomes. Check via country-level means.
country_means <- micro_m5 %>%
  group_by(country) %>%
  summarise(
    CBI_mean    = weighted.mean(CBI_pca_z, weight, na.rm = TRUE),
    CE_mean     = weighted.mean(CE_Action,  weight, na.rm = TRUE),
    bartik_z    = first(bartik_z),
    .groups = "drop"
  )

r_z_cbi <- cor(country_means$bartik_z, country_means$CBI_mean, use = "complete.obs")
r_z_ce  <- cor(country_means$bartik_z, country_means$CE_mean,  use = "complete.obs")
cat("\nCountry-level correlations:\n")
cat("  r(bartik_z, CBI_pca_z) =", round(r_z_cbi, 3), "\n")
cat("  r(bartik_z, CE_Action) =", round(r_z_ce,  3), "\n")

## ---- 9. Save results -----------------------------------------
dir.create(ROUT, recursive = TRUE, showWarnings = FALSE)

results_m5 <- list(
  ols_with_FE    = m5_ols,
  ols_no_FE      = m5_ols_bc,
  first_stage    = m5_fs,
  iv_2sls        = m5_iv,
  iv_liml        = m5_liml,
  reduced_form   = m5_rf,
  country_ols    = m5_c_ols,
  country_iv     = m5_c_iv,
  fs_F           = fs_F,
  n_obs          = nrow(micro_m5),
  n_countries    = length(unique(micro_m5$country)),
  excluded       = excluded,
  country_means  = micro_c,
  country_corr   = list(r_z_cbi = r_z_cbi, r_z_ce = r_z_ce),
  note           = paste0(
    "Single wave 2021; N=", length(unique(micro_m5$country)),
    " EU countries (GR+MT excluded: bartik_z unavailable). ",
    "bartik_z = Bartik shift-share instrument (green employment, Eurostat). ",
    "Controls: age, female, urban, edu_age, polit_lr. ",
    "IV estimated without country FE (country FE absorbs country-level instrument). ",
    "Country-level between-estimator (N=25) provided separately."
  )
)

saveRDS(results_m5, file.path(ROUT, "M5_bartik.rds"))
cat("\nSaved:", file.path(ROUT, "M5_bartik.rds"), "\n")

## ---- 10. Output tables --------------------------------------
## fs_note for table footer
fs_note <- paste0(
  "First-stage F = ", round(fs_F, 2),
  " (Stock-Yogo 10\\% size distortion critical value = 16.4). ",
  "Bartik shift-share instrument: green employment exposure (Eurostat, 2010 baseline shares). ",
  "Country FE throughout. Clustered SE by country (N = ",
  length(unique(micro_m5$country)), ")."
)

## LaTeX table — four-column: OLS|FE, First Stage, 2SLS, Country IV
modelsummary(
  list(
    "OLS (w/ country FE)" = m5_ols,
    "First Stage"         = m5_fs,
    "2SLS (micro)"        = m5_iv,
    "2SLS (country-level)"= m5_c_iv
  ),
  coef_rename = c(
    "CBI_pca_z"     = "CBI Index (std)",
    "fit_CBI_pca_z" = "CBI Index (std, IV)",
    "CBI_mean"      = "CBI Index (country mean)",
    "fit_CBI_mean"  = "CBI Index (country mean, IV)",
    "bartik_z"      = "Bartik Z",
    "age"           = "Age",
    "female"        = "Female",
    "urban"         = "Urban",
    "edu_age"       = "Education age",
    "polit_lr"      = "Political orientation (L-R)",
    "age_mean"      = "Age (country mean)",
    "female_m"      = "Female (country mean)",
    "urban_m"       = "Urban (country mean)"
  ),
  stars    = c('*' = .1, '**' = .05, '***' = .01),
  gof_omit = "AIC|BIC|Log|RMSE",
  title    = paste0(
    "Table M5. Bartik Shift-Share IV Estimates: ",
    "Effect of Cognitive Barriers on CE Adoption (EU-",
    length(unique(micro_m5$country)), ", 2021)"
  ),
  notes    = fs_note,
  output   = file.path(ROUT, "Table_M5.tex")
)
cat("Saved Table_M5.tex\n")

## Word/docx table
modelsummary(
  list(
    "OLS (w/ country FE)" = m5_ols,
    "First Stage"         = m5_fs,
    "2SLS (micro)"        = m5_iv,
    "2SLS (country-level)"= m5_c_iv
  ),
  coef_rename = c(
    "CBI_pca_z"     = "CBI Index (std)",
    "fit_CBI_pca_z" = "CBI Index (std, IV)",
    "CBI_mean"      = "CBI Index (country mean)",
    "fit_CBI_mean"  = "CBI Index (country mean, IV)",
    "bartik_z"      = "Bartik Z",
    "age"           = "Age",
    "female"        = "Female",
    "urban"         = "Urban",
    "edu_age"       = "Education age",
    "polit_lr"      = "Political orientation (L-R)",
    "age_mean"      = "Age (country mean)",
    "female_m"      = "Female (country mean)",
    "urban_m"       = "Urban (country mean)"
  ),
  stars    = c('*' = .1, '**' = .05, '***' = .01),
  gof_omit = "AIC|BIC|Log|RMSE",
  title    = paste0(
    "Table M5. Bartik Shift-Share IV Estimates: ",
    "Effect of Cognitive Barriers on CE Adoption (EU-",
    length(unique(micro_m5$country)), ", 2021)"
  ),
  notes    = paste0(
    "First-stage F = ", round(fs_F, 2),
    " (Stock-Yogo 10% size distortion critical value = 16.4). ",
    "Bartik shift-share instrument: green employment exposure (Eurostat, 2010 baseline). ",
    "Columns 1 and 2: individual-level; SE clustered by country. ",
    "Column 3: 2SLS without country FE (country FE absorbs country-level instrument). ",
    "Column 4: country-level aggregated IV (N = ", nrow(micro_c), " countries)."
  ),
  output   = file.path(ROUT, "Table_M5.docx")
)
cat("Saved Table_M5.docx\n")

## Save country-level correlations CSV for DAG figure cross-check
write.csv(country_means,
          file.path(ROUT, "M5_country_bartik.csv"), row.names = FALSE)
cat("Saved M5_country_bartik.csv\n")

cat("\n=== M5 Bartik IV complete ===\n")
cat("Key results:\n")
cat("  OLS (FE) CBI coef    :", round(coef(m5_ols)["CBI_pca_z"], 4),
    "p =", round(pvalue(m5_ols)["CBI_pca_z"], 3), "\n")
iv_cbi_coef <- tryCatch(coef(m5_iv)[["fit_CBI_pca_z"]], error = function(e) NA)
iv_cbi_p    <- tryCatch(pvalue(m5_iv)[["fit_CBI_pca_z"]], error = function(e) NA)
cat("  2SLS (micro) CBI coef:", round(iv_cbi_coef, 4),
    "p =", round(iv_cbi_p, 3), "\n")
civ_coef    <- tryCatch(coef(m5_c_iv)[["fit_CBI_mean"]], error = function(e) NA)
civ_p       <- tryCatch(pvalue(m5_c_iv)[["fit_CBI_mean"]], error = function(e) NA)
cat("  2SLS (country) CBI   :", round(civ_coef, 4),
    "p =", round(civ_p, 3), "\n")
cat("  First-stage F        :", round(fs_F, 2), "\n")
cat("  N obs (micro)        :", nrow(micro_m5), "\n")
cat("  N countries          :", length(unique(micro_m5$country)), "\n")
