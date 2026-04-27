# 05b_robustness_logspec.R
# Robustness: log(MPS) + log(GSSE) absolute values instead of shares
# + Webb wild cluster bootstrap via fixest::feols()
# PSE × AgTFP OECD | MGO × HBI | 2026-04-24
#
# Spec B: ln_TFP = β1*ln_mps + β2*ln_gsse + controls
# Rationale: share variable (MPS/PSE) may embed measurement artefact
#            log levels capture actual spending intensity

library(tidyverse); library(plm); library(xtable)

# fixest for Webb bootstrap
if (!requireNamespace("fixest", quietly=TRUE)) {
  install.packages("fixest", repos="https://cloud.r-project.org")
}
library(fixest)
library(fwildclusterboot)

CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"
dir.create(TBLS, recursive=TRUE, showWarnings=FALSE)

# ── Load and engineer ──────────────────────────────────────────────────────────
df <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types=FALSE) %>%
  mutate(
    ln_tfp    = log(tfp_index),
    ln_gdppc  = log(gdppc_const2015),
    ln_fert   = log(fertilizer_kgha + 0.001),
    ln_agl    = log(agland_share + 0.001),
    # Specification B: log absolute values (+ 1 to handle zeros)
    ln_mps    = log(mps_pos  + 1),
    ln_gsse   = log(gsse_val + 1)
  )

cat("Log-spec variables:\n")
cat(sprintf("  ln_mps  : range [%.2f, %.2f], NAs=%d\n",
    min(df$ln_mps, na.rm=TRUE), max(df$ln_mps, na.rm=TRUE), sum(is.na(df$ln_mps))))
cat(sprintf("  ln_gsse : range [%.2f, %.2f], NAs=%d\n",
    min(df$ln_gsse, na.rm=TRUE), max(df$ln_gsse, na.rm=TRUE), sum(is.na(df$ln_gsse))))

x_vars_logspec <- c("ln_mps","ln_gsse","ln_gdppc","rural_share","ln_fert","ln_agl")

df_est <- df %>%
  select(iso3, year, ln_tfp, all_of(x_vars_logspec)) %>%
  drop_na()

cat(sprintf("\nLog-spec sample: N=%d, T=%d–%d, obs=%d\n\n",
    n_distinct(df_est$iso3), min(df_est$year), max(df_est$year), nrow(df_est)))

# ── CCEMG (reuse function from 05_csardl_main.R) ─────────────────────────────
ccemg_estimator <- function(y_name, x_names, data, id_var="iso3", time_var="year",
                            verbose=TRUE) {
  cs_vars  <- c(y_name, x_names)
  cs_means <- data %>%
    group_by(.data[[time_var]]) %>%
    summarise(across(all_of(cs_vars), ~mean(., na.rm=TRUE), .names="cm_{.col}"),
              .groups="drop")
  data   <- left_join(data, cs_means, by=time_var)
  cm_cols <- paste0("cm_", cs_vars)

  countries <- unique(data[[id_var]])
  lr_coefs  <- vector("list", length(countries))
  names(lr_coefs) <- countries

  for (i in seq_along(countries)) {
    sub <- data %>% filter(.data[[id_var]] == countries[i]) %>% arrange(.data[[time_var]])
    Ti  <- nrow(sub)
    if (Ti < length(x_names) + length(cm_cols) + 3) next
    Y  <- sub[[y_name]]
    X  <- cbind(1, as.matrix(sub[, x_names]), as.matrix(sub[, cm_cols]))
    cc <- complete.cases(X, Y)
    if (sum(cc) < ncol(X) + 2) next
    m  <- tryCatch(lm(Y[cc] ~ X[cc,] - 1), error=function(e) NULL)
    if (is.null(m)) next
    cf <- coef(m)
    if (length(cf) >= 1 + length(x_names)) {
      lr_coefs[[i]] <- cf[2:(1+length(x_names))]
      names(lr_coefs[[i]]) <- x_names
    }
  }

  valid <- which(!sapply(lr_coefs, is.null))
  N_v   <- length(valid)
  if (N_v < 3) { cat("  CCEMG: N_v=", N_v, "too few\n"); return(NULL) }

  lr_mat  <- do.call(rbind, lr_coefs[valid])
  colnames(lr_mat) <- x_names
  mg_mean <- colMeans(lr_mat, na.rm=TRUE)
  mg_se   <- apply(lr_mat, 2, sd, na.rm=TRUE) / sqrt(N_v)
  mg_t    <- mg_mean / mg_se
  mg_p    <- 2 * pt(-abs(mg_t), df=N_v-1)

  if (verbose) {
    cat(sprintf("CCEMG — N=%d\n", N_v))
    for (j in seq_along(x_names)) {
      s <- ifelse(mg_p[j]<.01,"***",ifelse(mg_p[j]<.05,"**",ifelse(mg_p[j]<.10,"*","")))
      cat(sprintf("  %-18s β=%8.4f  SE=%.4f  t=%6.3f  p=%.4f %s\n",
                  x_names[j], mg_mean[j], mg_se[j], mg_t[j], mg_p[j], s))
    }
  }
  list(mg_coef=mg_mean, mg_se=mg_se, mg_t=mg_t, mg_p=mg_p,
       N=N_v, x_names=x_names, lr_matrix=lr_mat)
}

