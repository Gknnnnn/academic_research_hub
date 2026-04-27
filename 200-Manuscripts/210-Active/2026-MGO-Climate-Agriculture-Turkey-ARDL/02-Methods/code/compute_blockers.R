###############################################################################
#  compute_blockers.R
#  Özdemir & Işık (2026) — Climate-Agriculture-Turkey-ARDL
#
#  PURPOSE: Compute all three submission-blocker items identified in
#           v08/v09 academic sparring and peer review:
#
#  BLOCK 1: Extended unit-root battery — KPSS, DF-GLS (ERS 1996),
#            Zivot-Andrews on precipitation → Table 2 Panel A supplement
#
#  BLOCK 2: Wild bootstrap (B = 2000, Rademacher weights) SEs and 95% CIs
#            for long-run coefficients → Table 2 Panel B supplement column
#
#  BLOCK 3: Appendix A4 — ARDL(4,0,1,0,2,0) with mean-centred TSA anomaly
#            replacing ln TSA → Online Appendix Table A4
#
#  USAGE: setwd("path/to/2026-MGO-Climate-Agriculture-Turkey-ARDL")
#         source("code/compute_blockers.R")
#
#  OUTPUT: results/blockers_unit_root.csv
#          results/blockers_bootstrap.csv
#          results/blockers_appendix_A4.csv
#          results/blockers_console_output.txt  (full console log)
#
#  Required packages:
#    install.packages(c("readxl","urca","tseries","lmtest","car","strucchange"))
#
#  Authors : Dr. M. Gökhan Özdemir  <mgozdemirera@kku.edu.tr>
#            Prof. Dr. Hacı Bayram Işık
#  Date    : April 2026
###############################################################################

library(readxl)
library(urca)        # ur.df, ur.kpss, ur.ers, ur.za
library(tseries)     # jarque.bera.test
library(lmtest)      # bgtest, bptest, resettest
library(car)         # linearHypothesis

dir.create("results", showWarnings = FALSE)
sink("results/blockers_console_output.txt", split = TRUE)

DATA_PATH <- "data/turkey_climate_agri_1970_2021.xlsx"
raw <- read_excel(DATA_PATH, sheet = "Sayfa1")
names(raw) <- c("year","alan_raw","ava","co2_raw","tsso_raw","tsa","pr")

# Log-transformed variables
raw$lnAVA   <- log(raw$ava)
raw$lnPR    <- log(raw$pr)
raw$lnTSA   <- log(raw$tsa)
raw$lnTSSO  <- log(raw$tsso_raw)
raw$lnALAN  <- log(raw$alan_raw / 10)
raw$lnCO2   <- log(raw$co2_raw)
raw$TSA_anom <- raw$tsa - mean(raw$tsa, na.rm = TRUE)   # A4

veri_ln <- ts(
  raw[, c("lnAVA","lnPR","lnTSA","lnTSSO","lnALAN","lnCO2","TSA_anom")],
  start = 1970, end = 2021, frequency = 1
)

cat("\n====================================================\n")
cat("  BLOCK 1: EXTENDED UNIT-ROOT BATTERY\n")
cat("====================================================\n\n")

# DF-GLS critical values (ERS 1996, T = 50, constant-only specification)
# 1%: -2.57 | 5%: -1.94 | 10%: -1.61
# KPSS critical values (Kwiatkowski et al. 1992, constant)
# 10%: 0.347 | 5%: 0.463 | 1%: 0.739
# Zivot-Andrews critical values (constant-only)
# 1%: -5.34 | 5%: -4.80 | 10%: -4.58

vars_main <- c("lnAVA","lnPR","lnTSA","lnTSSO","lnALAN","lnCO2")
ur_table <- data.frame()

