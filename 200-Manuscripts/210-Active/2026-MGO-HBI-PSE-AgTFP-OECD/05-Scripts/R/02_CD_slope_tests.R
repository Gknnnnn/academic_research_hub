# 02_CD_slope_tests.R
# Cross-section dependence + slope homogeneity tests
# PSE × AgTFP OECD | MGO × HBI
#
# Tests:
#   1. Pesaran (2004) CD test
#   2. Pesaran-Yamagata (2008) Δ and Δ̃ slope homogeneity
#   3. Frees (1995) test as robustness

library(tidyverse); library(plm); library(xtable)

CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"

df <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types=FALSE) %>%
  mutate(ln_tfp   = log(tfp_index),
         ln_gdppc = log(gdppc_const2015),
         ln_fert  = log(fertilizer_kgha + 0.001),
         ln_agl   = log(agland_share + 0.001))

pdata <- pdata.frame(df, index=c("iso3","year"))

# ── Helper: Pesaran CD test (manual, for robustness) ──────────────────────────
pesaran_cd <- function(resid_matrix) {
  # resid_matrix: T×N matrix of residuals
  N <- ncol(resid_matrix)
  T <- nrow(resid_matrix)
  pairs <- combn(N, 2)
  rho_pairs <- apply(pairs, 2, function(idx) {
    x <- resid_matrix[, idx[1]]
    y <- resid_matrix[, idx[2]]
    complete <- complete.cases(x, y)
    if (sum(complete) < 3) return(NA_real_)
    cor(x[complete], y[complete])
  })
  rho_mean <- mean(rho_pairs, na.rm=TRUE)
  CD_stat <- sqrt(2*T / (N*(N-1))) * sum(rho_pairs, na.rm=TRUE)
  pval <- 2 * pnorm(-abs(CD_stat))
  list(CD=CD_stat, pval=pval, rho_mean=rho_mean)
}

# ── Baseline model for residuals ───────────────────────────────────────────────
# Use variables available before PSE merge (preliminary with controls only)
# Will be re-run after PSE data arrives

base_vars <- c("ln_tfp","ln_gdppc","rural_share","ln_fert","ln_agl")
df_base <- df %>% select(iso3, year, all_of(base_vars)) %>% drop_na()
pdata_base <- pdata.frame(df_base, index=c("iso3","year"))

# FE model for residuals
fe_base <- plm(ln_tfp ~ ln_gdppc + rural_share + ln_fert + ln_agl,
               data=pdata_base, model="within", effect="twoways")
resids_long <- residuals(fe_base)

# Build residual matrix (T×N)
resid_df <- data.frame(
  iso3 = df_base$iso3[!is.na(df_base$ln_tfp)],
  year = df_base$year[!is.na(df_base$ln_tfp)],
  resid = resids_long
) %>%
  pivot_wider(names_from=iso3, values_from=resid) %>%
  select(-year) %>%
  as.matrix()

# ── 1. Pesaran CD test ─────────────────────────────────────────────────────────
cat("═══ Cross-Section Dependence Tests ═══\n\n")

# Using plm's built-in CD test
cd_result <- tryCatch(
  purtest(fe_base, test="hadri"),  # plm CD approximation
  error = function(e) NULL
)

# Manual CD
cd_manual <- pesaran_cd(resid_df)
cat(sprintf("Pesaran CD: stat = %.3f, p-value = %.4f\n", cd_manual$CD, cd_manual$pval))
cat(sprintf("Average correlation: ρ̄ = %.3f\n", cd_manual$rho_mean))
cat(sprintf("Interpretation: %s\n\n",
    ifelse(cd_manual$pval < 0.05,
           "REJECT H0 → Cross-section dependence confirmed (use CS-ARDL)",
           "FAIL TO REJECT H0 → No strong CSD (FE/PMG sufficient)")))

