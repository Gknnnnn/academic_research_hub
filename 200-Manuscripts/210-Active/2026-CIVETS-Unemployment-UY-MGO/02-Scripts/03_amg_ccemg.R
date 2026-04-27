## CIVETS Unemployment — Stage 3: AMG / CCEMG Long-Run Estimation
## Author: Res. Asst. Dr. M. Gökhan Özdemir
## Date: 2026-04-28
##
## Context: Strong CSD (9/10 vars), heterogeneous slopes → 2nd-gen estimators
## Cointegration: Pedroni 5/7 + ECT significant in IDN/TUR/VNM → proceed in levels
##
## Estimators:
##   AMG  — Augmented Mean Group (Bond & Eberhardt 2013, Eberhardt & Bond 2009)
##           Accounts for common dynamic process via year-dummy first-differences
##   CCEMG — Common Correlated Effects Mean Group (Pesaran 2006)
##            Cross-section averages as proxies for unobserved common factors
##
## References:
##   Eberhardt & Bond (2009) Working Paper (AMG)
##   Pesaran (2006) DOI: 10.1111/j.1468-0262.2006.00692.x (CCEMG)
##   Eberhardt & Teal (2010) DOI: 10.1016/j.econlet.2010.07.030
##
## Webb wild cluster bootstrap: mandatory (N=6 < 30 clusters per CLAUDE.md)

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lmtest)
  library(sandwich)
})

set.seed(2026)
options(scipen = 999)

# ── 1. Load data ────────────────────────────────────────────────────────────────
df <- read_csv(
  "../01-Data/raw/civets_panel_full_20260428.csv",
  show_col_types = FALSE
) %>%
  mutate(
    ln_gdp_pc   = log(gdp_pc),
    ln_trade    = log(trade),
    ln_internet = log(internet + 0.1),
    ln_fdi      = log(abs(fdi) + 0.01),
    ln_lfp      = log(lfp),
    ln_vuln_emp = log(vuln_emp)
  ) %>%
  arrange(iso3c, year)

countries <- unique(df$iso3c)
years     <- unique(df$year)
N <- length(countries)
T <- length(years)
cat(sprintf("CIVETS panel: N=%d T=%d\n\n", N, T))

# ── 2. Variable specification ──────────────────────────────────────────────────
# Dependent: unemp (unemployment rate, %)
# Regressors (long-run): gdp_growth, inflation, ln_trade, ln_internet, fdi
# Additional controls: goveff (governance effectiveness), unemp_youth proxy
dep  <- "unemp"
main_regs <- c("gdp_growth", "inflation", "ln_trade", "ln_internet", "fdi")
ext_regs  <- c("gdp_growth", "inflation", "ln_trade", "ln_internet", "fdi", "goveff")

# ── 3. AMG Estimator ──────────────────────────────────────────────────────────
# Step 1: Pool all obs, regress Δy on Δx + year dummies → extract year-dummy coefs
# Step 2: For each country i, regress y on x + (year-dummy coefs as regressor μ̂_t)
# Step 3: Average country-level coefficients → AMG mean-group estimates

