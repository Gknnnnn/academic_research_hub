# ============================================================
# CIVETS Unemployment — Pre-Tests
# CD + Slope Homogeneity + CIPS Unit Root
# Script: 02_pretests_20260426.R
# Author: MGO
# Date: 2026-04-26
# ============================================================

library(tidyverse)
library(plm)       # CD test, panel FE
library(CADFtest)  # CADF (country-level ADF with cross-section)

# ── Load panel ───────────────────────────────────────────────
panel <- read_csv("01-Data/raw/civets_panel_merged_20260426.csv", show_col_types = FALSE)

# Core variables (100% complete)
core_vars <- c("unemp", "gdp_growth", "gdp_pc", "inflation", "trade", "fdi",
               "lfp", "goveff", "rulelaw", "corrupt", "polstab")

panel_core <- panel %>%
  select(iso3c, year, all_of(core_vars)) %>%
  arrange(iso3c, year)

# Convert to pdata.frame
pdata <- pdata.frame(panel_core, index = c("iso3c", "year"))

cat("=== Panel dimensions ===\n")
cat(sprintf("N=%d, T=%d, NT=%d\n\n", length(unique(panel$iso3c)),
            length(unique(panel$year)), nrow(panel_core)))

# ═══════════════════════════════════════════════════════════
# 1. PESARAN (2004) CD TEST
# ═══════════════════════════════════════════════════════════
cat("=== 1. Pesaran (2004) CD Test ===\n")
cat("H0: Cross-sectional independence\n\n")

cd_results <- list()
for (v in core_vars) {
  tryCatch({
    # Demean with FE residuals
    fe_mod <- plm(as.formula(paste(v, "~ 1")), data = pdata, model = "within")
    cd <- pcdtest(fe_mod, test = "cd")
    cd_results[[v]] <- data.frame(
      variable = v,
      CD_stat  = round(cd$statistic, 3),
      p_value  = round(cd$p.value, 4),
      decision = ifelse(cd$p.value < 0.05, "CSD ✅", "No CSD")
    )
    cat(sprintf("  %-12s CD=% 6.3f  p=%6.4f  %s\n",
                v, cd$statistic, cd$p.value,
                ifelse(cd$p.value < 0.05, "→ CSD confirmed", "→ No CSD")))
  }, error = function(e) {
    cat(sprintf("  %-12s ERROR: %s\n", v, e$message))
  })
}

cd_table <- bind_rows(cd_results)
cat("\nSummary: CSD detected in",
    sum(cd_table$decision == "CSD ✅"), "of", nrow(cd_table), "variables\n\n")

# ═══════════════════════════════════════════════════════════
# 2. PESARAN-YAMAGATA (2008) SLOPE HOMOGENEITY (Delta test)
# ═══════════════════════════════════════════════════════════
cat("=== 2. Pesaran-Yamagata (2008) Slope Homogeneity (Delta) ===\n")
cat("H0: Slope homogeneity (poolability)\n\n")

# Main regression: unemp ~ gdp_growth + inflation + trade + fdi + goveff
# Compute individual OLS and pool OLS, then Delta statistic
delta_test <- function(pdata, dep, regs) {
  fml <- as.formula(paste(dep, "~", paste(regs, collapse = " + ")))
  N <- length(unique(pdata$iso3c))
  T <- length(unique(pdata$year))
  k <- length(regs)

  # Pool OLS
  pool_mod <- plm(fml, data = pdata, model = "pooling")
  beta_pool <- coef(pool_mod)[-1]  # exclude intercept

  # Individual OLS
  indiv_betas <- matrix(NA, nrow = N, ncol = k)
  countries <- unique(as.character(pdata$iso3c))
  for (i in seq_along(countries)) {
    sub <- pdata[pdata$iso3c == countries[i], ]
    sub_df <- as.data.frame(sub)
    mod_i <- lm(fml, data = sub_df)
    b <- coef(mod_i)
    b_names <- names(b)[-1]
    for (j in seq_along(regs)) {
      idx <- which(b_names == regs[j])
      if (length(idx) > 0) indiv_betas[i, j] <- b[idx + 1]
    }
  }

  # Delta tilde (Pesaran-Yamagata 2008, eq. 4)
  S <- sum(apply(indiv_betas, 1, function(bi) {
    if (any(is.na(bi))) return(0)
    t(bi - beta_pool) %*% (bi - beta_pool)
  }), na.rm = TRUE)

  delta_tilde <- sqrt(N / (2 * k)) * (S / N - k)
  # Approximate p-value from N(0,1)
  p_val <- 2 * (1 - pnorm(abs(delta_tilde)))

  cat(sprintf("  Δ̃ = %.3f  p = %.4f  %s\n",
              delta_tilde, p_val,
              ifelse(p_val < 0.05, "→ Slope HETEROGENEITY confirmed", "→ Homogeneous slopes")))
  return(list(delta = delta_tilde, p = p_val))
}

regs_main <- c("gdp_growth", "inflation", "trade", "fdi", "goveff")
cat(sprintf("  Model: unemp ~ %s\n", paste(regs_main, collapse=" + ")))
slope_res <- delta_test(pdata, "unemp", regs_main)

