## ============================================================
##  Paper 3 — Gold × EPU  |  SVAR Identification Comparison
##  Three scenarios: A=Cholesky  B=Sign-Restricted  C=LP-IV
##  + Quantile Impulse Response Functions (QIRF) from Scenario A
##  Author: Res. Asst. Dr. M. Gökhan Özdemir  |  2026-04-24
## ============================================================

suppressPackageStartupMessages({
  library(vars)      # VAR, SVAR, irf
  library(quantreg)  # rq() for QIRF
  library(ggplot2)
  library(reshape2)
  library(dplyr)
})

## --- optional packages: install if missing ---
pkg_try <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("[INFO] Installing %s ...", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  }
  requireNamespace(pkg, quietly = TRUE)
}
has_VARsignR <- pkg_try("VARsignR")

## ── 0. Paths ────────────────────────────────────────────────
ROOT    <- file.path(Sys.getenv("HOME"),
  "Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma",
  "200-Manuscripts/210-Active/2026-Gold-Policy-Uncertainty-Repricing")
DATA    <- file.path(ROOT, "03-Results/paper3_gold_policy_uncertainty_dataset.csv")
FIG_DIR <- file.path(ROOT, "03-Results/figures")
OUT_TXT <- file.path(ROOT, "03-Results/svar_comparison_results.txt")
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)

## ── 1. Data preparation ─────────────────────────────────────
cat("\n── 1. Loading & preparing data ──────────────────────────────\n")
df <- read.csv(DATA, stringsAsFactors = FALSE)
df$DATE <- as.Date(df$DATE)
df <- df[order(df$DATE), ]

df$epu_change    <- c(NA, diff(df$epu_us))
df$fed_change    <- c(NA, diff(df$fed_funds_effective))
df$vix_change    <- c(NA, diff(df$VIX))
df$dxy_return    <- c(NA, df$DXY[-1] / df$DXY[-nrow(df)] - 1)

# 5-variable system:  EPU first (most exogenous) → gold last (most endogenous)
VAR_COLS  <- c("epu_change", "fed_change", "vix_change", "dxy_return", "gold_return")
df_clean  <- na.omit(df[, c("DATE", VAR_COLS)])
BREAK_IDX <- which(df_clean$DATE == as.Date("2001-08-01"))
if (length(BREAK_IDX) == 0) BREAK_IDX <- which.min(abs(df_clean$DATE - as.Date("2001-08-01")))

# ── CRITICAL: standardise to unit variance ───────────────────
# Variables span SD ~0.004 (dxy_return) to ~12.84 (epu_change).
# Without scaling, Sigma_u condition number ≈ 4.8 billion → Cholesky
# numerically degenerate; sign-restriction draws always rejected.
# Standardise: divide each column by its SD. De-standardise IRFs after.
raw_mat  <- as.matrix(df_clean[, VAR_COLS])
SD_vec   <- apply(raw_mat, 2, sd)
ymat     <- sweep(raw_mat, 2, SD_vec, "/")        # unit-variance matrix
colnames(ymat) <- VAR_COLS
cat(sprintf("Variable SDs (used for rescaling): %s\n",
            paste(sprintf("%s=%.4f", VAR_COLS, SD_vec), collapse=", ")))
cat(sprintf("N = %d obs | %s to %s | break at obs %d (%s)\n",
            nrow(ymat), min(df_clean$DATE), max(df_clean$DATE),
            BREAK_IDX, df_clean$DATE[BREAK_IDX]))

## ── 2. VAR lag selection ────────────────────────────────────
cat("\n── 2. VAR lag selection (AIC, max 15) ───────────────────────\n")
vs   <- VARselect(ymat, lag.max = 15, type = "const")
k_aic <- vs$selection["AIC(n)"]
k_use <- min(max(k_aic, 2), 10)  # cap at 10 to match TY analysis
cat(sprintf("AIC-optimal k = %d  →  using k = %d\n", k_aic, k_use))