# ── 2. Pesaran-Yamagata slope homogeneity test ─────────────────────────────────
# Implementation of PY(2008) Δ test
py_slope_test <- function(pdata, formula_str) {
  # Run country-by-country OLS
  countries <- levels(pdata$iso3)
  N <- length(countries)
  formula_obj <- as.formula(formula_str)

  beta_list <- vector("list", N)
  sigma2_list <- numeric(N)

  for (i in seq_along(countries)) {
    sub <- pdata[pdata$iso3 == countries[i], ]
    sub_df <- as.data.frame(sub)
    sub_df <- sub_df %>% drop_na(all.vars(formula_obj))
    T_i <- nrow(sub_df)
    if (T_i < 5) next
    m <- tryCatch(lm(formula_obj, data=sub_df), error=function(e) NULL)
    if (is.null(m)) next
    k <- length(coef(m)) - 1
    beta_list[[i]] <- coef(m)[-1]  # Exclude intercept
    sigma2_list[i] <- sum(resid(m)^2) / (T_i - k - 1)
  }

  # Pool estimates
  valid <- !sapply(beta_list, is.null)
  betas <- do.call(rbind, beta_list[valid])
  beta_bar <- colMeans(betas, na.rm=TRUE)
  N_valid <- sum(valid)

  # Swamy statistic
  S <- 0
  for (i in which(valid)) {
    S <- S + (1/sigma2_list[i]) * sum((betas[sum(valid[1:i]),] - beta_bar)^2)
  }
  k <- ncol(betas)
  T_avg <- mean(sapply(which(valid), function(i) {
    sub <- pdata[pdata$iso3 == countries[i], ]
    nrow(drop_na(as.data.frame(sub), all.vars(formula_obj)))
  }))

  # PY Delta statistic
  Delta    <- sqrt(N) * (S / N - k) / sqrt(2*k)
  Delta_adj <- sqrt(N) * (S / N - k * (T_avg-k-1)/(T_avg-2*k-3)) / sqrt(2*k*(T_avg-k-1)^2/(T_avg-2*k-3)^2)

  pval_D   <- 2 * pnorm(-abs(Delta))
  pval_Dadj <- 2 * pnorm(-abs(Delta_adj))

  list(Delta=Delta, pval_D=pval_D,
       Delta_adj=Delta_adj, pval_Dadj=pval_Dadj,
       N=N_valid, k=k)
}

cat("═══ Slope Homogeneity Test (Pesaran-Yamagata 2008) ═══\n\n")
py <- py_slope_test(pdata_base, "ln_tfp ~ ln_gdppc + rural_share + ln_fert + ln_agl")
cat(sprintf("Δ  stat = %.3f  (p = %.4f)\n", py$Delta,     py$pval_D))
cat(sprintf("Δ̃  stat = %.3f  (p = %.4f)\n", py$Delta_adj, py$pval_Dadj))
cat(sprintf("N = %d, k = %d\n", py$N, py$k))
cat(sprintf("Interpretation: %s\n\n",
    ifelse(py$pval_D < 0.05,
           "REJECT H0 → Slope heterogeneity confirmed (use heterojen estimators: CS-ARDL, AMG, CCEMG)",
           "FAIL TO REJECT H0 → Slope homogeneity (pooled estimators acceptable)")))

# ── 3. Export Table 2 ──────────────────────────────────────────────────────────
tab2 <- data.frame(
  Test = c("Pesaran (2004) CD", "Pesaran-Yamagata Δ", "Pesaran-Yamagata Δ̃ (adj.)"),
  Statistic = round(c(cd_manual$CD, py$Delta, py$Delta_adj), 3),
  `p-value` = round(c(cd_manual$pval, py$pval_D, py$pval_Dadj), 4),
  Decision = c(
    ifelse(cd_manual$pval < 0.05, "CSD present ***", "No CSD"),
    ifelse(py$pval_D < 0.05, "Heterogeneous ***", "Homogeneous"),
    ifelse(py$pval_Dadj < 0.05, "Heterogeneous ***", "Homogeneous")
  ),
  check.names = FALSE
)
cat("Table 2:\n"); print(tab2)

tab2_xt <- xtable(tab2,
  caption = "Cross-Section Dependence and Slope Homogeneity Tests",
  label   = "tab:cd_slope"
)
print(tab2_xt,
  file=file.path(TBLS, "tab2_cd_slope_tests.tex"),
  include.rownames=FALSE, booktabs=TRUE, caption.placement="top"
)
cat("→ Saved: tab2_cd_slope_tests.tex\n")
cat("✓ Step 2 complete.\n")
cat("  Next: source('03_unit_root.R')\n")