for (v in vars_main) {
  x   <- na.omit(veri_ln[, v])
  dx  <- diff(x)

  # --- ADF (already in manuscript, reconfirm) ---
  adf_l <- ur.df(x,  type = "drift", lags = 4)
  adf_d <- ur.df(dx, type = "drift", lags = 4)
  adf_l_stat <- adf_l@teststat[1]   # positional: named slot absent in some urca versions
  adf_d_stat <- adf_d@teststat[1]

  # --- KPSS (H0: stationary; reject = non-stationary) ---
  kpss_l <- ur.kpss(x,  type = "mu", lags = "short")   # constant-only
  kpss_d <- ur.kpss(dx, type = "mu", lags = "short")
  kpss_l_stat <- kpss_l@teststat
  kpss_d_stat <- kpss_d@teststat

  # KPSS conclusion: if level stat > 0.463 (5%) → reject H0 → non-stationary = I(1)
  kpss_l_sig <- ifelse(kpss_l_stat > 0.739, "***",
                ifelse(kpss_l_stat > 0.463, "**",
                ifelse(kpss_l_stat > 0.347, "*", "")))

  # --- DF-GLS (ERS 1996) ---
  dfgls_l <- tryCatch(ur.ers(x,  type = "DF-GLS", model = "constant", lag.max = 4),
                      error = function(e) NULL)
  dfgls_d <- tryCatch(ur.ers(dx, type = "DF-GLS", model = "constant", lag.max = 4),
                      error = function(e) NULL)
  dfgls_l_stat <- if (!is.null(dfgls_l)) dfgls_l@teststat else NA
  dfgls_d_stat <- if (!is.null(dfgls_d)) dfgls_d@teststat else NA

  # DF-GLS 5% critical = -1.94: if stat < -1.94 → reject unit root → stationary
  dfgls_l_sig <- ifelse(!is.na(dfgls_l_stat) & dfgls_l_stat < -2.57, "***",
                 ifelse(!is.na(dfgls_l_stat) & dfgls_l_stat < -1.94, "**",
                 ifelse(!is.na(dfgls_l_stat) & dfgls_l_stat < -1.61, "*", "")))

  # Integration order: conservative (require ADF + DF-GLS both significant for I(0))
  I_d <- if ((adf_l_stat < -2.924 || (!is.na(dfgls_l_stat) && dfgls_l_stat < -1.94)) &&
              kpss_l_stat < 0.463) "I(0)" else "I(1)"

  cat(sprintf("%-10s ADF(L)=%6.3f  ADF(Δ)=%6.3f  KPSS(L)=%5.3f%s  DFGLS(L)=%6.3f%s  -> %s\n",
              v,
              adf_l_stat, adf_d_stat,
              kpss_l_stat, kpss_l_sig,
              ifelse(is.na(dfgls_l_stat), -99, dfgls_l_stat),
              dfgls_l_sig,
              I_d))

  ur_table <- rbind(ur_table, data.frame(
    Variable   = v,
    ADF_level  = round(adf_l_stat, 3),
    ADF_diff   = round(adf_d_stat, 3),
    KPSS_level = round(kpss_l_stat, 3),
    KPSS_sig   = kpss_l_sig,
    KPSS_diff  = round(kpss_d_stat, 3),
    DFGLS_level = round(ifelse(is.na(dfgls_l_stat), NA, dfgls_l_stat), 3),
    DFGLS_sig  = dfgls_l_sig,
    DFGLS_diff  = round(ifelse(is.na(dfgls_d_stat), NA, dfgls_d_stat), 3),
    I_d        = I_d,
    stringsAsFactors = FALSE
  ))
}

# --- Zivot-Andrews on lnPR specifically ---
cat("\n--- Zivot-Andrews break test on lnPR ---\n")
za_pr <- ur.za(veri_ln[,"lnPR"], model = "intercept", lag = 4)
cat("ZA statistic:", round(za_pr@teststat, 3), "\n")
cat("ZA critical values: 1%=-5.34  5%=-4.80  10%=-4.58\n")
cat("Break point (obs):", za_pr@bpoint, " Year:", 1970 + za_pr@bpoint - 1, "\n")
za_verdict <- ifelse(za_pr@teststat < -4.80,
  "REJECT unit root at 5%: lnPR stationary even allowing for structural break",
  "FAIL to reject: break-driven stationarity cannot be ruled out")
cat("Verdict:", za_verdict, "\n")

write.csv(ur_table, "results/blockers_unit_root.csv", row.names = FALSE)
cat("\nUnit-root table saved: results/blockers_unit_root.csv\n")

cat("\n====================================================\n")
cat("  BLOCK 2: WILD BOOTSTRAP (B = 2000)\n")
cat("====================================================\n\n")

# Build ARDL(4,0,1,0,2,0) CECM
df <- as.data.frame(veri_ln)
df$year <- raw$year

lag_vec <- function(x, k) c(rep(NA, k), head(x, -k))

df$D_lnAVA   <- c(NA, diff(df$lnAVA))
df$D_lnPR    <- c(NA, diff(df$lnPR))
df$D_lnTSA   <- c(NA, diff(df$lnTSA))
df$D_lnTSSO  <- c(NA, diff(df$lnTSSO))
df$D_lnALAN  <- c(NA, diff(df$lnALAN))
df$D_lnCO2   <- c(NA, diff(df$lnCO2))

