# ============================================================
# CIVETS Unemployment — AMG + CCEMG + Webb Bootstrap CI
# Script: 04_amg_ccemg_webb_20260426.R
# Author: MGO | Date: 2026-04-26
# ============================================================
# AMG  : Bond & Eberhardt (2009) — adds common dynamic process
# CCEMG: Pesaran (2006) — augments with CS means
# Webb bootstrap: mandatory (N=6 clusters < 30 rule)
# ============================================================

suppressPackageStartupMessages({ library(tidyverse) })

panel <- read_csv("01-Data/raw/civets_panel_merged_20260426.csv",
                  show_col_types = FALSE) %>%
  mutate(ln_gdp_pc = log(gdp_pc)) %>%
  arrange(iso3c, year)

countries <- sort(unique(panel$iso3c))
N <- length(countries); T_obs <- 24

dep  <- "unemp"
regs <- c("ln_gdp_pc", "inflation", "trade", "goveff", "rulelaw", "corrupt")
k    <- length(regs)

cat("=== AMG + CCEMG Estimation ===\n")
cat(sprintf("N=%d, T=%d | %s ~ %s\n\n", N, T_obs, dep, paste(regs, collapse=" + ")))

# ═══════════════════════════════════════════════════════════
# 1. CCEMG — Pesaran (2006)
# Augment each i-regression with cross-sectional means of y and X
# β_CCEMG = (1/N) Σ_i β̂_i  (individual CCEMG estimates)
# ═══════════════════════════════════════════════════════════
ccemg_est <- function(panel, dep, regs) {
  # Compute CS means for all variables
  cs_means <- panel %>%
    group_by(year) %>%
    summarise(
      cs_y  = mean(get(dep),  na.rm=TRUE),
      across(all_of(regs), mean, na.rm=TRUE, .names="cs_{.col}"),
      .groups="drop"
    )

  panel_aug <- panel %>% left_join(cs_means, by="year")
  augvars   <- c("cs_y", paste0("cs_", regs))

  betas <- matrix(NA, N, k); rownames(betas) <- countries; colnames(betas) <- regs

  for (i in seq_along(countries)) {
    sub <- panel_aug %>% filter(iso3c == countries[i])
    fml <- as.formula(paste(dep, "~",
                            paste(c(regs, augvars), collapse=" + ")))
    m <- tryCatch(lm(fml, data=sub), error=function(e) NULL)
    if (!is.null(m)) {
      b <- coef(m)
      for (r in regs) {
        if (r %in% names(b)) betas[i, r] <- b[r]
      }
    }
  }

  beta_mg  <- colMeans(betas, na.rm=TRUE)
  se_mg    <- apply(betas, 2, function(x) sd(x, na.rm=TRUE) / sqrt(sum(!is.na(x))))
  t_mg     <- beta_mg / se_mg
  list(beta=beta_mg, se=se_mg, t=t_mg, betas_i=betas)
}

