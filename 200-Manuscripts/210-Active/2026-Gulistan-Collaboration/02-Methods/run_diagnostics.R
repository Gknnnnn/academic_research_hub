# run_diagnostics.R — SSA Agricultural Panel Diagnostic Tests
library(plm)
library(car)

DATA_PATH <- "../../../../400-Data/2026-Gulistan-Collaboration/data/ssa_tarim_29_ulke_v7_climate.csv"
df   <- read.csv(DATA_PATH)
df$year <- as.integer(df$year)
pdata <- pdata.frame(df, index = c("country", "year"))

dep_var  <- "Agri_GDP"
ind_vars <- c("Labor","Land","Fertilizer","Exports","Technology","Resource_Rent","Electricity")
new_vars <- c("gdp_pc","urban","fdi","trade_open","wgi_composite","enso_index","ln_ffpi","cereal_yield","food_prod_idx")
all_vars <- c(ind_vars, new_vars)

# Helper: within-country first differences (country-safe)
first_diff_by_country <- function(df_in, var) {
  countries <- unique(df_in$country)
  result <- rep(NA_real_, nrow(df_in))
  for (ctry in countries) {
    idx <- which(df_in$country == ctry)
    idx <- idx[order(df_in$year[idx])]
    y <- df_in[[var]][idx]
    result[idx[-1]] <- diff(y)
  }
  result
}

cat("\n", rep("=",72), "\n", sep="")
cat("PANEL DIAGNOSTIC TESTS — SSA Agricultural Panel (N=29, T=21)\n")
cat(rep("=",72), "\n\n", sep="")

# ============================================================
# [D1] Pesaran (2004) CD TEST via plm::pcdtest
# ============================================================
cat("[D1] PESARAN (2004) CD TEST — Cross-Sectional Dependence\n")
cat("H0: No cross-sectional dependence\n")
cat(rep("-",72), "\n", sep="")
cat(sprintf("%-26s %10s %10s %15s\n","Variable","CD stat","p-value","Decision"))
cat(rep("-",72), "\n", sep="")

cd_results <- list()
for (var in c(dep_var, all_vars)) {
  tryCatch({
    res <- plm::pcdtest(pdata[[var]], test = "cd")
    CD    <- as.numeric(res$statistic)
    p_val <- as.numeric(res$p.value)
    karar <- ifelse(p_val<0.01,"CSD ***", ifelse(p_val<0.05,"CSD **", ifelse(p_val<0.10,"CSD *","Independent")))
    cat(sprintf("%-26s %10.3f %10.4f %15s\n", var, CD, p_val, karar))
    cd_results[[var]] <- list(CD=CD, p=p_val)
  }, error = function(e) cat(sprintf("%-26s  ERROR: %s\n", var, conditionMessage(e))))
}
cat(rep("-",72), "\n", sep="")
cat("→ CSD present → 2nd-gen unit root (CIPS) required.\n\n")

# ============================================================
# [D2] CIPS UNIT ROOT — Pesaran (2007) manual CADF
# ============================================================
cat("[D2] PESARAN (2007) CIPS UNIT ROOT TEST\n")
cat("H0: Unit root present | Critical: 1%=-2.57  5%=-2.33  10%=-2.21\n")
cat(rep("-",72), "\n", sep="")
cat(sprintf("%-26s %12s %12s %12s\n","Variable","CIPS(level)","CIPS(Δ)","Integration"))
cat(rep("-",72), "\n", sep="")

cips_stat <- function(pd, var) {
  countries <- levels(pd$country)
  y_bar <- tapply(as.numeric(pd[[var]]), as.character(pd$year), mean, na.rm=TRUE)
  t_stats <- sapply(countries, function(ctry) {
    y <- as.numeric(pd[pd$country == ctry, var])
    yb <- as.numeric(y_bar)
    if (sum(!is.na(y)) < 5) return(NA)
    # keep only non-NA aligned rows
    ok <- !is.na(y) & !is.na(yb)
    y <- y[ok]; yb <- yb[ok]
    T_i <- length(y)
    dy <- diff(y); dyb <- diff(yb)
    ylg <- y[-T_i]; yblg <- yb[-T_i]
    X <- cbind(1, ylg, yblg, dyb)
    tryCatch({
      b  <- solve(t(X) %*% X) %*% t(X) %*% dy
      e  <- dy - X %*% b
      s2 <- sum(e^2) / max(nrow(X)-ncol(X), 1)
      se <- sqrt(s2 * solve(t(X) %*% X)[2,2])
      b[2] / se
    }, error=function(e) NA)
  })
  mean(t_stats, na.rm=TRUE)
}

sig_str <- function(v, cvs=c(-2.57,-2.33,-2.21)) {
  if (is.na(v)) return("")
  if (v < cvs[1]) "***" else if (v < cvs[2]) "**" else if (v < cvs[3]) "*" else ""
}

int_results <- list()
for (var in c(dep_var, all_vars)) {
  cips_lev <- tryCatch(cips_stat(pdata, var), error=function(e) NA)

  # First difference: add as new column in df, then recreate pdata piece
  d_col <- first_diff_by_country(df, var)
  df_tmp <- df; df_tmp[["__d__"]] <- d_col
  pd_tmp <- pdata.frame(df_tmp, index=c("country","year"))
  cips_dif <- tryCatch(cips_stat(pd_tmp, "__d__"), error=function(e) NA)

  cv5 <- -2.33
  ord <- if (!is.na(cips_lev) && cips_lev < cv5) "I(0)" else
         if (!is.na(cips_dif) && cips_dif < cv5)  "I(1)" else "I(?)"
  int_results[[var]] <- ord

  cat(sprintf("%-26s %10.3f%-3s %10.3f%-3s %10s\n",
              var,
              ifelse(is.na(cips_lev), NA, cips_lev), sig_str(cips_lev),
              ifelse(is.na(cips_dif), NA, cips_dif), sig_str(cips_dif),
              ord))
}
cat(rep("-",72), "\n", sep="")
cat("*** p<0.01  ** p<0.05  * p<0.10\n\n")