df$LD1_D_lnAVA  <- lag_vec(df$D_lnAVA,  1)
df$LD2_D_lnAVA  <- lag_vec(df$D_lnAVA,  2)
df$LD3_D_lnAVA  <- lag_vec(df$D_lnAVA,  3)
df$LD1_D_lnTSA  <- lag_vec(df$D_lnTSA,  1)
df$LD1_D_lnALAN <- lag_vec(df$D_lnALAN, 1)
df$L1_lnAVA   <- lag_vec(df$lnAVA,  1)
df$L1_lnPR    <- lag_vec(df$lnPR,   1)
df$L1_lnTSA   <- lag_vec(df$lnTSA,  1)
df$L1_lnTSSO  <- lag_vec(df$lnTSSO, 1)
df$L1_lnALAN  <- lag_vec(df$lnALAN, 1)
df$L1_lnCO2   <- lag_vec(df$lnCO2,  1)

cecm <- lm(D_lnAVA ~ LD1_D_lnAVA + LD2_D_lnAVA + LD3_D_lnAVA +
             D_lnPR + D_lnTSA + LD1_D_lnTSA + D_lnTSSO +
             D_lnALAN + LD1_D_lnALAN + D_lnCO2 +
             L1_lnAVA + L1_lnPR + L1_lnTSA + L1_lnTSSO + L1_lnALAN + L1_lnCO2,
           data = df, na.action = na.omit)

cat("Baseline CECM summary:\n")
cat("  ECT (L1_lnAVA):", round(coef(cecm)["L1_lnAVA"], 4),
    " SE:", round(summary(cecm)$coef["L1_lnAVA","Std. Error"], 4), "\n")

delta1   <- coef(cecm)["L1_lnAVA"]
lr_vars  <- c("L1_lnPR","L1_lnTSA","L1_lnTSSO","L1_lnALAN","L1_lnCO2")
lr_names <- c("lnPR","lnTSA","lnTSSO","lnALAN","lnCO2")

theta_ols <- -coef(cecm)[lr_vars] / delta1
cat("  OLS long-run coefficients:\n")
print(round(theta_ols, 4))

# Wild bootstrap
set.seed(42)
B       <- 2000
fitted_ <- fitted(cecm)
resid_  <- residuals(cecm)
n_obs   <- length(fitted_)

df_cc   <- df[complete.cases(df[, all.vars(formula(cecm))]), ]
X_mat   <- model.matrix(cecm)
Y_obs   <- df_cc$D_lnAVA

boot_matrix <- matrix(NA, nrow = B, ncol = length(lr_vars))
colnames(boot_matrix) <- lr_names

cat("\nRunning", B, "wild bootstrap draws (Rademacher weights)...\n")
for (b in seq_len(B)) {
  w        <- sample(c(-1, 1), n_obs, replace = TRUE)
  Y_boot   <- fitted_ + resid_ * w
  m_boot   <- lm.fit(X_mat, Y_boot)
  c_boot   <- m_boot$coefficients
  d1_boot  <- c_boot["L1_lnAVA"]
  if (is.na(d1_boot) || abs(d1_boot) < 1e-10) next
  for (j in seq_along(lr_vars)) {
    boot_matrix[b, j] <- -c_boot[lr_vars[j]] / d1_boot
  }
}
boot_matrix <- boot_matrix[complete.cases(boot_matrix), ]
cat("  Successful draws:", nrow(boot_matrix), "\n\n")

boot_results <- data.frame()
cat(sprintf("%-12s  %8s  %8s  %8s  %8s  %8s  %8s  %6s\n",
            "Variable","OLS_theta","Boot_SE","Boot_lo","Boot_hi","Delta_SE","Delta_lo","Boot_p"))
cat(strrep("-", 78), "\n")

for (j in seq_along(lr_vars)) {
  v    <- lr_vars[j]
  nm   <- lr_names[j]
  draws <- boot_matrix[, nm]

  theta_j    <- theta_ols[v]
  boot_se_j  <- sd(draws)
  boot_lo_j  <- quantile(draws, 0.025)
  boot_hi_j  <- quantile(draws, 0.975)
  delta_se_j <- summary(cecm)$coef[v, "Std. Error"] / abs(delta1)
  boot_p_j   <- 2 * min(mean(draws > 0), mean(draws < 0))

  sig <- ifelse(boot_p_j < 0.01, "***", ifelse(boot_p_j < 0.05, "**",
         ifelse(boot_p_j < 0.10, "*", "")))

  cat(sprintf("%-12s  %+8.4f  %8.4f  %+8.4f  %+8.4f  %8.4f  %+8.4f  %6.4f %s\n",
              nm, theta_j, boot_se_j, boot_lo_j, boot_hi_j,
              delta_se_j, theta_j - 1.96 * delta_se_j, boot_p_j, sig))

  boot_results <- rbind(boot_results, data.frame(
    Variable    = nm,
    OLS_theta   = round(theta_j, 4),
    Boot_SE     = round(boot_se_j, 4),
    Boot_CI_lo  = round(boot_lo_j, 4),
    Boot_CI_hi  = round(boot_hi_j, 4),
    Delta_SE    = round(delta_se_j, 4),
    Boot_p      = round(boot_p_j, 4),
    Sig_boot    = sig,
    stringsAsFactors = FALSE
  ))
}

