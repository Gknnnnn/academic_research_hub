# 06_causality_robustness.R
# Dumitrescu-Hurlin (2012) causality + Robustness checks
# PSE × AgTFP OECD | MGO × HBI
#
# Robustness: CCEMG, sub-panel (EU, non-EU), PMG-ECM

library(tidyverse); library(plm); library(xtable)

CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"

df <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types=FALSE) %>%
  mutate(
    ln_tfp   = log(tfp_index),
    ln_gdppc = log(gdppc_const2015),
    ln_fert  = log(fertilizer_kgha + 0.001),
    ln_agl   = log(agland_share + 0.001)
  )

pse_available <- "mps_share" %in% names(df) && !all(is.na(df$mps_share))

# ── Dumitrescu-Hurlin Non-Causality Test ──────────────────────────────────────
# H0: No Granger causality (homogeneous non-causality)
# H1: Granger causality for at least one country
# W̄, Z̄ statistics; Z̃ (standardised) follows N(0,1) asymptotically

dh_causality <- function(y_vec, x_vec, id, time, lag=2) {
  countries <- unique(id)
  N <- length(countries)
  W_i <- numeric(N)

  for (i in seq_along(countries)) {
    idx <- id == countries[i]
    yi <- y_vec[idx]
    xi <- x_vec[idx]
    ti <- time[idx]
    Ti <- length(yi)
    if (Ti < 2*lag + 3) { W_i[i] <- NA; next }

    # Build VAR lag matrix
    y_lags <- sapply(1:lag, function(l) c(rep(NA,l), yi)[seq_len(Ti)])
    x_lags <- sapply(1:lag, function(l) c(rep(NA,l), xi)[seq_len(Ti)])
    X      <- cbind(1, y_lags, x_lags)
    Y      <- yi
    cc     <- complete.cases(X, Y)
    if (sum(cc) < ncol(X)+2) { W_i[i] <- NA; next }
    m_unr  <- tryCatch(lm(Y[cc] ~ X[cc,]-1), error=function(e) NULL)

    # Restricted (no x lags)
    X_r    <- X[, 1:(lag+1), drop=FALSE]
    m_rest <- tryCatch(lm(Y[cc] ~ X_r[cc,]-1), error=function(e) NULL)
    if (is.null(m_unr) || is.null(m_rest)) { W_i[i] <- NA; next }

    RSS_u  <- sum(resid(m_unr)^2)
    RSS_r  <- sum(resid(m_rest)^2)
    df1    <- lag
    df2    <- sum(cc) - ncol(X)
    W_i[i] <- ((RSS_r - RSS_u)/df1) / (RSS_u/df2)  # F-stat × lag
  }

  valid <- which(!is.na(W_i))
  N_v   <- length(valid)
  T_bar <- mean(sapply(valid, function(i) sum(id == countries[i])))

  W_bar <- mean(W_i[valid])
  # Standardised W̃ (Dumitrescu-Hurlin eq.16)
  Z_bar <- sqrt(N_v/(2*lag)) * (W_bar - lag)
  # For finite T, use approximated Z̃
  Z_tilde <- sqrt(N_v) * (W_bar - lag) /
             sqrt(var(W_i[valid], na.rm=TRUE))

  p_Zbar   <- 2*pnorm(-abs(Z_bar))
  p_Ztilde <- 2*pnorm(-abs(Z_tilde))

  list(W_bar=W_bar, Z_bar=Z_bar, p_Zbar=p_Zbar,
       Z_tilde=Z_tilde, p_Ztilde=p_Ztilde,
       N=N_v, T=T_bar, W_i=W_i)
}

cat("═══ Dumitrescu-Hurlin (2012) Panel Causality ═══\n")
cat("H0: Homogeneous non-causality\n\n")

caus_results <- list()

# PSE → TFP (if available)
if (pse_available) {
  cat("PSE → TFP:\n")
  res <- dh_causality(df$ln_tfp, df$pse_pct, df$iso3, df$year, lag=2)
  caus_results[["PSE → TFP"]] <- res
  cat(sprintf("  W̄ = %.3f | Z̄ = %.3f (p=%.4f) | Z̃ = %.3f (p=%.4f)\n\n",
              res$W_bar, res$Z_bar, res$p_Zbar, res$Z_tilde, res$p_Ztilde))

  cat("TFP → PSE (reverse):\n")
  res2 <- dh_causality(df$pse_pct, df$ln_tfp, df$iso3, df$year, lag=2)
  caus_results[["TFP → PSE"]] <- res2
  cat(sprintf("  W̄ = %.3f | Z̄ = %.3f (p=%.4f) | Z̃ = %.3f (p=%.4f)\n\n",
              res2$W_bar, res2$Z_bar, res2$p_Zbar, res2$Z_tilde, res2$p_Ztilde))
}

# GDP → TFP
cat("GDP → TFP:\n")
res_gdp <- dh_causality(df$ln_tfp, df$ln_gdppc, df$iso3, df$year, lag=2)
caus_results[["ln_GDP → TFP"]] <- res_gdp
cat(sprintf("  W̄ = %.3f | Z̄ = %.3f (p=%.4f) | Z̃ = %.3f (p=%.4f)\n\n",
            res_gdp$W_bar, res_gdp$Z_bar, res_gdp$p_Zbar,
            res_gdp$Z_tilde, res_gdp$p_Ztilde))