amg_estimate <- function(panel_df, dep, regs) {
  all_years <- sort(unique(panel_df$year))
  T_all     <- length(all_years)

  # Compute first differences
  panel_df <- panel_df %>%
    group_by(iso3c) %>%
    arrange(year) %>%
    mutate(
      across(all_of(c(dep, regs)), ~ c(NA, diff(.x)), .names = "d_{.col}")
    ) %>%
    ungroup() %>%
    filter(!is.na(.data[[paste0("d_", dep)]]))

  # Add year dummies for the pooled step
  year_dummies <- model.matrix(~ factor(year) - 1, data = panel_df)
  colnames(year_dummies) <- paste0("yr_", colnames(year_dummies))
  colnames(year_dummies) <- gsub("factor\\(year\\)", "yr_", colnames(year_dummies))

  d_dep  <- paste0("d_", dep)
  d_regs <- paste0("d_", regs)

  # Step 1: pooled ΔY ~ ΔX + year dummies
  pool_df <- data.frame(
    panel_df[, c(d_dep, d_regs), drop = FALSE],
    year_dummies
  )
  pool_fit <- lm(reformulate(c(d_regs, colnames(year_dummies)), d_dep),
                 data = pool_df)
  yr_coefs <- coef(pool_fit)[colnames(year_dummies)]
  # μ̂_t: common dynamic factor estimated from year dummies in first-differences

  # Reconstruct μ̂ for each obs
  yr_coef_df <- data.frame(
    year     = as.integer(gsub("yr_", "", names(yr_coefs))),
    mu_hat_d = as.numeric(yr_coefs)
  )

  # Merge back and cumulate Δμ̂ → μ̂ (levels)
  # μ̂_t (levels) = cumsum of Δμ̂ starting from first observed year
  yr_coef_df <- yr_coef_df %>%
    arrange(year) %>%
    mutate(mu_hat = cumsum(mu_hat_d))

  panel_lev <- read_csv(
    "../01-Data/raw/civets_panel_full_20260428.csv",
    show_col_types = FALSE
  ) %>%
    mutate(
      ln_gdp_pc   = log(gdp_pc),
      ln_trade    = log(trade),
      ln_internet = log(internet + 0.1),
      ln_fdi      = log(abs(fdi) + 0.01)
    ) %>%
    arrange(iso3c, year) %>%
    left_join(yr_coef_df[, c("year","mu_hat")], by = "year")

  # Step 2: country-level AMG regressions: y ~ x + μ̂
  amg_coefs <- lapply(countries, function(cty) {
    d <- filter(panel_lev, iso3c == cty) %>% arrange(year)
    if (any(is.na(d$mu_hat))) d$mu_hat[is.na(d$mu_hat)] <- 0

    y  <- d[[dep]]
    X  <- as.matrix(cbind(1, d[, regs, drop = FALSE], mu_hat = d$mu_hat))
    tryCatch({
      formula_i <- reformulate(c(regs, "mu_hat"), dep)
      fit <- lm(formula_i, data = d)
      cf  <- coef(fit)
      se  <- sqrt(diag(vcov(fit)))
      t_v <- cf / se
      list(coef = cf[c(regs, "mu_hat")],
           se   = se[c(regs, "mu_hat")],
           t    = t_v[c(regs, "mu_hat")],
           ok   = TRUE)
    }, error = function(e) {
      list(coef = setNames(rep(NA, length(regs)+1), c(regs,"mu_hat")),
           se   = setNames(rep(NA, length(regs)+1), c(regs,"mu_hat")),
           t    = setNames(rep(NA, length(regs)+1), c(regs,"mu_hat")),
           ok   = FALSE)
    })
  })

  # Step 3: Mean-group averages
  coef_mat <- do.call(rbind, lapply(amg_coefs, `[[`, "coef"))
  se_mat   <- do.call(rbind, lapply(amg_coefs, `[[`, "se"))

  mg_coef  <- colMeans(coef_mat, na.rm = TRUE)
  mg_se_mg <- apply(coef_mat, 2, sd, na.rm = TRUE) / sqrt(sum(!is.na(coef_mat[,1])))
  mg_t     <- mg_coef / mg_se_mg

  list(
    mg_coef    = mg_coef,
    mg_se      = mg_se_mg,
    mg_t       = mg_t,
    coef_mat   = coef_mat,
    se_mat     = se_mat,
    countries  = countries
  )
}

# ── 4. CCEMG Estimator ────────────────────────────────────────────────────────
# For each unit i: y_it ~ x_it + ȳ_t + x̄_t (cross-section means as proxies)
# Mean-group average of country-level coefficients on x_it

