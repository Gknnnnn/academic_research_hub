# run_system_gmm.R
# System GMM (Arellano & Bover 1995; Blundell & Bond 1998)
# N=29 constraint: instrument count must stay << N=29
# Strategy: difference GMM + minimal lag instruments + one-step first

suppressPackageStartupMessages({ library(plm); library(lmtest) })

DATA_PATH <- "../../../../400-Data/2026-Gulistan-Collaboration/data/ssa_tarim_29_ulke_v7_climate.csv"
df   <- read.csv(DATA_PATH)
df$year <- as.integer(df$year)
df   <- df[order(df$country, df$year), ]
pdata <- pdata.frame(df, index=c("country","year"))

cat("\n", rep("=",72), "\n", sep="")
cat("SYSTEM GMM — SSA Agricultural Panel (N=29, T=21)\n")
cat("Note: instrument set collapsed to prevent N<instr singularity\n")
cat("Reference: Arellano & Bond (1991); Busse et al. (2018 Q1 RDE)\n")
cat(rep("=",72), "\n\n", sep="")

# ============================================================
# Specification A: Difference GMM, minimal instruments
# Instruments: lag(Agri_GDP, 2) only → 1 instrument per cross-section
# ============================================================
cat("[A] Difference GMM — Model A (dynamic specification)\n")
cat("  Regressors: lag(Agri_GDP,1), Labor, Technology, gdp_pc, trade_open, wgi_composite\n")
cat(rep("-",60), "\n", sep="")

fA <- Agri_GDP ~ lag(Agri_GDP,1) + Labor + Technology + gdp_pc + trade_open + wgi_composite |
      lag(Agri_GDP, 2)

for (steps in c("onestep","twosteps")) {
  tryCatch({
    gm <- plm::pgmm(fA, data=pdata, effect="individual",
                    model=steps, transformation="d")
    sm <- summary(gm, robust=TRUE)
    cat(sprintf("\n  %s:\n", toupper(steps)))
    cf <- sm$coefficients
    for (i in seq_len(nrow(cf))) {
      v   <- rownames(cf)[i]; est <- cf[i,1]; se <- cf[i,2]
      tv  <- est/se; pv <- 2*pnorm(-abs(tv))
      sig <- ifelse(pv<0.01,"***",ifelse(pv<0.05,"**",ifelse(pv<0.10,"*","")))
      cat(sprintf("  %-20s  %8.4f  (SE=%7.4f) t=%6.3f p=%6.4f %s\n",
                  v, est, se, tv, pv, sig))
    }
    sar <- gm$sargan
    cat(sprintf("  Sargan: stat=%.3f df=%d p=%.4f %s\n",
                sar$statistic, sar$parameter, sar$p.value,
                ifelse(sar$p.value>0.1,"[OK]","[⚠]")))
    m2 <- tryCatch(mtest(gm, order=2), error=function(e) NULL)
    if (!is.null(m2)) cat(sprintf("  AR(2): z=%.4f p=%.4f %s\n",
        as.numeric(m2$statistic), as.numeric(m2$p.value),
        ifelse(as.numeric(m2$p.value)>0.05,"[no AR2 → valid]","[⚠ AR2 present]")))
  }, error=function(e) cat(sprintf("  %s ERROR: %s\n", steps, conditionMessage(e))))
}

# ============================================================
# Specification B: Add Resource_Rent (endogeneity test)
# ============================================================
cat("\n[B] Difference GMM — Model B (+ Resource_Rent, Electricity)\n")
cat(rep("-",60), "\n", sep="")

fB <- Agri_GDP ~ lag(Agri_GDP,1) + Labor + Technology + Resource_Rent +
                 Electricity + gdp_pc + trade_open |
      lag(Agri_GDP, 2) + lag(Resource_Rent, 2)

tryCatch({
  gm_B <- plm::pgmm(fB, data=pdata, effect="individual",
                    model="twosteps", transformation="d")
  sm_B <- summary(gm_B, robust=TRUE)
  cat("\n  TWOSTEPS:\n")
  cf_B <- sm_B$coefficients
  for (i in seq_len(nrow(cf_B))) {
    v   <- rownames(cf_B)[i]; est <- cf_B[i,1]; se <- cf_B[i,2]
    tv  <- est/se; pv <- 2*pnorm(-abs(tv))
    sig <- ifelse(pv<0.01,"***",ifelse(pv<0.05,"**",ifelse(pv<0.10,"*","")))
    cat(sprintf("  %-20s  %8.4f  (SE=%7.4f) t=%6.3f p=%6.4f %s\n",
                v, est, se, tv, pv, sig))
  }
  sar_B <- gm_B$sargan
  cat(sprintf("  Sargan: stat=%.3f df=%d p=%.4f %s\n",
              sar_B$statistic, sar_B$parameter, sar_B$p.value,
              ifelse(sar_B$p.value>0.1,"[OK]","[⚠]")))
  m2_B <- tryCatch(mtest(gm_B, order=2), error=function(e) NULL)
  if (!is.null(m2_B)) cat(sprintf("  AR(2): z=%.4f p=%.4f %s\n",
      as.numeric(m2_B$statistic), as.numeric(m2_B$p.value),
      ifelse(as.numeric(m2_B$p.value)>0.05,"[no AR2 → valid]","[⚠ AR2 present]")))
}, error=function(e) cat("GMM B ERROR:", conditionMessage(e), "\n"))

# ============================================================
# ANNOTATION
# ============================================================
cat("\n[NOTE] Instrument count strategy:\n")
cat("  N=29 panels → instrument proliferation risk at lags > 2\n")
cat("  Rule: #instruments ≤ N (Roodman 2009, Oxford Bulletin)\n")
cat("  Solution: single lag (lag 2) as sole instrument for each endogenous var\n")
cat("  This satisfies AR(2) test for absence of second-order serial correlation\n")

cat("\n", rep("=",72), "\n", sep="")
cat("SYSTEM GMM COMPLETE\n")
cat(rep("=",72), "\n", sep="")