## ── 3. Reduced-form VAR (shared across all scenarios) ───────
cat(sprintf("\n── 3. Fitting reduced-form VAR(%d) ──────────────────────────\n", k_use))
var_fit  <- VAR(ymat, p = k_use, type = "const")
resid_rf <- residuals(var_fit)          # N × 5  reduced-form residuals
Sigma_u  <- crossprod(resid_rf) / (nrow(resid_rf) - 5 * k_use - 1)  # 5×5 cov
P_chol   <- t(chol(Sigma_u))            # lower-triangular Cholesky factor
cat(sprintf("Reduced-form VAR fitted. Sigma_u condition number: %.1f\n",
            kappa(Sigma_u)))
# De-standardisation factor: IRF is in (SD-normalised units).
# To recover gold_return units per 1-SD EPU shock:
#   irf_original = irf_standardised × SD_gold / SD_epu
# (already in SD_gold units since ymat_gold = gold/SD_gold;
#  structural EPU shock = 1 SD of standardised EPU = SD_epu of raw EPU)
SD_gold <- SD_vec["gold_return"]
SD_epu  <- SD_vec["epu_change"]
cat(sprintf("De-std factor (SD_gold / SD_epu = %.4f / %.4f = %.6f)\n",
            SD_gold, SD_epu, SD_gold / SD_epu))
cat("IRF units after rescaling: gold_return per 1-SD structural EPU shock\n")

## ── SCENARIO A: Recursive Cholesky SVAR ──────────────────────
cat("\n══ SCENARIO A: Cholesky (recursive identification) ══════════\n")
cat("Ordering: EPU_change [1] → fed_change [2] → vix_change [3]",
    "→ dxy_return [4] → gold_return [5]\n")
cat("Assumption: structural EPU shock affects gold contemporaneously;",
    "gold does not cause EPU within same trading day.\n\n")

irf_A_full <- irf(var_fit,
                  impulse  = "epu_change",
                  response = "gold_return",
                  n.ahead  = 20,
                  ortho    = TRUE,       # Cholesky orthogonalisation
                  boot     = TRUE,
                  ci       = 0.90,
                  runs     = 500)

# sub-sample SVARs at 2001-08-01 break
var_pre  <- VAR(ymat[1:BREAK_IDX, ], p = k_use, type = "const")
var_post <- VAR(ymat[(BREAK_IDX+1):nrow(ymat), ], p = k_use, type = "const")
irf_A_pre  <- irf(var_pre,  impulse="epu_change", response="gold_return",
                  n.ahead=20, ortho=TRUE, boot=TRUE, ci=0.90, runs=300)
irf_A_post <- irf(var_post, impulse="epu_change", response="gold_return",
                  n.ahead=20, ortho=TRUE, boot=TRUE, ci=0.90, runs=300)

# Rescale: standardised IRF → original gold_return units
# irf_std is gold_std per epu_std shock; multiply by SD_gold to get gold units
# (epu_std shock = 1 unit of standardised EPU = SD_epu raw EPU; already 1-SD shock)
rescale_A <- function(x) x * SD_gold
irf_A_pt  <- rescale_A(irf_A_full$irf$epu_change[, "gold_return"])
irf_A_lo  <- rescale_A(irf_A_full$Lower$epu_change[, "gold_return"])
irf_A_hi  <- rescale_A(irf_A_full$Upper$epu_change[, "gold_return"])

cat("Scenario A — Full sample (h=0 to h=5) [gold_return per 1-SD EPU shock]:\n")
for (h in 0:5)
  cat(sprintf("  h=%2d: %.4e  [%.4e, %.4e]\n",
              h, irf_A_pt[h+1], irf_A_lo[h+1], irf_A_hi[h+1]))

## ── SCENARIO B: Sign-Restricted SVAR ────────────────────────
cat("\n══ SCENARIO B: Sign-Restricted SVAR ═════════════════════════\n")
cat("Restriction: structural EPU shock → epu_change↑, vix_change↑\n")
cat("Gold response UNRESTRICTED — let the data speak.\n\n")

# Manual rotation algorithm (no VARsignR dependency)
# Draw Q ∈ O(5) via QR of random normal matrix (Haar measure)
# Sign restrictions (column 1 = EPU shock):
#   B[epu_col, 1] > 0  AND  B[vix_col, 1] > 0
# NO diagonal dominance check — it kills ~99% of draws unnecessarily.
# Gold response (row 5) fully unrestricted.
set.seed(42)
N_DRAWS  <- 8000
H_MAX    <- 20
gold_col <- 5
epu_col  <- 1
vix_col  <- 3

