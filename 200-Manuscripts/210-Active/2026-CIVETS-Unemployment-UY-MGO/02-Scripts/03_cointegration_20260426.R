# ============================================================
# CIVETS Unemployment — Cointegration Tests
# Westerlund (2007) ECM-based + Engle-Granger residual check
# Script: 03_cointegration_20260426.R
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(tseries)   # adf.test
})

panel <- read_csv("01-Data/raw/civets_panel_merged_20260426.csv",
                  show_col_types = FALSE) %>%
  mutate(ln_gdp_pc = log(gdp_pc)) %>%
  arrange(iso3c, year)

countries <- sort(unique(panel$iso3c))
N <- length(countries); T_obs <- 24

dep  <- "unemp"
regs <- c("ln_gdp_pc", "inflation", "trade", "goveff", "rulelaw", "corrupt")
k    <- length(regs)

cat(sprintf("=== Westerlund (2007) | %s ~ %s ===\n", dep, paste(regs, collapse=" + ")))
cat(sprintf("N=%d, T=%d, k=%d, lags=1\n\n", N, T_obs, k))

# ── Country-level ECM: Δy = α*y_{t-1} + Β*x_{t-1} + γ*Δy_{t-1} + Φ*Δx_{t-1} + ε
run_ecm <- function(df, dep, regs, lag = 1) {
  y <- df[[dep]]
  X <- as.matrix(df[, regs])
  T <- nrow(df)

  dy <- diff(y)
  dX <- apply(X, 2, diff)

  # Lag-1 levels
  y_lag1 <- y[1:(T-1)]
  X_lag1 <- X[1:(T-1), , drop = FALSE]

  # Lag-1 differences
  dy_lag1 <- dy[1:(T-2)]
  dX_lag1 <- dX[1:(T-2), , drop = FALSE]

  # Align: response is dy[2:(T-1)], length T-2
  dy_r  <- dy[2:(T-1)]
  yl    <- y_lag1[2:(T-1)]
  Xl    <- X_lag1[2:(T-1), , drop = FALSE]
  dyl   <- dy_lag1         # length T-2
  dXl   <- dX_lag1         # (T-2) x k

  RHS <- cbind(intercept = 1, yl, Xl, dyl, dXl)
  colnames(RHS) <- c("intercept", "y_lag1",
                     paste0(regs, "_lag1"),
                     "dy_lag1",
                     paste0("d", regs, "_lag1"))

  mod  <- lm(dy_r ~ RHS - 1)
  coef_mat <- summary(mod)$coefficients
  alpha    <- coef_mat["RHSy_lag1", "Estimate"]
  se_alpha <- coef_mat["RHSy_lag1", "Std. Error"]
  t_alpha  <- coef_mat["RHSy_lag1", "t value"]

  list(alpha = alpha, se = se_alpha, t = t_alpha,
       resid = residuals(mod), fitted = fitted(mod), dy_r = dy_r)
}

# ── Run for each country ──────────────────────────────────
alpha_vec <- numeric(N); se_vec <- numeric(N); t_vec <- numeric(N)
cat("Individual ECT coefficients:\n")
for (i in seq_along(countries)) {
  sub  <- panel %>% filter(iso3c == countries[i])
  res  <- tryCatch(run_ecm(sub, dep, regs), error = function(e) NULL)
  if (!is.null(res)) {
    alpha_vec[i] <- res$alpha
    se_vec[i]    <- res$se
    t_vec[i]     <- res$t
    sig <- if (abs(res$t) > 3.36) "***" else if (abs(res$t) > 2.09) "**" else
           if (abs(res$t) > 1.75) "*"   else ""
    cat(sprintf("  %-3s  α=%7.4f  SE=%6.4f  t=%6.3f%s\n",
                countries[i], res$alpha, res$se, res$t, sig))
  }
}

# ── Westerlund statistics ─────────────────────────────────
Gt_obs <- mean(t_vec)
Ga_obs <- (T_obs / N) * sum(alpha_vec)
Pt_obs <- sum(t_vec) / sqrt(N)
Pa_obs <- T_obs * mean(alpha_vec)

cat(sprintf("\nWesterlund statistics:\n"))
cat(sprintf("  Gt = %.4f  (group-mean t-stat; H1: some i cointegrated)\n", Gt_obs))
cat(sprintf("  Ga = %.4f  (group-mean α;     H1: some i cointegrated)\n", Ga_obs))
cat(sprintf("  Pt = %.4f  (panel t-stat;     H1: all i cointegrated)\n",  Pt_obs))
cat(sprintf("  Pa = %.4f  (panel α;          H1: all i cointegrated)\n",  Pa_obs))

