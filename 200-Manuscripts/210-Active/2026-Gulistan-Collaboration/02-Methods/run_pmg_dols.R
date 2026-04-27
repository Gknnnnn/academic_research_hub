# run_pmg_dols.R
# MG / CMG / DOLS heterogeneous long-run panel estimators
# Reference: Pesaran & Smith (1995) MG; Pesaran (2006) CMG;
#            Stock & Watson (1993) DOLS; Kaba et al. (2022 Q1 The World Economy)
# plm v2.x: pmg() accepts model = "mg" | "cmg" | "dmg"

suppressPackageStartupMessages({
  library(plm)
  library(dplyr)
})

DATA_PATH <- "../../../../400-Data/2026-Gulistan-Collaboration/data/ssa_tarim_29_ulke_v7_climate.csv"
df   <- read.csv(DATA_PATH)
df$year <- as.integer(df$year)
df   <- df[order(df$country, df$year), ]
pdata <- pdata.frame(df, index = c("country","year"))

dep  <- "Agri_GDP"
x_m3 <- c("Labor","Land","Fertilizer","Exports","Technology","Resource_Rent","Electricity")
x_m4 <- c("Labor","Land","Fertilizer","Exports","Technology","Resource_Rent","Electricity",
           "gdp_pc","urban","trade_open","wgi_composite","enso_index")

df_m4 <- df[complete.cases(df[, c(dep, x_m4)]), ]
pd_m4 <- pdata.frame(df_m4, index=c("country","year"))

cat("\n", rep("=",72), "\n", sep="")
cat("MG / CMG / DOLS LONG-RUN ESTIMATORS — SSA Agricultural Panel\n")
cat("Reference: Pesaran & Smith (1995); Pesaran (2006); Kaba et al. (2022 Q1)\n")
cat(rep("=",72), "\n\n", sep="")

# -----------------------------------------------------------------------
# Helper: extract mg/cmg result as clean table
# -----------------------------------------------------------------------
mg_table <- function(model_obj, title) {
  tryCatch({
    cf  <- coef(model_obj)
    sm  <- summary(model_obj)
    mat <- sm$coefficients
    if (is.matrix(mat) || is.data.frame(mat)) {
      cat(title, "\n")
      nm <- rownames(mat)
      est <- mat[, 1]; se <- mat[, 2]
      tv  <- est / se; pv <- 2 * pnorm(-abs(tv))
      sig <- ifelse(pv<0.01,"***", ifelse(pv<0.05,"**", ifelse(pv<0.10,"*","")))
      out <- data.frame(Estimate=round(est,4), SE=round(se,4),
                        t=round(tv,3), p=round(pv,4), sig=sig)
      rownames(out) <- nm
      print(out)
    } else {
      cat(title, "\n")
      names_cf <- names(cf)
      cat(sprintf("  %-22s  Estimate\n", "Variable"))
      for (i in seq_along(cf)) cat(sprintf("  %-22s  %10.4f\n", names_cf[i], cf[i]))
    }
  }, error=function(e) cat(title, "ERROR:", conditionMessage(e), "\n"))
  cat("\n")
}

# ============================================================
# [A] MG — Mean Group Estimator (Pesaran & Smith, 1995)
# ============================================================
cat("[A] MG — MEAN GROUP ESTIMATOR (Pesaran & Smith, 1995)\n")
cat("Allows heterogeneous slopes across countries\n")
cat(rep("-",60), "\n", sep="")

f_m3 <- as.formula(paste(dep,"~",paste(x_m3, collapse="+")))
f_m4 <- as.formula(paste(dep,"~",paste(x_m4, collapse="+")))

tryCatch({ mg_m3 <- pmg(f_m3, data=pdata, model="mg")
           mg_table(mg_m3, "MG — Model 3 (7 variables):") },
  error=function(e) cat("MG M3 ERROR:", conditionMessage(e), "\n"))

tryCatch({ mg_m4 <- pmg(f_m4, data=pd_m4, model="mg")
           mg_table(mg_m4, "MG — Model 4 (12 variables):") },
  error=function(e) cat("MG M4 ERROR:", conditionMessage(e), "\n"))

# ============================================================
# [B] CMG — Common Correlated Effects Mean Group (Pesaran, 2006)
# ============================================================
cat("[B] CMG — COMMON CORRELATED EFFECTS MG (Pesaran, 2006)\n")
cat("Controls for cross-sectional dependence via cross-section averages\n")
cat(rep("-",60), "\n", sep="")

tryCatch({ cmg_m3 <- pmg(f_m3, data=pdata, model="cmg")
           mg_table(cmg_m3, "CMG — Model 3 (7 variables):") },
  error=function(e) cat("CMG M3 ERROR:", conditionMessage(e), "\n"))

tryCatch({ cmg_m4 <- pmg(f_m4, data=pd_m4, model="cmg")
           mg_table(cmg_m4, "CMG — Model 4 (12 variables):") },
  error=function(e) cat("CMG M4 ERROR:", conditionMessage(e), "\n"))

# ============================================================
# [C] DOLS — Dynamic OLS (Stock & Watson, 1993)
# With p=0 (T=21 too short for leads/lags with K≥7)
# Adjusted p=1 only for ≤4 variables
# ============================================================
cat("[C] DOLS — DYNAMIC OLS (Stock & Watson, 1993)\n")
cat("Panel DOLS: country-by-country OLS with Δx augmentation (p adaptive)\n")
cat(rep("-",60), "\n", sep="")