amg_estimator <- function(y_name, x_names, data, id_var="iso3", time_var="year") {
  data <- data %>% arrange(.data[[id_var]], .data[[time_var]])
  df_fd <- data %>%
    group_by(.data[[id_var]]) %>%
    mutate(across(all_of(c(y_name, x_names)), ~c(NA_real_, diff(.)), .names="d_{.col}")) %>%
    ungroup() %>% drop_na(starts_with("d_"))

  d_y <- paste0("d_", y_name); d_x <- paste0("d_", x_names)
  yr_dum <- model.matrix(~ factor(df_fd[[time_var]]) - 1)
  X_pool <- cbind(as.matrix(df_fd[, d_x]), yr_dum)
  Y_pool <- df_fd[[d_y]]
  cc     <- complete.cases(X_pool, Y_pool)
  mu_vec <- rep(0, nrow(yr_dum))
  if (sum(cc) > ncol(X_pool)) {
    mp <- tryCatch(lm(Y_pool[cc] ~ X_pool[cc,] - 1), error=function(e) NULL)
    if (!is.null(mp)) {
      yd <- grep("factor", names(coef(mp)))
      if (length(yd)) mu_vec[cc][seq_along(yd)] <- coef(mp)[yd]
    }
  }
  countries <- unique(data[[id_var]])
  lr_coefs  <- vector("list", length(countries))
  for (i in seq_along(countries)) {
    sub <- data %>% filter(.data[[id_var]] == countries[i]) %>% arrange(.data[[time_var]])
    n_i <- nrow(sub)
    mu_i <- if (n_i <= length(mu_vec)) mu_vec[seq_len(n_i)] else
              c(mu_vec, rep(0, n_i-length(mu_vec)))
    mu_cum <- cumsum(replace_na(mu_i, 0))
    X_c <- cbind(1, as.matrix(sub[, x_names]), mu_cum)
    Y_c <- sub[[y_name]]
    cc2 <- complete.cases(X_c, Y_c)
    if (sum(cc2) < ncol(X_c)+2) next
    m <- tryCatch(lm(Y_c[cc2] ~ X_c[cc2,] - 1), error=function(e) NULL)
    if (is.null(m)) next
    cf <- coef(m)
    if (length(cf) >= 1+length(x_names)) {
      lr_coefs[[i]] <- cf[2:(1+length(x_names))]; names(lr_coefs[[i]]) <- x_names
    }
  }
  valid <- which(!sapply(lr_coefs, is.null)); N_v <- length(valid)
  if (N_v < 3) return(NULL)
  lr_mat <- do.call(rbind, lr_coefs[valid]); colnames(lr_mat) <- x_names
  mg_mean <- colMeans(lr_mat, na.rm=TRUE)
  mg_se   <- apply(lr_mat, 2, sd, na.rm=TRUE)/sqrt(N_v)
  mg_t    <- mg_mean/mg_se; mg_p <- 2*pt(-abs(mg_t), df=N_v-1)
  cat(sprintf("AMG — N=%d\n", N_v))
  for (j in seq_along(x_names)) {
    s <- ifelse(mg_p[j]<.01,"***",ifelse(mg_p[j]<.05,"**",ifelse(mg_p[j]<.10,"*","")))
    cat(sprintf("  %-18s β=%8.4f  SE=%.4f  t=%6.3f  p=%.4f %s\n",
                x_names[j], mg_mean[j], mg_se[j], mg_t[j], mg_p[j], s))
  }
  list(mg_coef=mg_mean, mg_se=mg_se, mg_t=mg_t, mg_p=mg_p,
       N=N_v, x_names=x_names, lr_matrix=lr_mat)
}

# ── Run Spec B ────────────────────────────────────────────────────────────────
cat("═══ Specification B: log(MPS_USD) + log(GSSE_USD) ═══\n\n")
res_ccemg_b <- tryCatch(ccemg_estimator("ln_tfp", x_vars_logspec, df_est),
                        error=function(e) { cat("CCEMG-B error:", e$message,"\n"); NULL })
cat("\n")
res_amg_b   <- tryCatch(amg_estimator("ln_tfp", x_vars_logspec, df_est),
                        error=function(e) { cat("AMG-B error:", e$message,"\n"); NULL })