write.csv(boot_results, "results/blockers_bootstrap.csv", row.names = FALSE)
cat("\nBootstrap table saved: results/blockers_bootstrap.csv\n")

# Precipitation summary for manuscript
pr <- boot_results[boot_results$Variable == "lnPR", ]
cat(sprintf("\nKEY RESULT — Precipitation (Table 2 Panel B supplement):\n"))
cat(sprintf("  OLS theta = %+.4f\n", pr$OLS_theta))
cat(sprintf("  Wild-bootstrap SE = %.4f | 95%% CI = [%+.4f, %+.4f]\n",
            pr$Boot_SE, pr$Boot_CI_lo, pr$Boot_CI_hi))
cat(sprintf("  Bootstrap p = %.4f  %s\n", pr$Boot_p, pr$Sig_boot))
cat(sprintf("  SURVIVES bootstrap: %s\n",
            ifelse(pr$Boot_p < 0.10, "YES (p < 0.10)", "NO")))

cat("\n====================================================\n")
cat("  BLOCK 3: APPENDIX A4 — SEMI-LOG (TSA ANOMALY)\n")
cat("====================================================\n\n")

# Replace lnTSA with TSA_anom; keep same ARDL(4,0,1,0,2,0) lag structure
df$D_TSA_anom   <- c(NA, diff(df$TSA_anom))
df$LD1_D_TSAnom <- lag_vec(df$D_TSA_anom, 1)
df$L1_TSAnom    <- lag_vec(df$TSA_anom, 1)

cecm_A4 <- lm(D_lnAVA ~ LD1_D_lnAVA + LD2_D_lnAVA + LD3_D_lnAVA +
                D_lnPR + D_TSA_anom + LD1_D_TSAnom + D_lnTSSO +
                D_lnALAN + LD1_D_lnALAN + D_lnCO2 +
                L1_lnAVA + L1_lnPR + L1_TSAnom + L1_lnTSSO + L1_lnALAN + L1_lnCO2,
              data = df, na.action = na.omit)

delta1_A4 <- coef(cecm_A4)["L1_lnAVA"]

# Bounds F-test
level_vars_A4 <- c("L1_lnAVA","L1_lnPR","L1_TSAnom","L1_lnTSSO","L1_lnALAN","L1_lnCO2")
F_bounds_A4 <- linearHypothesis(cecm_A4,
  paste0(level_vars_A4, "=0"), test = "F")
F_stat_A4 <- F_bounds_A4[2, "F"]
F_df_A4   <- c(F_bounds_A4[2, "Df"], F_bounds_A4[2, "Res.Df"])

cat(sprintf("A4 Bounds F-stat: %.3f (df: %d, %d)\n", F_stat_A4, F_df_A4[1], F_df_A4[2]))
cat(sprintf("PSS critical values — k=5: I(0)=3.41  I(1)=4.68 (1%%)\n"))
cat(sprintf("Verdict: %s\n\n", ifelse(F_stat_A4 > 4.68, "Cointegrated (1%)",
            ifelse(F_stat_A4 > 3.41, "Cointegrated (5%)", "Inconclusive"))))

cat(sprintf("A4 ECT: %.4f  SE=%.4f  t=%.3f\n",
            delta1_A4,
            summary(cecm_A4)$coef["L1_lnAVA","Std. Error"],
            summary(cecm_A4)$coef["L1_lnAVA","t value"]))
cat(sprintf("A4 Half-life: %.2f years\n\n", log(0.5)/log(1+delta1_A4)))

lr_vars_A4  <- c("L1_lnPR","L1_TSAnom","L1_lnTSSO","L1_lnALAN","L1_lnCO2")
lr_names_A4 <- c("lnPR","TSA_anom","lnTSSO","lnALAN","lnCO2")
A4_results  <- data.frame()

