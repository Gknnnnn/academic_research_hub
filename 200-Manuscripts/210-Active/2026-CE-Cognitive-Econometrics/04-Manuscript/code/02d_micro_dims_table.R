## Script 02d -- CBI dimension analysis + summary table
## Run from project root
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(modelsummary)
})

PROC <- "400-Data/processed"
RESU <- "600-Results/CE_pilot_v3"

micro <- readRDS(file.path(PROC, "CBI_micro.rds"))
micro_clean <- micro |>
  filter(!is.na(CE_Action), !is.na(CBI_pca_z)) |>
  mutate(urban_bin = as.integer(urban >= 3))

## Main models (re-run for table)
m1a <- feols(CE_Action ~ CBI_pca_z + age + edu_age + female + urban_bin + polit_lr | country,
             data=micro_clean, weights=~weight, cluster=~country)
m1b <- feglm(CE_Action ~ CBI_pca_z + age + edu_age + female + urban_bin + polit_lr | country,
             data=micro_clean, family=binomial("logit"), weights=~weight, cluster=~country)
m1c <- feols(CE_Action ~ CBI_eq_z  + age + edu_age + female + urban_bin + polit_lr | country,
             data=micro_clean, weights=~weight, cluster=~country)

## Dimension-by-dimension
dims <- c("SQ","LA1","LA2","BC","PB","OP")
dim_rows <- list()
for (d in dims) {
  f <- reformulate(c(d, "age", "edu_age", "female", "urban_bin", "polit_lr"),
                   response = "CE_Action", intercept = TRUE)
  fit <- tryCatch(
    feols(f, data=micro_clean, weights=~weight, cluster=~country,
          fixef = "country"),
    error = function(e) NULL
  )
  if (!is.null(fit)) {
    b <- coef(fit)[d]
    s <- se(fit)[d]
    p <- pvalue(fit)[d]
    stars <- ifelse(p<.01,"***", ifelse(p<.05,"**", ifelse(p<.10,"*","")))
    dim_rows[[d]] <- data.frame(Dimension=d, beta=round(b,4),
                                 se=round(s,4), p=round(p,3), sig=stars)
    cat(sprintf("%-4s: beta=%7.4f  SE=%.4f  p=%.3f %s\n", d, b, s, p, stars))
  }
}
dim_df <- do.call(rbind, dim_rows)
write.csv(dim_df, file.path(RESU, "micro_dim_results.csv"), row.names=FALSE)

## LaTeX table
modelsummary(
  list("LPM-PCA"=m1a, "Logit-PCA"=m1b, "LPM-EqWt"=m1c),
  stars      = c("*"=.1, "**"=.05, "***"=.01),
  coef_rename = c(
    CBI_pca_z = "CBI (PCA, std.)", CBI_eq_z = "CBI (Eq.Wt., std.)",
    age = "Age", edu_age = "Education (school-leaving age)",
    female = "Female", urban_bin = "Urban (large city)",
    polit_lr = "Political orientation (L to R)"
  ),
  gof_map  = c("nobs","r.squared","rmse"),
  gof_omit = "AIC|BIC|Log|Within|Pseudo|Std|F",
  title    = "Table M1. CBI and CE Behaviour: Individual-Level Estimates (EU-27, 2021)",
  notes    = paste("Cluster-robust SE at country level (N_c=27). Country FE absorbed.",
                   "CBI standardised. Dep. var: CE_Action (binary).",
                   "Data: Eurobarometer 95.1 ZA7781 (N=19,843 complete cases)."),
  output   = file.path(RESU, "Table_M1_micro.tex")
)

## Key numbers for manuscript
b_cbi <- coef(m1a)["CBI_pca_z"]
p_cbi <- pvalue(m1a)["CBI_pca_z"]
b_log <- coef(m1b)["CBI_pca_z"]
cat("\n=== KEY NUMBERS FOR MANUSCRIPT ===\n")
cat(sprintf("CE_Action rate: %.1f%%\n", mean(micro_clean$CE_Action)*100))
cat(sprintf("N complete: %d | countries: %d\n", nrow(micro_clean[!is.na(micro_clean$edu_age)&!is.na(micro_clean$polit_lr),]), n_distinct(micro_clean$country)))
cat(sprintf("M1a CBI_pca_z: beta=%.4f  p=%.4f\n", b_cbi, p_cbi))
cat(sprintf("M1b CBI_pca_z (logit): beta=%.4f\n", b_log))
cat("\nDimension results:\n")
print(dim_df)
cat("\n=== 02d complete ===\n")