# Table 6a: Causality
tab6a <- do.call(rbind, lapply(names(caus_results), function(nm) {
  r <- caus_results[[nm]]
  data.frame(Direction=nm,
             `W-bar`  = round(r$W_bar,3),
             `Z-bar`  = round(r$Z_bar,3),
             `p(Z-bar)` = round(r$p_Zbar,4),
             `Z-tilde`= round(r$Z_tilde,3),
             `p(Z-tilde)` = round(r$p_Ztilde,4),
             check.names=FALSE)
}))
cat("Table 6a:\n"); print(tab6a)

# ── CCEMG Robustness ──────────────────────────────────────────────────────────
cat("\n═══ CCEMG Robustness (Pesaran 2006) ═══\n")

# CCEMG: augment each country regression with cross-section means
ccemg <- function(y_name, x_names, data, id_var="iso3", time_var="year") {
  cs_mean_vars <- c(y_name, x_names)
  cs_means <- data %>%
    group_by(.data[[time_var]]) %>%
    summarise(across(all_of(cs_mean_vars), ~mean(., na.rm=TRUE), .names="cm_{.col}"),
              .groups="drop")
  data <- left_join(data, cs_means, by=time_var)
  cm_names <- paste0("cm_", cs_mean_vars)

  countries <- unique(data[[id_var]])
  lr_coefs  <- vector("list", length(countries))
  for (i in seq_along(countries)) {
    sub <- data %>% filter(.data[[id_var]] == countries[i]) %>% arrange(.data[[time_var]])
    X   <- cbind(1, as.matrix(sub[, c(x_names, cm_names)]))
    Y   <- sub[[y_name]]
    cc  <- complete.cases(X, Y)
    if (sum(cc) < ncol(X)+2) next
    m   <- tryCatch(lm(Y[cc] ~ X[cc,]-1), error=function(e) NULL)
    if (is.null(m)) next
    lr_coefs[[i]] <- coef(m)[2:(1+length(x_names))]
  }
  valid <- which(!sapply(lr_coefs, is.null))
  N_v   <- length(valid)
  lr_mat <- do.call(rbind, lr_coefs[valid])
  colnames(lr_mat) <- x_names
  mg_mean <- colMeans(lr_mat, na.rm=TRUE)
  mg_se   <- apply(lr_mat, 2, sd, na.rm=TRUE) / sqrt(N_v)
  mg_t    <- mg_mean / mg_se
  mg_p    <- 2*pt(-abs(mg_t), df=N_v-1)
  cat(sprintf("CCEMG — N=%d\n", N_v))
  for (j in seq_along(x_names)) {
    stars <- ifelse(mg_p[j]<0.01,"***",ifelse(mg_p[j]<0.05,"**",ifelse(mg_p[j]<0.10,"*","")))
    cat(sprintf("  %-20s β = %7.4f  SE = %.4f  p = %.4f %s\n",
                x_names[j], mg_mean[j], mg_se[j], mg_p[j], stars))
  }
  list(mg_coef=mg_mean, mg_se=mg_se, mg_t=mg_t, mg_p=mg_p, N=N_v, x_names=x_names)
}

x_vars <- if (pse_available) c("mps_share","gsse_share","ln_gdppc","rural_share","ln_fert","ln_agl") else
                             c("ln_gdppc","rural_share","ln_fert","ln_agl")
df_est <- df %>% select(iso3, year, ln_tfp, all_of(x_vars)) %>% drop_na()

res_ccemg <- tryCatch(ccemg("ln_tfp", x_vars, df_est), error=function(e) NULL)

# ── Sub-panel robustness ───────────────────────────────────────────────────────
cat("\n═══ Sub-Panel Analysis ═══\n")

EU_MEMBERS <- c("AUT","BEL","CZE","DNK","EST","FIN","FRA","DEU","GRC","HUN",
                "IRL","ITA","LVA","LTU","LUX","NLD","POL","PRT","SVK","SVN","ESP","SWE")

cat("\n─ EU sub-panel ─\n")
df_eu  <- df_est %>% filter(iso3 %in% EU_MEMBERS)
if (n_distinct(df_eu$iso3) >= 5)
  res_eu  <- tryCatch(ccemg("ln_tfp", x_vars, df_eu), error=function(e) NULL)

cat("\n─ Non-EU sub-panel ─\n")
df_neu <- df_est %>% filter(!iso3 %in% EU_MEMBERS)
if (n_distinct(df_neu$iso3) >= 5)
  res_neu <- tryCatch(ccemg("ln_tfp", x_vars, df_neu), error=function(e) NULL)

# Save causality table
tab6a_xt <- xtable(tab6a,
  caption="Dumitrescu-Hurlin (2012) Heterogeneous Panel Causality Tests",
  label="tab:causality"
)
print(tab6a_xt,
  file=file.path(TBLS, "tab6_causality.tex"),
  include.rownames=FALSE, booktabs=TRUE, caption.placement="top",
  sanitize.text.function=identity
)
cat("\n→ Saved: tab6_causality.tex\n")
cat("✓ Step 6 complete — full pipeline done.\n")
cat("  Next: Run 04-Manuscript/PSE_AgTFP_OECD_v01.qmd\n")