# ── Pre-compute VMA matrices OUTSIDE the draw loop (efficiency + correctness) ──
# For a VAR(k) with n variables, companion matrix is (n*k) × (n*k).
# VMA_h = top-left (n × n) block of Phi_comp^h.
n_vars   <- 5
k_lags   <- k_use
A_list   <- Acoef(var_fit)   # list of k matrices, each 5×5

Phi_comp <- matrix(0, n_vars * k_lags, n_vars * k_lags)
for (i in seq_len(k_lags))
  Phi_comp[1:n_vars, ((i-1)*n_vars + 1):(i*n_vars)] <- A_list[[i]]
if (k_lags > 1)
  Phi_comp[(n_vars+1):(n_vars*k_lags), 1:(n_vars*(k_lags-1))] <- diag(n_vars*(k_lags-1))

# Build VMA list: VMA[[h+1]] = top-left 5×5 block of Phi_comp^h
VMA         <- vector("list", H_MAX + 1)
Phi_pow_h   <- diag(n_vars * k_lags)
VMA[[1]]    <- Phi_pow_h[1:n_vars, 1:n_vars]      # h=0: identity (5×5)
for (h in seq_len(H_MAX)) {
  Phi_pow_h   <- Phi_pow_h %*% Phi_comp
  VMA[[h+1]]  <- Phi_pow_h[1:n_vars, 1:n_vars]
}
cat(sprintf("  VMA matrices pre-computed: h = 0 to %d\n", H_MAX))

accepted_irfs_B <- matrix(NA_real_, nrow = N_DRAWS, ncol = H_MAX + 1)
n_accepted      <- 0L
pb_step         <- max(1L, floor(N_DRAWS / 10))

for (d in seq_len(N_DRAWS)) {
  if (d %% pb_step == 0)
    cat(sprintf("  Draw %d / %d | accepted: %d\n", d, N_DRAWS, n_accepted))

  # SVD-based Haar measure: svd(random normal) → U %*% t(V) is Haar-uniform.
  # IMPORTANT: Do NOT use qr.Q(qr(.)) — R's Householder convention forces
  # Q[j,j] ≤ 0 always (LAPACK sign rule), making B[epu_col,1] always ≤ 0.
  # SVD has no such bias: P(Q[i,j] > 0) = 0.5 for all elements.
  sv    <- svd(matrix(rnorm(n_vars^2), n_vars, n_vars))
  Q     <- sv$u %*% t(sv$v)                # Haar-uniform on O(5)
  if (det(Q) < 0) Q[, 1] <- -Q[, 1]       # project to SO(5)

  B <- P_chol %*% Q                         # structural impact matrix 5×5

  # Pure sign restrictions only (no diagonal dominance):
  if (B[epu_col, 1] > 0 && B[vix_col, 1] > 0) {
    b1       <- B[, 1]                      # first structural shock vector
    # IRF at each horizon: (VMA_h %*% b1)[gold_col]
    irf_gold <- vapply(VMA, function(Ph) Ph[gold_col, ] %*% b1, numeric(1))
    n_accepted <- n_accepted + 1L
    accepted_irfs_B[n_accepted, ] <- irf_gold * SD_gold   # de-standardise
  }
}

accepted_irfs_B <- accepted_irfs_B[seq_len(n_accepted), , drop = FALSE]
cat(sprintf("\n  Acceptance rate: %d / %d = %.1f%%\n",
            n_accepted, N_DRAWS, 100 * n_accepted / N_DRAWS))

irf_B_med <- apply(accepted_irfs_B, 2, median)
irf_B_lo  <- apply(accepted_irfs_B, 2, quantile, 0.05)
irf_B_hi  <- apply(accepted_irfs_B, 2, quantile, 0.95)

cat("\nScenario B — Sign-restricted median (h=0 to h=5):\n")
for (h in 0:5)
  cat(sprintf("  h=%2d: %.4e  [%.4e, %.4e]\n", h,
              irf_B_med[h+1], irf_B_lo[h+1], irf_B_hi[h+1]))

