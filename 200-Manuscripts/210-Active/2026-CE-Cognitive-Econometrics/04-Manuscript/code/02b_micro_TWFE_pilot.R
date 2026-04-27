## ============================================================
## Script 02b — M1: Mikro TWFE (pilot, Bartik hariç)
## Author : Dr. M. Gökhan Özdemir | 2026-04-08
## Input  : 400-Data/processed/CBI_micro.rds
## Output : 600-Results/CE_pilot/M1_twfe_pilot.csv
## ============================================================
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(broom); library(modelsummary)
})

PROC <- "400-Data/processed"
RESU <- "600-Results/CE_pilot"
dir.create(RESU, showWarnings=FALSE, recursive=TRUE)

micro <- readRDS(file.path(PROC, "CBI_micro.rds"))
cat("N loaded:", nrow(micro), "| countries:", n_distinct(micro$country), "\n")

## ---- M1a: Linear Probability TWFE ----
## FE: country (tek dalga olduğu için wave_yr sabit, ülke FE yeterli)
m1a <- tryCatch(
  feols(CE_Action ~ CBI_pca_z + age + female + edu_age + urban + polit_lr
        | country,
        data    = micro |> filter(!is.na(CBI_pca_z)),
        weights = ~weight,
        cluster = ~country),
  error = function(e) { cat("M1a hata:", conditionMessage(e), "\n"); NULL }
)

## ---- M1b: Logit ----
m1b <- tryCatch(
  feglm(CE_Action ~ CBI_pca_z + age + female + edu_age + urban + polit_lr
        | country,
        data    = micro |> filter(!is.na(CBI_pca_z)),
        family  = binomial("logit"),
        weights = ~weight,
        cluster = ~country),
  error = function(e) { cat("M1b hata:", conditionMessage(e), "\n"); NULL }
)

## ---- M1c: Equal-weight CBI robustness ----
m1c <- tryCatch(
  feols(CE_Action ~ CBI_eq_z + age + female + edu_age + urban + polit_lr
        | country,
        data    = micro |> filter(!is.na(CBI_eq_z)),
        weights = ~weight,
        cluster = ~country),
  error = function(e) { cat("M1c hata:", conditionMessage(e), "\n"); NULL }
)

## ---- Sonuçlar ----
cat("\n=== M1a: Linear Probability TWFE ===\n")
if (!is.null(m1a)) {
  s <- summary(m1a)
  print(s)
  b1a <- tidy(m1a, conf.int=TRUE) |> mutate(model="M1a_LPM")
} else { b1a <- NULL }

cat("\n=== M1b: Logit TWFE ===\n")
if (!is.null(m1b)) {
  print(summary(m1b))
  b1b <- tidy(m1b, conf.int=TRUE) |> mutate(model="M1b_Logit")
} else { b1b <- NULL }

cat("\n=== M1c: Equal-weight CBI ===\n")
if (!is.null(m1c)) {
  print(summary(m1c))
  b1c <- tidy(m1c, conf.int=TRUE) |> mutate(model="M1c_EqualW")
} else { b1c <- NULL }

## ---- Export ----
results_df <- bind_rows(b1a, b1b, b1c)
write.csv(results_df, file.path(RESU, "M1_twfe_pilot.csv"), row.names=FALSE)
cat("\nKaydedildi:", file.path(RESU, "M1_twfe_pilot.csv"), "\n")

## ---- Özet Tablo ----
models_list <- Filter(Negate(is.null), list("LPM-TWFE"=m1a, "Logit"=m1b, "Equal-w CBI"=m1c))
if (length(models_list) > 0) {
  cat("\n=== ÖZET TABLO ===\n")
  ms <- modelsummary(models_list,
    output   = "data.frame",
    statistic = "({std.error})",
    stars    = c('*'=.1,'**'=.05,'***'=.01),
    coef_rename = c("CBI_pca_z"="CBI (PCA z-score)",
                    "CBI_eq_z" ="CBI (equal-weight z)",
                    "age"="Age", "female"="Female",
                    "edu_age"="Education (years)", "urban"="Urban (1-3)",
                    "polit_lr"="Left-Right (1-10)"))
  print(ms)
  write.csv(ms, file.path(RESU, "M1_summary_table.csv"), row.names=FALSE)
}
cat("\n=== M1 PILOT TAMAMLANDI ===\n")