# ── Bootstrap p-values (B=499) ────────────────────────────
cat("\nBootstrap p-values (B=499, residual resampling under H0)...\n")
set.seed(2026)
B <- 499
boot_mat <- matrix(NA, B, 4)

for (b in 1:B) {
  av_b <- numeric(N); tv_b <- numeric(N)
  for (i in seq_along(countries)) {
    sub  <- panel %>% filter(iso3c == countries[i])
    res0 <- tryCatch(run_ecm(sub, dep, regs), error = function(e) NULL)
    if (is.null(res0)) next

    # Resample residuals under H0 (α=0)
    resamp <- sample(res0$resid, replace = TRUE)

    # Reconstruct Δy_boot = fitted_H0 + ε* where fitted_H0 excludes y_lag1 term
    # Approximate: just perturb the ECT residuals
    dy_boot  <- res0$fitted - res0$alpha * res0$dy_r + resamp
    # Reconstruct levels
    y_orig   <- sub[[dep]]
    y_boot   <- cumsum(c(y_orig[1], dy_boot))
    sub_b    <- sub; sub_b[[dep]] <- y_boot[1:T_obs]

    res_b <- tryCatch(run_ecm(sub_b, dep, regs), error = function(e) NULL)
    if (!is.null(res_b)) {
      av_b[i] <- res_b$alpha
      tv_b[i] <- res_b$t
    }
  }
  boot_mat[b, ] <- c(mean(tv_b), (T_obs/N)*sum(av_b),
                     sum(tv_b)/sqrt(N), T_obs*mean(av_b))
}

obs_vec <- c(Gt_obs, Ga_obs, Pt_obs, Pa_obs)
p_boot  <- sapply(1:4, function(j) mean(boot_mat[,j] <= obs_vec[j], na.rm=TRUE))

west_table <- tibble(
  Statistic  = c("Gt","Ga","Pt","Pa"),
  Value      = round(obs_vec, 4),
  p_bootstrap = round(p_boot, 4),
  H1         = c(rep("some i cointegrated",2), rep("all i cointegrated",2))
)

cat("\n=== Westerlund (2007) Final Results ===\n")
cat("H0: No cointegration  |  Bootstrap p-values (B=499)\n\n")
print(west_table, n = 4)

# ── Engle-Granger residual check (country-level) ─────────
cat("\n=== Engle-Granger Residual ADF (per country) ===\n")
cat("NOTE: 1st-generation; reported for country-level insight only\n\n")
for (iso in countries) {
  sub  <- panel %>% filter(iso3c == iso)
  fml  <- as.formula(paste(dep, "~", paste(regs, collapse=" + ")))
  ols  <- lm(fml, data = sub)
  e    <- residuals(ols)
  adf  <- tryCatch(adf.test(e, k = 1), error = function(x) NULL)
  pv   <- if (!is.null(adf)) round(adf$p.value, 4) else NA
  sig  <- if (!is.na(pv) && pv < 0.01) "***" else if (!is.na(pv) && pv < 0.05) "**" else
          if (!is.na(pv) && pv < 0.10) "*"   else ""
  cat(sprintf("  %-3s  ADF p=%6.4f%s  %s\n", iso, pv, sig,
              if (!is.na(pv) && pv < 0.10) "→ cointegrated" else "→ not confirmed"))
}

# ── Save ──────────────────────────────────────────────────
dir.create("03-Output/tables", recursive=TRUE, showWarnings=FALSE)
write_csv(west_table, "03-Output/tables/results_westerlund_20260426.csv")

cat("\n=== COINTEGRATION DECISION ===\n")
n_rej <- sum(west_table$p_bootstrap < 0.10)
cat(sprintf("  %d/4 Westerlund statistics reject H0 at 10%%\n", n_rej))
cat(sprintf("  Mean ECT (ᾱ): %.4f\n", mean(alpha_vec)))
if (n_rej >= 2) {
  cat("  → COINTEGRATION CONFIRMED → proceed with AMG/CCEMG (ECM form)\n")
} else {
  cat("  → Weak cointegration evidence → first-difference model as robustness\n")
}
cat("\n✅ Saved: results_westerlund_20260426.csv\n")