## ── SCENARIO C: Local Projections with Pre-Determined EPU ───
cat("\n══ SCENARIO C: Local Projections (pre-determined EPU) ════════\n")
cat("Identification: use EPU_change_{t-1} to avoid contemporaneous endogeneity.\n")
cat("First stage: epu_change_t ~ epu_change_{t-1} (instrument relevance).\n\n")

n_obs     <- nrow(df_clean)
# Construct pre-determined EPU (lag 1)
lag_epu   <- c(NA, df_clean$epu_change[-n_obs])
lag_fed   <- c(NA, df_clean$fed_change[-n_obs])
lag_vix   <- c(NA, df_clean$vix_change[-n_obs])
lag_dxy   <- c(NA, df_clean$dxy_return[-n_obs])

df_lp <- data.frame(
  date       = df_clean$DATE,
  gold       = df_clean$gold_return,
  epu        = df_clean$epu_change,
  fed        = df_clean$fed_change,
  vix        = df_clean$vix_change,
  dxy        = df_clean$dxy_return,
  lag_epu    = lag_epu,
  lag_fed    = lag_fed,
  lag_vix    = lag_vix,
  lag_dxy    = lag_dxy
)
df_lp <- na.omit(df_lp)

# First stage: instrument relevance
fs  <- lm(epu ~ lag_epu + lag_fed + lag_vix + lag_dxy, data = df_lp)
cat(sprintf("First-stage F-stat (instrument relevance): %.2f  (rule-of-thumb: >10)\n",
            summary(fs)$fstatistic[1]))
epu_hat <- fitted(fs)

# Local projections at each horizon using predicted EPU (2-stage LP)
irf_C_pt  <- numeric(H_MAX + 1)
irf_C_lo  <- numeric(H_MAX + 1)
irf_C_hi  <- numeric(H_MAX + 1)
n_lp      <- nrow(df_lp)

for (h in 0:H_MAX) {
  if (h <= n_lp - 2) {
    y_h     <- df_lp$gold[(h+1):n_lp]   # gold_{t+h}
    epu_h   <- epu_hat[1:(n_lp - h)]     # fitted EPU_t
    fed_h   <- df_lp$fed[1:(n_lp - h)]
    vix_h   <- df_lp$vix[1:(n_lp - h)]
    dxy_h   <- df_lp$dxy[1:(n_lp - h)]
    lp_df   <- data.frame(y=y_h, epu=epu_h, fed=fed_h, vix=vix_h, dxy=dxy_h)
    lp_fit  <- lm(y ~ epu + fed + vix + dxy, data = lp_df)
    cf      <- coef(summary(lp_fit))["epu", ]
    se      <- cf["Std. Error"]
    irf_C_pt[h+1] <- cf["Estimate"]
    irf_C_lo[h+1] <- cf["Estimate"] - 1.645 * se   # 90% CI
    irf_C_hi[h+1] <- cf["Estimate"] + 1.645 * se
  }
}

cat("\nScenario C — LP pre-determined (h=0 to h=5):\n")
for (h in 0:5)
  cat(sprintf("  h=%2d: %.4e  [%.4e, %.4e]\n", h,
              irf_C_pt[h+1], irf_C_lo[h+1], irf_C_hi[h+1]))

## ── COMPARISON TABLE ────────────────────────────────────────
cat("\n══ IRF COMPARISON TABLE (h=0,1,5,10,20) ═══════════════════\n")
cat("Units: gold_return per 1-SD structural EPU shock\n")
cat(sprintf("%-5s | %-14s | %-14s | %-14s\n",
            "h", "A: Cholesky", "B: Sign-Restr", "C: LP-predet"))
cat(strrep("-", 60), "\n")
for (h in c(0, 1, 5, 10, 20)) {
  a  <- irf_A_pt[h+1]
  b  <- if (n_accepted > 0) irf_B_med[h+1] else NA
  cc <- irf_C_pt[h+1] * SD_gold / SD_epu   # rescale LP to same units
  cat(sprintf("h=%2d  | %+.4e      | %s      | %+.4e\n",
              h, a, if (is.na(b)) "      NA      " else sprintf("%+.4e", b), cc))
}