dols_panel <- function(df_in, dep, x_vars) {
  K <- length(x_vars)
  # T_eff = 21 - 2 for border loss; need T_eff > K*(2p+1) + K
  # with T_eff=19 and K=7, maximum p where K*(2p+1)+K+1 <= 19 is p=0
  # p=0: regressors = 1 + K + K = 2K+1; for K=7 → 15 < 19, fine
  p <- if (K <= 4) 1L else 0L

  countries <- unique(df_in$country)
  coef_mat  <- matrix(NA, nrow=length(countries), ncol=K,
                      dimnames=list(countries, x_vars))

  for (ctry in countries) {
    sub <- df_in[df_in$country == ctry, ]
    sub <- sub[order(sub$year), ]
    T_i <- nrow(sub)
    if (T_i < K + 5) next
    y  <- sub[[dep]]
    Xm <- as.matrix(sub[, x_vars, drop=FALSE])
    dX <- apply(Xm, 2, diff)    # (T-1) x K

    if (p == 0) {
      # contemporaneous diffs only
      y_t  <- y[-1]
      full <- data.frame(y=y_t, Xm[-1, , drop=FALSE], dX)
    } else {
      # p=1: lead + contemp + lag of dX
      n_d <- nrow(dX)
      aug <- matrix(NA, nrow=n_d, ncol=K*3)
      for (j in seq_len(K)) {
        aug[, 3*(j-1)+1] <- c(NA, dX[-n_d, j])    # lag
        aug[, 3*(j-1)+2] <- dX[, j]               # contemp
        aug[, 3*(j-1)+3] <- c(dX[-1, j], NA)      # lead
      }
      y_t  <- y[-1]
      full <- data.frame(y=y_t, Xm[-1, , drop=FALSE], aug)
    }
    full <- full[complete.cases(full), ]
    if (nrow(full) <= ncol(full)) next
    y_f <- full[, 1]
    X_f <- cbind(1, as.matrix(full[, -1]))
    tryCatch({
      b <- lm.fit(X_f, y_f)$coefficients
      # coefficients 2..(K+1) are for the level x_vars
      coef_mat[ctry, ] <- b[2:(K+1)]
    }, error=function(e) NULL)
  }
  n_ok <- colSums(!is.na(coef_mat))
  means <- colMeans(coef_mat, na.rm=TRUE)
  sds   <- apply(coef_mat, 2, sd, na.rm=TRUE)
  se    <- sds / sqrt(n_ok)
  tv    <- means / se
  pv    <- 2 * pnorm(-abs(tv))
  sig   <- ifelse(pv<0.01,"***", ifelse(pv<0.05,"**", ifelse(pv<0.10,"*","")))
  data.frame(Estimate=round(means,4), SE=round(se,4),
             t=round(tv,3), p=round(pv,4), sig=sig,
             N_ctry=n_ok, p_lag=p)
}

tryCatch({
  d3 <- dols_panel(df, dep, x_m3)
  cat(sprintf("DOLS — Model 3 (p=%d):\n", d3$p_lag[1]))
  print(d3[, c("Estimate","SE","t","p","sig","N_ctry")])
}, error=function(e) cat("DOLS M3 ERROR:", conditionMessage(e), "\n"))

cat("\n")
tryCatch({
  d4 <- dols_panel(df_m4, dep, x_m4)
  cat(sprintf("DOLS — Model 4 (p=%d):\n", d4$p_lag[1]))
  print(d4[, c("Estimate","SE","t","p","sig","N_ctry")])
}, error=function(e) cat("DOLS M4 ERROR:", conditionMessage(e), "\n"))

# ============================================================
# [D] Comparison: CMG vs DOLS (key variables)
# ============================================================
cat("\n[D] ROBUSTNESS COMPARISON — Model 3 Key Variables\n")
cat(rep("-",60), "\n", sep="")
cat(sprintf("%-20s  %8s  %8s  %8s\n", "Variable", "MG", "CMG", "DOLS"))
cat(rep("-",50), "\n", sep="")

tryCatch({
  mg_m3_c  <- coef(pmg(f_m3, data=pdata, model="mg"))
  cmg_m3_c <- coef(pmg(f_m3, data=pdata, model="cmg"))
  d3_c     <- dols_panel(df, dep, x_m3)$Estimate
  names(d3_c) <- x_m3
  vars_show <- intersect(names(mg_m3_c), x_m3)
  for (v in vars_show) {
    mg_v  <- ifelse(v %in% names(mg_m3_c),  round(mg_m3_c[v],4), NA)
    cmg_v <- ifelse(v %in% names(cmg_m3_c), round(cmg_m3_c[v],4), NA)
    d_v   <- ifelse(v %in% names(d3_c),     round(d3_c[v],4), NA)
    cat(sprintf("%-20s  %8.4f  %8.4f  %8.4f\n", v, mg_v, cmg_v, d_v))
  }
}, error=function(e) cat("Comparison ERROR:", conditionMessage(e), "\n"))

cat("\n", rep("=",72), "\n", sep="")
cat("MG / CMG / DOLS COMPLETE\n")
cat(rep("=",72), "\n", sep="")