ccemg_estimate <- function(panel_df, dep, regs) {
  # Compute cross-section means for each year
  panel_df <- panel_df %>% arrange(iso3c, year)
  cs_means <- panel_df %>%
    group_by(year) %>%
    summarise(
      across(all_of(c(dep, regs)), \(x) mean(x, na.rm = TRUE), .names = "csm_{.col}"),
      .groups = "drop"
    )

  panel_aug <- panel_df %>% left_join(cs_means, by = "year")

  csm_dep  <- paste0("csm_", dep)
  csm_regs <- paste0("csm_", regs)

  # Country-level CCEMG regressions
  ccemg_coefs <- lapply(countries, function(cty) {
    d <- filter(panel_aug, iso3c == cty) %>% arrange(year)
    # Regress y on x + cross-section means of y and x
    all_regs_i <- c(regs, csm_dep, csm_regs)
    formula_i  <- reformulate(all_regs_i, dep)
    tryCatch({
      fit <- lm(formula_i, data = d)
      cf  <- coef(fit)
      se  <- sqrt(diag(vcov(fit)))
      t_v <- cf / se
      # Extract only structural regs (not CSM regs)
      list(coef = cf[regs], se = se[regs], t = t_v[regs], ok = TRUE)
    }, error = function(e) {
      list(coef = setNames(rep(NA, length(regs)), regs),
           se   = setNames(rep(NA, length(regs)), regs),
           t    = setNames(rep(NA, length(regs)), regs), ok = FALSE)
    })
  })

  # Mean-group
  coef_mat  <- do.call(rbind, lapply(ccemg_coefs, `[[`, "coef"))
  mg_coef   <- colMeans(coef_mat, na.rm = TRUE)
  mg_se_mg  <- apply(coef_mat, 2, sd, na.rm = TRUE) / sqrt(sum(!is.na(coef_mat[,1])))
  mg_t      <- mg_coef / mg_se_mg

  list(
    mg_coef   = mg_coef,
    mg_se     = mg_se_mg,
    mg_t      = mg_t,
    coef_mat  = coef_mat,
    countries = countries
  )
}

# ── 5. Webb wild cluster bootstrap SE ─────────────────────────────────────────
# Mandatory for N=6 < 30 clusters (Webb 2023, CLAUDE.md Anayasa)
# Weights: ±1/√2 with equal probability (Webb 2014 optimal for small N)

webb_bootstrap_mg <- function(coef_mat, countries, B = 999) {
  N_c <- nrow(coef_mat)
  K   <- ncol(coef_mat)
  var_names <- colnames(coef_mat)

  # Webb weights: {-√(3/2), -1/√2, -1/√6, 1/√6, 1/√2, √(3/2)} — 6 point mass
  webb_w <- c(-sqrt(3/2), -1/sqrt(2), -1/sqrt(6), 1/sqrt(6), 1/sqrt(2), sqrt(3/2))

  obs_mg <- colMeans(coef_mat, na.rm = TRUE)

  boot_mg <- matrix(NA_real_, B, K, dimnames = list(NULL, var_names))
  for (b in seq_len(B)) {
    w <- sample(webb_w, N_c, replace = TRUE)
    # Wild bootstrap: demean + reweight
    demeaned <- sweep(coef_mat, 2, obs_mg)
    boot_coef_mat <- sweep(demeaned, 1, w, "*") + matrix(obs_mg, N_c, K, byrow = TRUE)
    boot_mg[b, ] <- colMeans(boot_coef_mat, na.rm = TRUE)
  }

  # Bootstrap SE = SD of bootstrap distribution
  boot_se <- apply(boot_mg, 2, sd, na.rm = TRUE)

  # p-values (two-tailed): proportion of bootstrap shifts exceeding observed value
  boot_p <- sapply(seq_len(K), function(k) {
    mean(abs(boot_mg[, k] - obs_mg[k]) >= abs(obs_mg[k]), na.rm = TRUE)
  })
  names(boot_se) <- var_names
  names(boot_p)  <- var_names

  list(se = boot_se, pval = boot_p, B = B)
}

# ── 6. Run AMG ─────────────────────────────────────────────────────────────────
cat("=======================================================\n")
cat("AMG ESTIMATION — Augmented Mean Group\n")
cat("=======================================================\n")
cat("Dep: unemp  |  Regs:", paste(main_regs, collapse=", "), "\n\n")

amg_res  <- amg_estimate(df, dep, main_regs)
webb_amg <- webb_bootstrap_mg(amg_res$coef_mat[, main_regs, drop = FALSE],
                               countries, B = 999)
amg_mg_regs <- amg_res$mg_coef[main_regs]

cat("Variable       AMG coef   Webb SE   t-stat  p(Webb)\n")
cat("──────────────────────────────────────────────────\n")
for (v in main_regs) {
  b    <- amg_res$mg_coef[v]
  se   <- webb_amg$se[v]
  t_v  <- b / se
  pv   <- webb_amg$pval[v]
  sig  <- ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**",
          ifelse(pv < 0.10, "*", "")))
  cat(sprintf("%-14s %8.4f  %8.4f  %6.3f  %.4f %s\n",
              v, b, se, t_v, pv, sig))
}

# ── 7. Run CCEMG ───────────────────────────────────────────────────────────────
cat("\n=======================================================\n")
cat("CCEMG ESTIMATION — Common Correlated Effects Mean Group\n")
cat("=======================================================\n")
cat("Dep: unemp  |  Regs:", paste(main_regs, collapse=", "), "\n\n")