# ═══════════════════════════════════════════════════════════
# 2. AMG — Bond & Eberhardt (2009)
# Step 1: First-difference OLS on pooled panel + year dummies → μ̂_t
# Step 2: Individual OLS of y_it on x_it and μ̂_t
# β_AMG = (1/N) Σ_i β̂_i
# ═══════════════════════════════════════════════════════════
amg_est <- function(panel, dep, regs) {
  # Step 1: FD pooled regression with year dummies to extract CDP (μ̂_t)
  panel_fd <- panel %>%
    group_by(iso3c) %>%
    mutate(
      across(all_of(c(dep, regs)), ~c(NA, diff(.)), .names="d_{.col}")
    ) %>%
    ungroup() %>%
    filter(!is.na(get(paste0("d_", dep))))

  # Year dummies for CDP
  fd_dep  <- paste0("d_", dep)
  fd_regs <- paste0("d_", regs)

  fml_fd <- as.formula(paste(fd_dep, "~",
                              paste(fd_regs, collapse="+"),
                              "+ factor(year) - 1"))

  step1 <- tryCatch(lm(fml_fd, data=panel_fd), error=function(e) NULL)

  # Extract year-dummy coefficients as CDP proxy μ̂_t
  if (!is.null(step1)) {
    year_coefs <- coef(step1)[grep("factor\\(year\\)", names(coef(step1)))]
    years      <- as.integer(gsub("factor\\(year\\)", "", names(year_coefs)))
    cdp_df     <- tibble(year=years, cdp=as.numeric(year_coefs))
    # Prepend the first year with CDP=0
    min_yr <- min(panel$year)
    if (!min_yr %in% cdp_df$year)
      cdp_df <- bind_rows(tibble(year=min_yr, cdp=0), cdp_df)
    cdp_df <- cdp_df %>% arrange(year) %>%
              mutate(cdp_cum = cumsum(cdp))  # cumulate FD CDP → level proxy
  } else {
    # Fallback: time trend as CDP
    cdp_df <- tibble(year=unique(panel$year), cdp_cum=seq_along(unique(panel$year)))
  }

  panel_amg <- panel %>% left_join(cdp_df %>% select(year, cdp_cum), by="year")

  # Step 2: Individual OLS with CDP
  betas <- matrix(NA, N, k); rownames(betas) <- countries; colnames(betas) <- regs

  for (i in seq_along(countries)) {
    sub <- panel_amg %>% filter(iso3c == countries[i])
    fml <- as.formula(paste(dep, "~",
                            paste(c(regs, "cdp_cum"), collapse=" + ")))
    m <- tryCatch(lm(fml, data=sub), error=function(e) NULL)
    if (!is.null(m)) {
      b <- coef(m)
      for (r in regs) {
        if (r %in% names(b)) betas[i, r] <- b[r]
      }
    }
  }

  beta_mg <- colMeans(betas, na.rm=TRUE)
  se_mg   <- apply(betas, 2, function(x) sd(x, na.rm=TRUE) / sqrt(sum(!is.na(x))))
  t_mg    <- beta_mg / se_mg
  list(beta=beta_mg, se=se_mg, t=t_mg, betas_i=betas)
}

# ═══════════════════════════════════════════════════════════
# 3. WEBB WILD CLUSTER BOOTSTRAP CI (N=6 mandatory)
# Weights: {−√1.5, −1, −√0.5, √0.5, 1, √1.5} (Webb 2023)
# ═══════════════════════════════════════════════════════════
webb_bootstrap_ci <- function(panel, dep, regs, estimator="ccemg",
                              B=999, alpha=0.05) {
  cat(sprintf("  Running Webb bootstrap (B=%d, estimator=%s)...\n", B, estimator))
  webb_weights <- c(-sqrt(1.5), -1, -sqrt(0.5), sqrt(0.5), 1, sqrt(1.5))
  set.seed(2026)

  # Point estimate
  if (estimator == "ccemg") {
    pt <- ccemg_est(panel, dep, regs)
  } else {
    pt <- amg_est(panel, dep, regs)
  }
  beta_hat <- pt$beta

  # Bootstrap distribution
  boot_betas <- matrix(NA, B, k); colnames(boot_betas) <- regs
  for (b in 1:B) {
    # Assign random Webb weight to each cluster (country)
    w_i <- sample(webb_weights, N, replace=TRUE)
    panel_b <- panel
    for (i in seq_along(countries)) {
      idx <- which(panel_b$iso3c == countries[i])
      # Scale observations by cluster weight (wild bootstrap on cluster scores)
      panel_b[[dep]][idx] <- panel_b[[dep]][idx] * w_i[i]
    }
    if (estimator == "ccemg") {
      res_b <- tryCatch(ccemg_est(panel_b, dep, regs), error=function(e) NULL)
    } else {
      res_b <- tryCatch(amg_est(panel_b, dep, regs), error=function(e) NULL)
    }
    if (!is.null(res_b)) boot_betas[b, ] <- res_b$beta
  }

  # Percentile CI
  ci_lo <- apply(boot_betas, 2, quantile, probs=alpha/2,   na.rm=TRUE)
  ci_hi <- apply(boot_betas, 2, quantile, probs=1-alpha/2, na.rm=TRUE)
  # p-value: proportion of bootstrap betas on same side as 0 relative to point est
  p_webb <- sapply(1:k, function(j) {
    b_star <- boot_betas[, j] - mean(boot_betas[, j], na.rm=TRUE)
    2 * min(mean(b_star >= abs(beta_hat[j]), na.rm=TRUE),
            mean(b_star <= -abs(beta_hat[j]), na.rm=TRUE))
  })
  names(p_webb) <- regs

  list(beta=beta_hat, ci_lo=ci_lo, ci_hi=ci_hi, p_webb=p_webb,
       boot_dist=boot_betas)
}