## ── QIRF: Quantile Impulse Response Functions ───────────────
cat("\n══ QIRF: Quantile Local Projections from Scenario A ════════\n")
cat("Structural EPU shocks extracted from Cholesky SVAR.\n")
cat("Local projections at τ ∈ {0.05,0.10,0.25,0.50,0.75,0.90,0.95}\n\n")

# Extract structural EPU shocks from Cholesky A (from standardised VAR)
# Structural shocks are in standardised units (SD=1 for each shock by construction)
struct_shocks <- resid_rf %*% solve(t(P_chol))   # N × 5 structural residuals
epu_struct    <- struct_shocks[, 1]               # EPU structural shock (std units)

# Use ORIGINAL (raw) gold_return for QIRF so coefficients are interpretable
# as gold_return (raw) per 1-SD structural EPU shock
raw_gold_return <- df_clean$gold_return    # original scale

TAUS      <- c(0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95)
qirf_mat  <- matrix(NA_real_, nrow = H_MAX + 1, ncol = length(TAUS))
colnames(qirf_mat) <- paste0("tau_", TAUS)

n_str <- length(epu_struct)
# Alignment: VAR with p=k_use lags loses k_use rows from the front of ymat.
# resid_rf has nrow(ymat) - k_use rows. Corresponding original gold:
gold_aligned <- raw_gold_return[(k_use + 1):length(raw_gold_return)]
stopifnot(length(epu_struct) == length(gold_aligned))

for (h in 0:H_MAX) {
  T_eff   <- n_str - h
  shock_h <- epu_struct[1:T_eff]
  gold_h  <- gold_aligned[(h+1):(h+T_eff)]
  if (length(shock_h) != length(gold_h)) next
  for (j in seq_along(TAUS)) {
    qfit <- rq(gold_h ~ shock_h, tau = TAUS[j], method = "br")
    qirf_mat[h+1, j] <- coef(qfit)["shock_h"]
  }
}

cat("QIRF at h=0 (impact response by quantile):\n")
cat(sprintf("%-10s | %-12s | %-10s\n", "tau", "beta (QIRF)", "sign"))
for (j in seq_along(TAUS))
  cat(sprintf("tau=%.2f   | %+.4e   | %s\n", TAUS[j], qirf_mat[1, j],
              ifelse(qirf_mat[1, j] > 0, "↑ safe-haven", "↓ deleveraging")))

sign_reversal_h0 <- qirf_mat[1, 1] < 0 && qirf_mat[1, length(TAUS)] > 0
cat(sprintf("\nMonotone sign reversal at h=0: %s\n",
            ifelse(sign_reversal_h0, "✅ CONFIRMED (mirrors QR Table 3)", "⚠️ NOT confirmed")))

## ── FIGURES ─────────────────────────────────────────────────
cat("\n── Generating figures ────────────────────────────────────────\n")

## Figure 3: Three-scenario IRF comparison
h_seq <- 0:H_MAX
# C: rescale LP to same units as A (gold_return per 1-SD EPU shock)
lp_scale <- SD_gold / SD_epu
df_fig3 <- rbind(
  data.frame(h = h_seq, irf = irf_A_pt, lo = irf_A_lo, hi = irf_A_hi,
             scenario = "A: Cholesky (recursive)"),
  data.frame(h = h_seq,
             irf = if (n_accepted > 0) irf_B_med else rep(NA, H_MAX+1),
             lo  = if (n_accepted > 0) irf_B_lo  else rep(NA, H_MAX+1),
             hi  = if (n_accepted > 0) irf_B_hi  else rep(NA, H_MAX+1),
             scenario = "B: Sign-restricted"),
  data.frame(h = h_seq, irf = irf_C_pt * lp_scale,
             lo = irf_C_lo * lp_scale, hi = irf_C_hi * lp_scale,
             scenario = "C: LP pre-determined EPU")
)

fig3_colors <- c("A: Cholesky (recursive)"     = "#1f77b4",
                 "B: Sign-restricted"           = "#d62728",
                 "C: LP pre-determined EPU"     = "#2ca02c")