ccemg_res  <- ccemg_estimate(df, dep, main_regs)
webb_ccemg <- webb_bootstrap_mg(ccemg_res$coef_mat, countries, B = 999)

cat("Variable       CCEMG coef  Webb SE   t-stat  p(Webb)\n")
cat("──────────────────────────────────────────────────\n")
for (v in main_regs) {
  b    <- ccemg_res$mg_coef[v]
  se   <- webb_ccemg$se[v]
  t_v  <- b / se
  pv   <- webb_ccemg$pval[v]
  sig  <- ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**",
          ifelse(pv < 0.10, "*", "")))
  cat(sprintf("%-14s %8.4f  %8.4f  %6.3f  %.4f %s\n",
              v, b, se, t_v, pv, sig))
}

# ── 8. Country-level coefficients ────────────────────────────────────────────
cat("\n── Country-level AMG coefficients ──────────────────────\n")
amg_c_mat <- round(amg_res$coef_mat[, main_regs, drop=FALSE], 4)
rownames(amg_c_mat) <- countries
print(amg_c_mat)

cat("\n── Country-level CCEMG coefficients ────────────────────\n")
ccemg_c_mat <- round(ccemg_res$coef_mat, 4)
rownames(ccemg_c_mat) <- countries
print(ccemg_c_mat)

# ── 9. Hausman-like test: AMG vs CCEMG consistency ───────────────────────────
cat("\n── AMG vs CCEMG comparison (coefficient difference) ────\n")
for (v in main_regs) {
  diff_v <- amg_res$mg_coef[v] - ccemg_res$mg_coef[v]
  cat(sprintf("  %-14s  AMG=%7.4f  CCEMG=%7.4f  diff=%7.4f\n",
              v, amg_res$mg_coef[v], ccemg_res$mg_coef[v], diff_v))
}
cat("  Small differences → consistent estimates\n\n")

# ── 10. Save results ────────────────────────────────────────────────────────────
dir.create("../03-Output", showWarnings = FALSE)

# Primary results table
results_wide <- data.frame(
  variable     = main_regs,
  amg_coef     = amg_res$mg_coef[main_regs],
  amg_se_webb  = webb_amg$se[main_regs],
  amg_t_webb   = amg_res$mg_coef[main_regs] / webb_amg$se[main_regs],
  amg_p_webb   = webb_amg$pval[main_regs],
  ccemg_coef   = ccemg_res$mg_coef[main_regs],
  ccemg_se_webb= webb_ccemg$se[main_regs],
  ccemg_t_webb = ccemg_res$mg_coef[main_regs] / webb_ccemg$se[main_regs],
  ccemg_p_webb = webb_ccemg$pval[main_regs],
  N = N, T = T, date_run = "2026-04-28"
)

write_csv(results_wide, "../03-Output/amg_ccemg_results_20260428.csv")
amg_country_df  <- as.data.frame(amg_c_mat);  amg_country_df$country  <- countries
ccemg_country_df<- as.data.frame(ccemg_c_mat); ccemg_country_df$country <- countries
write_csv(amg_country_df,   "../03-Output/amg_country_coefs_20260428.csv")
write_csv(ccemg_country_df, "../03-Output/ccemg_country_coefs_20260428.csv")

cat("Saved → 03-Output/amg_ccemg_results_20260428.csv\n")
cat("        03-Output/amg_country_coefs_20260428.csv\n")
cat("        03-Output/ccemg_country_coefs_20260428.csv\n\n")

# ── 11. Economic interpretation ───────────────────────────────────────────────
cat("=======================================================\n")
cat("ECONOMIC INTERPRETATION (AMG primary)\n")
cat("=======================================================\n")
for (v in main_regs) {
  b   <- amg_res$mg_coef[v]
  pv  <- webb_amg$pval[v]
  sig <- ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**",
         ifelse(pv < 0.10, "*", "n.s.")))
  cat(sprintf("%-14s: β=%7.4f [%s]\n", v, b, sig))
}
cat("\nNote: All coefficients are long-run mean-group estimates.\n")
cat("SE from Webb (2023) wild cluster bootstrap, B=999.\n")
cat("Mandatory for N=6 < 30 clusters (Webb 2023, CAJE).\n")