# ── Run CCEMG ───────────────────────────────────────────────
cat("Running CCEMG...\n")
ccemg <- ccemg_est(panel, dep, regs)

cat("Running AMG...\n")
amg   <- amg_est(panel, dep, regs)

# ── Webb bootstrap ──────────────────────────────────────────
cat("\nWebb bootstrap for CCEMG:\n")
wb_ccemg <- webb_bootstrap_ci(panel, dep, regs, estimator="ccemg", B=999)
cat("Webb bootstrap for AMG:\n")
wb_amg   <- webb_bootstrap_ci(panel, dep, regs, estimator="amg",   B=999)

# ── Results table ────────────────────────────────────────────
sig_str <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.01) "***" else if (p < 0.05) "**" else if (p < 0.10) "*" else ""
}

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("TABLE: Long-Run Coefficients — CCEMG and AMG\n")
cat(sprintf("N=6, T=24 | Webb bootstrap CI (B=999, 95%%)\n"))
cat("═══════════════════════════════════════════════════════════════\n")
cat(sprintf("%-14s  %8s  %16s  %8s  %16s\n",
            "Regressor", "CCEMG", "Webb 95% CI", "AMG", "Webb 95% CI"))
cat(sprintf("%-14s  %8s  %16s  %8s  %16s\n",
            "", "coeff", "[lo, hi] p", "coeff", "[lo, hi] p"))
cat(paste(rep("─",72),collapse=""),"\n")

results_rows <- list()
for (r in regs) {
  cc <- round(ccemg$beta[r],4); clo <- round(wb_ccemg$ci_lo[r],4)
  chi <- round(wb_ccemg$ci_hi[r],4); cp  <- round(wb_ccemg$p_webb[r],4)
  ac <- round(amg$beta[r],4);  alo <- round(wb_amg$ci_lo[r],4)
  ahi <- round(wb_amg$ci_hi[r],4);  ap  <- round(wb_amg$p_webb[r],4)
  cat(sprintf("%-14s  %8.4f  [%6.4f,%6.4f]%3s  %8.4f  [%6.4f,%6.4f]%3s\n",
              r, cc, clo, chi, sig_str(cp), ac, alo, ahi, sig_str(ap)))
  results_rows[[r]] <- tibble(
    variable=r,
    ccemg=cc, ccemg_ci_lo=clo, ccemg_ci_hi=chi, ccemg_p_webb=cp,
    amg=ac,   amg_ci_lo=alo,   amg_ci_hi=ahi,   amg_p_webb=ap
  )
}
cat(paste(rep("─",72),collapse=""),"\n")
cat("Notes: *** p<0.01 ** p<0.05 * p<0.10 (Webb wild cluster bootstrap)\n")
cat("       Webb (2023) 6-point weights: {±√0.5, ±1, ±√1.5}\n")
cat("       CCEMG: cross-section mean augmented (Pesaran 2006)\n")
cat("       AMG: augmented mean group (Bond & Eberhardt 2009)\n")

# ── Individual heterogeneity ─────────────────────────────────
cat("\n=== Individual β̂_i (CCEMG) — ln_gdp_pc ===\n")
for (i in seq_along(countries)) {
  cat(sprintf("  %-3s  %7.4f\n", countries[i], ccemg$betas_i[i,"ln_gdp_pc"]))
}

cat("\n=== Individual β̂_i (AMG) — ln_gdp_pc ===\n")
for (i in seq_along(countries)) {
  cat(sprintf("  %-3s  %7.4f\n", countries[i], amg$betas_i[i,"ln_gdp_pc"]))
}

# ── Save ────────────────────────────────────────────────────
results_df <- bind_rows(results_rows)
dir.create("03-Output/tables", recursive=TRUE, showWarnings=FALSE)
write_csv(results_df, "03-Output/tables/results_amg_ccemg_webb_20260426.csv")
cat("\n✅ Saved: results_amg_ccemg_webb_20260426.csv\n")
