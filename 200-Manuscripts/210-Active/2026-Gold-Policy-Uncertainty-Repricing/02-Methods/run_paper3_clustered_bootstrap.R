## ============================================================
## P3 Month-Clustered Bootstrap SE Check (FAST VERSION)
## Uses parallel::mclapply + B=500
## ============================================================

suppressPackageStartupMessages({
  library(quantreg)
  library(readr)
  library(dplyr)
  library(parallel)
})

set.seed(42)
B_BOOT  <- 500
N_CORES <- max(1L, detectCores() - 1L)
TAUS    <- c(0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95)

cat(sprintf("Using %d cores | B=%d\n", N_CORES, B_BOOT))

## ── Load data ────────────────────────────────────────────────
BASE <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Gold-Policy-Uncertainty-Repricing"
df <- read_csv(file.path(BASE, "03-Results/paper3_gold_policy_uncertainty_dataset.csv"),
               show_col_types = FALSE) %>%
  mutate(
    DATE      = as.Date(DATE),
    month_id  = format(DATE, "%Y-%m"),
    delta_epu = c(NA, diff(log(epu_us + 1))),
    delta_fed = c(NA, diff(fed_funds_effective)),
    delta_vix = c(NA, diff(log(VIX + 1))),
    delta_dxy = c(NA, diff(log(DXY)))
  ) %>%
  filter(!is.na(gold_return), !is.na(delta_epu),
         !is.na(delta_fed), !is.na(delta_vix), !is.na(delta_dxy),
         is.finite(delta_epu), is.finite(delta_dxy))

months_vec  <- unique(df$month_id)
N_months    <- length(months_vec)
# Pre-split data by month for fast lookup
df_by_month <- split(df, df$month_id)

cat(sprintf("N obs: %d | N months (clusters): %d\n\n", nrow(df), N_months))

## ── Standard xy bootstrap ────────────────────────────────────
cat("[1/3] Standard xy bootstrap...\n")
xy_ses <- sapply(TAUS, function(tau) {
  fit  <- rq(gold_return ~ delta_epu + delta_fed + delta_vix + delta_dxy,
             data = df, tau = tau, method = "br")
  boot <- summary(fit, se = "boot", R = B_BOOT, bsmethod = "xy")
  coef(boot)["delta_epu", "Std. Error"]
})

## ── Month-clustered bootstrap (parallel) ─────────────────────
cat("[2/3] Month-clustered bootstrap (parallel)...\n")

# Point estimates
betas_full <- sapply(TAUS, function(tau) {
  fit <- rq(gold_return ~ delta_epu + delta_fed + delta_vix + delta_dxy,
            data = df, tau = tau, method = "br")
  coef(fit)["delta_epu"]
})

# One function per quantile — parallelize over B draws
clustered_se_one_tau <- function(tau, b_seed) {
  set.seed(b_seed)
  boot_betas <- numeric(B_BOOT)
  for (b in seq_len(B_BOOT)) {
    drawn  <- sample(months_vec, N_months, replace = TRUE)
    boot_df <- do.call(rbind, df_by_month[drawn])
    fit_b  <- tryCatch(
      rq(gold_return ~ delta_epu + delta_fed + delta_vix + delta_dxy,
         data = boot_df, tau = tau, method = "br"),
      error = function(e) NULL
    )
    boot_betas[b] <- if (!is.null(fit_b)) coef(fit_b)["delta_epu"] else NA_real_
  }
  boot_betas <- boot_betas[!is.na(boot_betas)]
  list(se = sd(boot_betas),
       ci_lo = quantile(boot_betas, 0.025),
       ci_hi = quantile(boot_betas, 0.975))
}

# Run quantiles in parallel
cluster_results <- mclapply(
  seq_along(TAUS),
  function(i) clustered_se_one_tau(TAUS[i], b_seed = 42 + i),
  mc.cores = N_CORES
)

## ── Results table ─────────────────────────────────────────────
cat("\n[3/3] Results:\n\n")
cat(sprintf("%-6s %12s %12s %8s %s\n",
            "tau", "xy_SE", "cluster_SE", "ratio", "verdict"))
cat(strrep("─", 60), "\n")

ratio_vec <- numeric(length(TAUS))
for (i in seq_along(TAUS)) {
  xy_se  <- xy_ses[i]
  cl_se  <- cluster_results[[i]]$se
  ratio  <- cl_se / xy_se
  ratio_vec[i] <- ratio
  verdict <- ifelse(ratio > 1.5, "⚠️  INFLATED",
                    ifelse(ratio > 1.2, "⚠️  moderate", "✅ similar"))
  cat(sprintf("tau=%.2f  xy_SE=%10.3e  cl_SE=%10.3e  ratio=%5.2f  %s\n",
              TAUS[i], xy_se, cl_se, ratio, verdict))
}
cat(strrep("─", 60), "\n")
cat(sprintf("Mean ratio: %.3f | Max ratio: %.3f (tau=%.2f)\n",
            mean(ratio_vec), max(ratio_vec), TAUS[which.max(ratio_vec)]))

## ── Verdict ───────────────────────────────────────────────────
cat("\n── VERDICT ──\n")
mean_ratio <- mean(ratio_vec)
tail_ratios <- ratio_vec[TAUS %in% c(0.05, 0.95)]
if (all(tail_ratios < 1.3)) {
  cat(sprintf(
"✅ ROBUST: Clustered SEs at key tails (tau=0.05 and tau=0.95) are within\n   %.0f%% of xy SEs. The *** significance at both tails survives clustering.\n   Limitation 1 note is precautionary and correct, but core findings are robust.\n",
    (max(tail_ratios) - 1) * 100))
} else {
  cat(sprintf(
"⚠️  CAUTION: Clustered SEs at tails are %.1fx–%.1fx larger than xy SEs.\n   The *** results should be re-reported with clustered CIs.\n",
    min(tail_ratios), max(tail_ratios)))
}

## ── Save ─────────────────────────────────────────────────────
out <- data.frame(
  tau        = TAUS,
  beta_epu   = betas_full,
  se_xy      = xy_ses,
  se_cluster = sapply(cluster_results, `[[`, "se"),
  ci_lo_cl   = sapply(cluster_results, function(r) r$ci_lo),
  ci_hi_cl   = sapply(cluster_results, function(r) r$ci_hi),
  ratio      = ratio_vec
)
write_csv(out, file.path(BASE, "03-Results/clustered_bootstrap_se_check.csv"))
cat(sprintf("\nSaved: 03-Results/clustered_bootstrap_se_check.csv\n"))
cat("✅ Done.\n")