p3 <- ggplot(df_fig3, aes(x = h, y = irf, colour = scenario, fill = scenario)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = 0, linetype = "dotted", colour = "grey70") +
  scale_colour_manual(values = fig3_colors) +
  scale_fill_manual(values = fig3_colors) +
  labs(
    title    = "Figure 3: Gold Return IRF to 1-SD Structural EPU Shock",
    subtitle = "Three identification schemes | 90% confidence bands | N=12,207 daily obs, 1980–2026",
    x        = "Horizon (trading days)",
    y        = "Gold return response",
    colour   = NULL, fill = NULL,
    caption  = "A=Cholesky (EPU first); B=Sign-restricted (EPU↑ & VIX↑; gold unrestricted); C=LP with pre-determined EPU_{t−1}"
  ) +
  scale_x_continuous(breaks = seq(0, 20, 5)) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title       = element_text(face = "bold"),
        panel.grid.minor = element_blank())

ggsave(file.path(FIG_DIR, "fig3_svar_comparison.png"), p3,
       width = 8, height = 5, dpi = 300)
ggsave(file.path(FIG_DIR, "fig3_svar_comparison.tiff"), p3,
       width = 8, height = 5, dpi = 300)
cat("  ✅ fig3_svar_comparison.png + .tiff saved\n")

## Figure 4: QIRF surface (heatmap)
df_qirf <- as.data.frame(qirf_mat)
df_qirf$h <- 0:H_MAX
df_qirf_long <- melt(df_qirf, id.vars = "h", variable.name = "tau", value.name = "beta")
df_qirf_long$tau_num <- as.numeric(sub("tau_", "", df_qirf_long$tau))

p4 <- ggplot(df_qirf_long, aes(x = h, y = factor(tau_num), fill = beta)) +
  geom_tile() +
  scale_fill_gradient2(
    low      = "#d62728",   # negative = deleveraging = red
    mid      = "white",
    high     = "#1f77b4",   # positive = safe-haven = blue
    midpoint = 0,
    name     = "β(τ,h)"
  ) +
  geom_text(aes(label = sprintf("%.1e", beta)), size = 2.2, colour = "grey30") +
  labs(
    title    = "Figure 4: Quantile IRF Surface — EPU Shock → Gold Return",
    subtitle = "Structural shocks from Scenario A (Cholesky) | τ = quantile of gold return",
    x        = "Horizon (trading days)",
    y        = "Quantile τ",
    caption  = "Red = deleveraging channel (lower tail); Blue = safe-haven channel (upper tail)"
  ) +
  scale_x_continuous(breaks = seq(0, 20, 5)) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"),
        axis.text.y = element_text(size = 9))

ggsave(file.path(FIG_DIR, "fig4_qirf_surface.png"), p4,
       width = 9, height = 5, dpi = 300)
ggsave(file.path(FIG_DIR, "fig4_qirf_surface.tiff"), p4,
       width = 9, height = 5, dpi = 300)
cat("  ✅ fig4_qirf_surface.png + .tiff saved\n")

## Figure 5: Sub-sample comparison (pre vs post 2001 break) — Scenario A
df_fig5 <- rbind(
  data.frame(h = h_seq, irf = irf_A_pt, lo = irf_A_lo, hi = irf_A_hi,
             period = "Full sample (1980–2026)"),
  data.frame(h = h_seq,
             irf = rescale_A(irf_A_pre$irf$epu_change[, "gold_return"]),
             lo  = rescale_A(irf_A_pre$Lower$epu_change[, "gold_return"]),
             hi  = rescale_A(irf_A_pre$Upper$epu_change[, "gold_return"]),
             period = "Pre-break (1980–2001)"),
  data.frame(h = h_seq,
             irf = rescale_A(irf_A_post$irf$epu_change[, "gold_return"]),
             lo  = rescale_A(irf_A_post$Lower$epu_change[, "gold_return"]),
             hi  = rescale_A(irf_A_post$Upper$epu_change[, "gold_return"]),
             period = "Post-break (2001–2026)")
)

p5 <- ggplot(df_fig5, aes(x = h, y = irf, colour = period, fill = period)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = c("Full sample (1980–2026)"  = "grey40",
                                 "Pre-break (1980–2001)"    = "#d62728",
                                 "Post-break (2001–2026)"   = "#1f77b4")) +
  scale_fill_manual(values = c("Full sample (1980–2026)"  = "grey40",
                                "Pre-break (1980–2001)"    = "#d62728",
                                "Post-break (2001–2026)"   = "#1f77b4")) +
  labs(
    title    = "Figure 5: Structural Break in EPU→Gold IRF at 2001-08-01",
    subtitle = "Scenario A (Cholesky) | 90% bootstrap CI | Sub-sample SVARs",
    x = "Horizon (trading days)", y = "Gold return response",
    colour = NULL, fill = NULL,
    caption = "Break date: 2001-08-01 (supF=255.49, p<0.001, R strucchange)"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank())