# ============================================================
# [D3] DUMITRESCU-HURLIN (2012) PANEL CAUSALITY
# ============================================================
cat("[D3] DUMITRESCU-HURLIN (2012) PANEL CAUSALITY\n")
cat("H0: x does NOT Granger-cause y\n")
cat(rep("-",72), "\n", sep="")

dh_test <- function(df_in, y_var, x_var, lags=1) {
  countries <- unique(df_in$country)
  N <- length(countries); T_val <- length(unique(df_in$year))
  W_i <- sapply(countries, function(ctry) {
    sub <- df_in[df_in$country == ctry, ]; sub <- sub[order(sub$year),]
    y <- sub[[y_var]]; x <- sub[[x_var]]
    T_i <- length(y)
    if (T_i <= lags*2+2 || any(is.na(c(y,x)))) return(NA)
    Y   <- y[(lags+1):T_i]
    X_u <- cbind(1, sapply(1:lags, function(k) y[(lags+1-k):(T_i-k)]),
                    sapply(1:lags, function(k) x[(lags+1-k):(T_i-k)]))
    X_r <- cbind(1, sapply(1:lags, function(k) y[(lags+1-k):(T_i-k)]))
    tryCatch({
      lags * ((sum(lm.fit(X_r,Y)$residuals^2)-sum(lm.fit(X_u,Y)$residuals^2))/lags) /
             (sum(lm.fit(X_u,Y)$residuals^2)/(length(Y)-ncol(X_u)))
    }, error=function(e) NA)
  })
  W_i <- W_i[!is.na(W_i)]; N_v <- length(W_i); W_bar <- mean(W_i)
  T_eff <- T_val - 2*lags - 1
  Z_t  <- if (T_eff > 3+lags) sqrt(N_v/(2*lags)*(T_eff/(T_eff+2*lags)))*(W_bar-lags) else sqrt(N_v/(2*lags))*(W_bar-lags)
  p    <- 2 * pnorm(-abs(Z_t))
  list(W_bar=round(W_bar,3), Z_tilde=round(Z_t,3), p=round(p,4),
       decision=ifelse(p<0.01,"Causality ***", ifelse(p<0.05,"Causality **", ifelse(p<0.10,"Causality *","No causality"))))
}

test_pairs <- c("Labor","Fertilizer","Technology","Resource_Rent","Electricity",
                "gdp_pc","urban","trade_open","wgi_composite","enso_index",
                "ln_ffpi","cereal_yield","food_prod_idx")
test_pairs <- test_pairs[test_pairs %in% names(df)]

cat(sprintf("%-42s %7s %9s %8s  %s\n","Hypothesis","W-bar","Z-tilde","p-val","Decision"))
cat(rep("-",72), "\n", sep="")
for (pred in test_pairs) {
  r <- tryCatch(dh_test(df, dep_var, pred), error=function(e) list(W_bar=NA,Z_tilde=NA,p=NA,decision="ERROR"))
  cat(sprintf("%-42s %7.3f %9.3f %8.4f  %s\n", paste(pred,"→",dep_var), r$W_bar, r$Z_tilde, r$p, r$decision))
}
cat(rep("-",35), "\n", sep="")
for (pred in test_pairs) {
  r <- tryCatch(dh_test(df, pred, dep_var), error=function(e) list(W_bar=NA,Z_tilde=NA,p=NA,decision="ERROR"))
  cat(sprintf("%-42s %7.3f %9.3f %8.4f  %s\n", paste(dep_var,"→",pred), r$W_bar, r$Z_tilde, r$p, r$decision))
}
cat(rep("-",72), "\n", sep="")
cat("*** p<0.01  ** p<0.05  * p<0.10\n\n")

# ============================================================
# [D4] VIF ANALYSIS
# ============================================================
cat("[D4] VIF ANALYSIS\n")
cat(rep("-",52), "\n", sep="")

f_m3  <- as.formula(paste(dep_var,"~",paste(ind_vars, collapse="+")))
vif_m3 <- vif(lm(f_m3, data=df))
cat("Model 3 (7 variables):\n")
for (v in names(vif_m3)) {
  flag <- if (vif_m3[v]>10) "⚠ VERY HIGH" else if (vif_m3[v]>5) "⚠ MODERATE" else "✓"
  cat(sprintf("  %-25s VIF = %6.2f  %s\n", v, vif_m3[v], flag))
}

f_ext <- as.formula(paste(dep_var,"~",paste(c(ind_vars,"gdp_pc","urban","trade_open","fdi","wgi_composite","enso_index"), collapse="+")))
vif_ext <- tryCatch(vif(lm(f_ext, data=df)), error=function(e) NULL)
if (!is.null(vif_ext)) {
  cat("\nExtended Model 4 (13 variables):\n")
  for (v in names(vif_ext)) {
    flag <- if (vif_ext[v]>10) "⚠ VERY HIGH" else if (vif_ext[v]>5) "⚠ MODERATE" else "✓"
    cat(sprintf("  %-25s VIF = %6.2f  %s\n", v, vif_ext[v], flag))
  }
}
cat(rep("-",52), "\n", sep="")
cat("Reference: Wooldridge (2010) — VIF < 10 acceptable\n\n")

cat(rep("=",72), "\n", sep="")
cat("ALL DIAGNOSTIC TESTS COMPLETE\n")
cat(rep("=",72), "\n", sep="")