cat("\n")

# ═══════════════════════════════════════════════════════════
# 3. CIPS PANEL UNIT ROOT (Pesaran 2007)
# ═══════════════════════════════════════════════════════════
cat("=== 3. CIPS Panel Unit Root Test (Pesaran 2007) ===\n")
cat("H0: Unit root (non-stationary)\n")
cat("CV (N=6,T=24, no trend): 10%=-2.21  5%=-2.33  1%=-2.53\n\n")

# CIPS: average of CADF statistics across i
cips_test <- function(series_mat, lags = 1) {
  # series_mat: T x N matrix
  N <- ncol(series_mat)
  T <- nrow(series_mat)
  cadf_stats <- numeric(N)
  # Cross-section mean
  cs_mean <- rowMeans(series_mat, na.rm = TRUE)

  for (i in 1:N) {
    y <- series_mat[, i]
    dy <- diff(y)
    y_lag <- y[-T]
    d_cs <- diff(cs_mean)
    cs_lag <- cs_mean[-T]

    # CADF regression: dy ~ y_lag + cs_lag + d_cs (+ lags of dy, d_cs)
    n <- length(dy)
    if (lags > 0) {
      dy_lags <- embed(dy, lags + 1)[, -1, drop = FALSE]
      n <- nrow(dy_lags)
      dy_reg  <- dy[(lags + 1):length(dy)]
      y_l     <- y_lag[(lags + 1):length(y_lag)]
      cs_l    <- cs_lag[(lags + 1):length(cs_lag)]
      d_cs_r  <- d_cs[(lags + 1):length(d_cs)]
      X <- cbind(1, y_l, cs_l, d_cs_r, dy_lags)
    } else {
      dy_reg <- dy
      y_l    <- y_lag
      cs_l   <- cs_lag
      d_cs_r <- d_cs
      X <- cbind(1, y_l, cs_l, d_cs_r)
    }

    tryCatch({
      mod <- lm(dy_reg ~ X - 1)
      se  <- summary(mod)$coefficients[2, 2]
      b   <- coef(mod)[2]
      cadf_stats[i] <- b / se
    }, error = function(e) { cadf_stats[i] <<- NA })
  }
  cips <- mean(cadf_stats, na.rm = TRUE)
  return(list(CIPS = cips, CADF = cadf_stats))
}

# Prepare matrices
countries <- sort(unique(panel_core$iso3c))
T_full <- 24

cips_results <- data.frame()
for (v in c("unemp", "gdp_growth", "gdp_pc", "inflation", "trade", "fdi",
            "goveff", "rulelaw", "corrupt")) {
  mat <- matrix(NA, nrow = T_full, ncol = length(countries))
  colnames(mat) <- countries
  for (j in seq_along(countries)) {
    vals <- panel_core[panel_core$iso3c == countries[j], v][[1]]
    if (length(vals) == T_full) mat[, j] <- vals
  }

  # Level
  res_lev <- cips_test(mat, lags = 1)
  # First difference
  mat_d <- apply(mat, 2, diff)
  res_dif <- cips_test(mat_d, lags = 1)

  # Integration order
  cv5 <- -2.33
  order_str <- if (res_lev$CIPS < cv5) "I(0)" else if (res_dif$CIPS < cv5) "I(1)" else "I(2)+"

  cips_results <- rbind(cips_results, data.frame(
    variable = v,
    CIPS_level = round(res_lev$CIPS, 3),
    CIPS_diff  = round(res_dif$CIPS, 3),
    order      = order_str
  ))

  sig_lev <- if (res_lev$CIPS < -2.53) "***" else if (res_lev$CIPS < -2.33) "**" else if (res_lev$CIPS < -2.21) "*" else ""
  sig_dif <- if (res_dif$CIPS < -2.53) "***" else if (res_dif$CIPS < -2.33) "**" else if (res_dif$CIPS < -2.21) "*" else ""
  cat(sprintf("  %-12s Level: %6.3f%-3s  Δ: %6.3f%-3s  → %s\n",
              v, res_lev$CIPS, sig_lev, res_dif$CIPS, sig_dif, order_str))
}

# ── Save results ────────────────────────────────────────────
dir.create("03-Output/tables", recursive = TRUE, showWarnings = FALSE)
write_csv(cd_table,    "03-Output/tables/results_cd_test_20260426.csv")
write_csv(cips_results,"03-Output/tables/results_cips_20260426.csv")

cat("\n\n=== PRE-TEST DECISION ===\n")
n_csd <- sum(cd_table$decision == "CSD ✅")
cat(sprintf("CD: %d/%d variables show CSD → 2nd-generation estimators MANDATORY\n", n_csd, nrow(cd_table)))
cat(sprintf("Slope homogeneity: Δ̃=%.3f p=%.4f → %s\n",
            slope_res$delta, slope_res$p,
            if (slope_res$p < 0.05) "AMG/CCEMG confirmed (heterogeneous slopes)" else "MG may suffice"))
cat("Unit root: see CIPS table above\n")
cat("\n✅ Saved: results_cd_test_20260426.csv | results_cips_20260426.csv\n")