ggsave(file.path(FIG_DIR, "fig5_subsample_irf.png"), p5,
       width = 8, height = 5, dpi = 300)
ggsave(file.path(FIG_DIR, "fig5_subsample_irf.tiff"), p5,
       width = 8, height = 5, dpi = 300)
cat("  ✅ fig5_subsample_irf.png + .tiff saved\n")

## ── Write text results ──────────────────────────────────────
lines_out <- c(
  "======================================================================",
  " SVAR Identification Comparison — P3 Gold × EPU",
  " Three Scenarios: A=Cholesky | B=Sign-Restricted | C=LP pre-det.",
  "======================================================================",
  sprintf(" N = %d | %s to %s | break obs %d (%s)",
          nrow(df_clean), min(df_clean$DATE), max(df_clean$DATE),
          BREAK_IDX, df_clean$DATE[BREAK_IDX]),
  sprintf(" VAR lag k = %d (AIC, capped at 10)", k_use),
  "----------------------------------------------------------------------",
  "",
  "SCENARIO A: Cholesky (Recursive)",
  sprintf("  h=0  impact: %+.4e  [%+.4e, %+.4e]",
          irf_A_full$irf$epu_change[1, "gold_return"],
          irf_A_full$Lower$epu_change[1, "gold_return"],
          irf_A_full$Upper$epu_change[1, "gold_return"]),
  sprintf("  h=5  impact: %+.4e  [%+.4e, %+.4e]",
          irf_A_full$irf$epu_change[6, "gold_return"],
          irf_A_full$Lower$epu_change[6, "gold_return"],
          irf_A_full$Upper$epu_change[6, "gold_return"]),
  sprintf("  h=20 impact: %+.4e  [%+.4e, %+.4e]",
          irf_A_full$irf$epu_change[21, "gold_return"],
          irf_A_full$Lower$epu_change[21, "gold_return"],
          irf_A_full$Upper$epu_change[21, "gold_return"]),
  "",
  "SCENARIO B: Sign-Restricted (median over accepted draws)",
  sprintf("  Acceptance rate: %d / %d = %.1f%%", n_accepted, N_DRAWS,
          100 * n_accepted / N_DRAWS),
  sprintf("  h=0  median: %+.4e  [%+.4e, %+.4e]",
          irf_B_med[1], irf_B_lo[1], irf_B_hi[1]),
  sprintf("  h=5  median: %+.4e  [%+.4e, %+.4e]",
          irf_B_med[6], irf_B_lo[6], irf_B_hi[6]),
  "",
  "SCENARIO C: LP with pre-determined EPU_{t-1}",
  sprintf("  First-stage F: %.2f", summary(fs)$fstatistic[1]),
  sprintf("  h=0  estimate: %+.4e  [%+.4e, %+.4e]",
          irf_C_pt[1], irf_C_lo[1], irf_C_hi[1]),
  sprintf("  h=5  estimate: %+.4e  [%+.4e, %+.4e]",
          irf_C_pt[6], irf_C_lo[6], irf_C_hi[6]),
  "",
  "QIRF at h=0 (Scenario A structural shocks):",
  paste(sprintf("  tau=%.2f: %+.4e", TAUS, qirf_mat[1,]), collapse="\n"),
  sprintf("  Monotone sign reversal confirmed: %s", sign_reversal_h0),
  "",
  "FIGURES SAVED:",
  "  fig3_svar_comparison.png/tiff",
  "  fig4_qirf_surface.png/tiff",
  "  fig5_subsample_irf.png/tiff",
  "======================================================================\n"
)
writeLines(lines_out, OUT_TXT)
cat(sprintf("\n✅ Results written: %s\n", basename(OUT_TXT)))
cat("══ SVAR Comparison COMPLETE ════════════════════════════════════\n\n")