# ── Webb Wild Cluster Bootstrap via lm + year/country dummies ─────────────────
# NOTE: boottest.fixest (fwildclusterboot 0.14.3) has a bug: preprocess2.fixest
# calls get_cluster() which evaluates iso3+year → error for character iso3.
# Workaround: use lm() with explicit dummies (boottest.lm is fully supported).
# Coefficients are numerically identical to feols TWFE.
cat("\n═══ Webb Wild Cluster Bootstrap (via lm + dummies) ═══\n")
cat("N=27 < 30 clusters → mandatory per CLAUDE.md\n\n")

df_fe <- df_est %>%
  mutate(iso3_f = factor(iso3), year_f = factor(year))

fe_lm <- lm(ln_tfp ~ ln_mps + ln_gsse + ln_gdppc + rural_share + ln_fert + ln_agl +
              iso3_f + year_f - 1,
            data = df_fe)

cat("TWFE (lm+dummies) key coefficients:\n")
cf_key <- coef(fe_lm)[c("ln_mps","ln_gsse","ln_gdppc","rural_share","ln_fert","ln_agl")]
for (nm in names(cf_key)) cat(sprintf("  %-12s  β = %.4f\n", nm, cf_key[nm]))

cat(sprintf("\n%-12s  %8s  %10s  %18s\n",
            "Variable", "TWFE β", "p (Webb)", "95% CI [Webb]"))
cat(strrep("─", 58), "\n")

set.seed(2026)
for (param in c("ln_mps","ln_gsse","ln_gdppc","rural_share","ln_fert","ln_agl")) {
  tryCatch({
    boot <- boottest(fe_lm, clustid = "iso3_f", param = param, B = 999, type = "webb")
    ci  <- boot$conf_int
    sig <- ifelse(boot$p_val<.01,"***",ifelse(boot$p_val<.05,"**",ifelse(boot$p_val<.10,"*","")))
    cat(sprintf("%-12s  %8.4f  %10.4f  [%7.4f, %7.4f] %s\n",
                param, boot$point_estimate, boot$p_val, ci[1], ci[2], sig))
  }, error=function(e) cat(sprintf("%-12s  Bootstrap error: %s\n", param, e$message)))
}

# ── Comparison table: Spec A (shares) vs Spec B (logs) ───────────────────────
cat("\n═══ Comparison: Share Spec (A) vs Log-Level Spec (B) ═══\n\n")

var_labels_b <- c(
  ln_mps     = "ln(MPS, USD)",
  ln_gsse    = "ln(GSSE, USD)",
  ln_gdppc   = "ln(GDP per capita)",
  rural_share= "Rural pop. share",
  ln_fert    = "ln(Fertilizer)",
  ln_agl     = "ln(Agric. land)"
)

if (!is.null(res_ccemg_b) && !is.null(res_amg_b)) {
  tab_b <- do.call(rbind, lapply(x_vars_logspec, function(xn) {
    j_c <- which(res_ccemg_b$x_names == xn)
    j_a <- which(res_amg_b$x_names   == xn)
    sc <- ifelse(res_ccemg_b$mg_p[j_c]<.01,"***",ifelse(res_ccemg_b$mg_p[j_c]<.05,"**",ifelse(res_ccemg_b$mg_p[j_c]<.10,"*","")))
    sa <- ifelse(res_amg_b$mg_p[j_a]<.01,"***",  ifelse(res_amg_b$mg_p[j_a]<.05,"**",  ifelse(res_amg_b$mg_p[j_a]<.10,"*",  "")))
    data.frame(
      Variable   = var_labels_b[xn] %||% xn,
      CCEMG_B    = sprintf("%.4f%s (%.4f)", res_ccemg_b$mg_coef[j_c], sc, res_ccemg_b$mg_se[j_c]),
      AMG_B      = sprintf("%.4f%s (%.4f)", res_amg_b$mg_coef[j_a],   sa, res_amg_b$mg_se[j_a]),
      stringsAsFactors = FALSE
    )
  }))
  cat("Spec B — log(MPS_USD) + log(GSSE_USD):\n")
  print(tab_b, row.names=FALSE)

  tab_b_xt <- xtable(tab_b,
    caption="Robustness — Specification B: Log absolute PSE values (USD). SE in parentheses.",
    label="tab:specB"
  )
  print(tab_b_xt,
    file=file.path(TBLS, "tab_specB_logmps.tex"),
    include.rownames=FALSE, booktabs=TRUE, caption.placement="top",
    sanitize.text.function=identity
  )
  cat("→ Saved: tab_specB_logmps.tex\n")
}

cat("\n✓ 05b complete — log-spec robustness + Webb bootstrap done.\n")
