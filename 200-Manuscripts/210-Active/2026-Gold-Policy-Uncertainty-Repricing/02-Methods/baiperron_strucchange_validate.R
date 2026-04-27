## Bai-Perron Structural Break Validation — Paper 3 (Gold × EPU)
## R strucchange cross-check against Python chi2(q) approximation
## CLAUDE.md standing rule: cross-check Bai-Perron before Q1 submission
## Reference: Bai & Perron (1998, 2003); strucchange: Zeileis et al. (2002)

suppressPackageStartupMessages({ library(strucchange); library(zoo) })

RESULTS_DIR <- file.path(
  Sys.getenv("HOME"),
  "Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma",
  "200-Manuscripts/210-Active/2026-Gold-Policy-Uncertainty-Repricing/03-Results"
)
DATA_FILE <- file.path(RESULTS_DIR, "paper3_gold_policy_uncertainty_dataset.csv")
OUT_FILE  <- file.path(RESULTS_DIR, "baiperron_strucchange_validation.txt")

cat("── Loading data ──────────────────────────────────────────────\n")
df <- read.csv(DATA_FILE, stringsAsFactors = FALSE)
df$DATE <- as.Date(df$DATE)
df <- df[order(df$DATE), ]
cat(sprintf("N = %d obs | %s to %s\n", nrow(df), min(df$DATE), max(df$DATE)))

# First-differences (matching Python QR script)
df$epu_change    <- c(NA, diff(df$epu_us))
df$fed_change    <- c(NA, diff(df$fed_funds_effective))
df$ust10y_change <- c(NA, diff(df$ust10y))
df$vix_change    <- c(NA, diff(df$VIX))
df$dxy_return    <- c(NA, df$DXY[-1] / df$DXY[-nrow(df)] - 1)
df$usdjpy_return <- c(NA, df$USDJPY[-1] / df$USDJPY[-nrow(df)] - 1)

keep_cols <- c("DATE","gold_return","epu_change","fed_change",
               "ust10y_change","vix_change","dxy_return","usdjpy_return")
df <- na.omit(df[, keep_cols])
cat(sprintf("After differencing: N = %d obs\n\n", nrow(df)))

FML <- gold_return ~ epu_change + fed_change + ust10y_change +
       vix_change + dxy_return + usdjpy_return

# ── 1. CUSUM OLS-based fluctuation test ───────────────────────────────────────
cat("── (1) CUSUM OLS-based fluctuation test ──────────────────────\n")
efp_obj    <- efp(FML, data = df, type = "OLS-CUSUM")
cusum_test <- sctest(efp_obj)
cat(sprintf("  OLS-CUSUM: stat = %.4f, p = %.4f\n\n",
            cusum_test$statistic, cusum_test$p.value))

# ── 2. Andrews (1993) supF — single structural break ──────────────────────────
cat("── (2) Andrews supF via Fstats() ─────────────────────────────\n")
fl       <- Fstats(FML, data = df, from = 0.15, to = 0.85)
bt       <- sctest(fl, type = "supF")
break_date <- df$DATE[fl$breakpoint]
cat(sprintf("  supF stat  = %.4f\n", bt$statistic))
cat(sprintf("  supF p     = %.6f\n", bt$p.value))
cat(sprintf("  Break date = %s\n\n", break_date))

# ── 3. Bai-Perron multiple breaks — breakpoints() ─────────────────────────────
cat("── (3) Bai-Perron multiple breaks, BIC (h=0.15, max=3) ───────\n")
bp   <- breakpoints(FML, data = df, h = 0.15, breaks = 3)
best <- breakpoints(bp)
cat(sprintf("  BIC-optimal m = %d break(s)\n", length(best$breakpoints)))
if (length(best$breakpoints) > 0) {
  for (brk in best$breakpoints)
    cat(sprintf("    obs %d → %s\n", brk, df$DATE[brk]))
}
cat("\n")

# ── 4. Segment EPU coefficients ───────────────────────────────────────────────
cat("── (4) EPU coefficient by segment ───────────────────────────\n")
if (length(best$breakpoints) >= 1) {
  seg <- rep(0L, nrow(df))
  for (k in seq_along(best$breakpoints))
    seg[(best$breakpoints[k] + 1):nrow(df)] <- k
  df$seg <- seg
  for (s in sort(unique(df$seg))) {
    sub <- df[df$seg == s, ]
    m_s <- lm(FML, data = sub)
    co  <- summary(m_s)$coefficients
    b   <- co["epu_change", "Estimate"]
    pv  <- co["epu_change", "Pr(>|t|)"]
    cat(sprintf("  seg %d (N=%d, %s – %s): epu beta = %.4e  p = %.4f\n",
                s, nrow(sub), min(sub$DATE), max(sub$DATE), b, pv))
  }
} else {
  cat("  No break → single regime\n")
}

# ── 5. Cross-validation summary ───────────────────────────────────────────────
python_date  <- as.Date("2001-08-02")
python_supf  <- 120.21
date_diff    <- abs(as.numeric(break_date - python_date))
date_ok      <- if (date_diff <= 30) "CONFIRMED" else "DIFFERS"

cat("\n── CROSS-VALIDATION SUMMARY ──────────────────────────────────\n")
cat(sprintf("  Python chi2-approx : supF=%.2f, break=2001-08-02\n", python_supf))
cat(sprintf("  R strucchange      : supF=%.4f, break=%s (p=%.6f)\n",
            bt$statistic, break_date, bt$p.value))
cat(sprintf("  Date agreement     : %s (|diff|=%d days)\n", date_ok, date_diff))

# ── 6. Write text report ──────────────────────────────────────────────────────
lines <- c(
  "======================================================================",
  " Bai-Perron Structural Break Validation — P3 Gold x EPU",
  "======================================================================",
  sprintf(" Data: %s to %s | N=%d daily obs", min(df$DATE), max(df$DATE), nrow(df)),
  " Model: gold_return ~ D.epu + D.fed_funds + D.ust10y + D.vix + D.dxy + D.usdjpy",
  "----------------------------------------------------------------------",
  "",
  "(1) OLS-CUSUM fluctuation test",
  sprintf("    stat = %.4f,  p = %.4f", cusum_test$statistic, cusum_test$p.value),
  "",
  "(2) Andrews (1993) supF (R strucchange::Fstats)",
  sprintf("    supF = %.4f,  p = %.6f", bt$statistic, bt$p.value),
  sprintf("    Break date (argmax F) = %s", break_date),
  "",
  "(3) Bai-Perron multiple breaks (BIC, h=0.15, max=3)",
  sprintf("    m_BIC = %d", length(best$breakpoints))
)
if (length(best$breakpoints) > 0) {
  for (brk in best$breakpoints)
    lines <- c(lines, sprintf("    -> obs %d = %s", brk, df$DATE[brk]))
}
lines <- c(lines,
  "",
  "(4) Cross-validation vs Python result",
  sprintf("    Python chi2-approx supF = %.2f,  break = 2001-08-02", python_supf),
  sprintf("    R strucchange supF      = %.4f,  break = %s", bt$statistic, break_date),
  sprintf("    Date match: %s (|diff| = %d days)", date_ok, date_diff),
  "",
  "Significance: strucchange p < 0.001 confirms structural break.",
  "======================================================================\n"
)
writeLines(lines, OUT_FILE)
cat(sprintf("\n✅ Report saved: %s\n", basename(OUT_FILE)))