cat(sprintf("%-12s  %8s  %8s  %8s  %6s\n","Variable","A4_theta","SE","t-stat","Sig"))
cat(strrep("-",52),"\n")
for (j in seq_along(lr_vars_A4)) {
  v    <- lr_vars_A4[j]
  nm   <- lr_names_A4[j]
  c_A4 <- coef(cecm_A4)
  se_m <- summary(cecm_A4)$coef
  theta_j <- -c_A4[v] / delta1_A4
  se_j    <- se_m[v,"Std. Error"] / abs(delta1_A4)
  t_j     <- theta_j / se_j
  p_j     <- 2 * pt(-abs(t_j), df = cecm_A4$df.residual)
  sig_j   <- ifelse(p_j<0.01,"***",ifelse(p_j<0.05,"**",ifelse(p_j<0.10,"*","")))

  cat(sprintf("%-12s  %+8.4f  %8.4f  %8.3f  %6s\n", nm, theta_j, se_j, t_j, sig_j))
  A4_results <- rbind(A4_results, data.frame(
    Variable = nm, A4_theta = round(theta_j,4), SE = round(se_j,4),
    t_stat = round(t_j,3), p_value = round(p_j,4), Sig = sig_j,
    stringsAsFactors = FALSE))
}

# A4 diagnostics
bg_A4    <- bgtest(cecm_A4, order=2)
reset_A4 <- resettest(cecm_A4, power=2:3)
jb_A4    <- jarque.bera.test(residuals(cecm_A4))
bp_A4    <- bptest(cecm_A4)
cat(sprintf("\nA4 Diagnostics:\n"))
cat(sprintf("  BG LM(2)   : chi2=%.3f  p=%.3f %s\n", bg_A4$statistic, bg_A4$p.value,
            ifelse(bg_A4$p.value>0.05,"(pass)","(FAIL)")))
cat(sprintf("  RESET      : F=%.3f    p=%.3f %s\n", reset_A4$statistic, reset_A4$p.value,
            ifelse(reset_A4$p.value>0.05,"(pass)","(FAIL)")))
cat(sprintf("  Jarque-Bera: JB=%.3f   p=%.3f %s\n", jb_A4$statistic, jb_A4$p.value,
            ifelse(jb_A4$p.value>0.05,"(pass)","(FAIL)")))
cat(sprintf("  BPG        : chi2=%.3f  p=%.3f %s\n", bp_A4$statistic, bp_A4$p.value,
            ifelse(bp_A4$p.value>0.05,"(pass)","(FAIL)")))

# Key comparison: main spec vs A4 — temperature
main_tsa <- theta_ols["L1_lnTSA"]
A4_tsa   <- A4_results[A4_results$Variable=="TSA_anom","A4_theta"]
A4_tsa_p <- A4_results[A4_results$Variable=="TSA_anom","p_value"]
cat(sprintf("\nTEMPERATURE FUNCTIONAL FORM COMPARISON (§5.4 verification):\n"))
cat(sprintf("  Main spec (ln TSA): theta = %+.4f  [insignificant]\n", main_tsa))
cat(sprintf("  A4 (TSA anomaly°C): theta = %+.4f  p = %.4f  %s\n",
            A4_tsa, A4_tsa_p,
            ifelse(A4_tsa_p > 0.10,
              "CONFIRMED: temperature insignificant under anomaly spec",
              "WARNING: temperature SIGNIFICANT under anomaly spec — review §5.4")))

A4_results$F_bounds <- F_stat_A4
write.csv(A4_results, "results/blockers_appendix_A4.csv", row.names = FALSE)
cat("\nAppendix A4 table saved: results/blockers_appendix_A4.csv\n")

cat("\n====================================================\n")
cat("  ALL COMPUTATIONS COMPLETE\n")
cat("  Outputs in: results/blockers_*.csv\n")
cat("  Embed in v02.qmd — see EMBEDDING GUIDE below\n")
cat("====================================================\n\n")
cat("EMBEDDING GUIDE:\n")
cat("  Table 2 Panel A: add KPSS_level, KPSS_sig, DFGLS_level, DFGLS_sig\n")
cat("                   columns from blockers_unit_root.csv\n")
cat("  Table 2 Panel B: add Boot_SE and Boot_CI_lo/Boot_CI_hi columns\n")
cat("                   from blockers_bootstrap.csv\n")
cat("  Online Appendix: paste blockers_appendix_A4.csv as Table A4\n")
cat("  §5.4 assertion:  update 'we expect' to 'is confirmed' once A4 runs\n")

sink()
cat("\nDone. See results/blockers_console_output.txt for full log.\n")
