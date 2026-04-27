# 05_csardl_main.R — CCEMG + AMG Main Estimation
# PSE × AgTFP OECD | MGO × HBI | Fixed: 2026-04-24
#
# Full model: ln_TFP = β1*mps_share + β2*gsse_share + β3*ln_gdppc +
#             β4*rural_share + β5*ln_fert + β6*ln_agl + ε
# Expected: β1<0 (MPS bozucu), β2>0 (GSSE üretken), β3>0

library(tidyverse); library(plm); library(lmtest); library(sandwich)
library(xtable); library(fwildclusterboot)

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

x_vars_ctrl <- c("ln_gdppc","rural_share","ln_fert","ln_agl")
x_vars_full <- if (pse_available) c("mps_share","gsse_share", x_vars_ctrl) else x_vars_ctrl

df_est <- df %>%
  select(iso3, year, ln_tfp, all_of(x_vars_full)) %>%
  drop_na()

cat(sprintf("Estimation sample: N=%d, T=%d–%d, obs=%d\n\n",
    n_distinct(df_est$iso3), min(df_est$year), max(df_est$year), nrow(df_est)))

# ── CCEMG Estimator (Pesaran 2006) ────────────────────────────────────────────
# Augments each country regression with contemporaneous CS means of y and all x's
# Parsimonious: adds only K+1 extra regressors (ȳ_t, x̄_1t...x̄_Kt)
# Works with Ti as small as ~15

ccemg_estimator <- function(y_name, x_names, data, id_var="iso3", time_var="year",
                            verbose=TRUE) {
  # Compute cross-section means for each year
  cs_vars <- c(y_name, x_names)
  cs_means <- data %>%
    group_by(.data[[time_var]]) %>%
    summarise(across(all_of(cs_vars), ~mean(., na.rm=TRUE), .names="cm_{.col}"),
              .groups="drop")

  data <- left_join(data, cs_means, by=time_var)
  cm_cols <- paste0("cm_", cs_vars)

  countries <- unique(data[[id_var]])
  N <- length(countries)
  lr_coefs  <- vector("list", N)
  names(lr_coefs) <- countries

  for (i in seq_along(countries)) {
    sub <- data %>% filter(.data[[id_var]] == countries[i]) %>% arrange(.data[[time_var]])
    Ti  <- nrow(sub)
    if (Ti < length(x_names) + length(cm_cols) + 3) next

    # Regressors: y_name ~ x_names + cm_cols
    Y <- sub[[y_name]]
    X <- cbind(1, as.matrix(sub[, x_names]), as.matrix(sub[, cm_cols]))
    cc <- complete.cases(X, Y)
    if (sum(cc) < ncol(X) + 2) next

    m <- tryCatch(lm(Y[cc] ~ X[cc,] - 1), error=function(e) NULL)
    if (is.null(m)) next

    # Long-run coefficients are columns 2:(1+k) of X (after intercept col 1)
    cf <- coef(m)
    if (length(cf) >= 1 + length(x_names)) {
      lr_coefs[[i]] <- cf[2:(1 + length(x_names))]
      names(lr_coefs[[i]]) <- x_names
    }
  }

  valid <- which(!sapply(lr_coefs, is.null))
  N_v   <- length(valid)

  if (N_v < 3) {
    cat("  CCEMG: Too few valid estimates (N_v =", N_v, "). Check data.\n")
    return(NULL)
  }

  lr_mat  <- do.call(rbind, lr_coefs[valid])
  colnames(lr_mat) <- x_names
  mg_mean <- colMeans(lr_mat, na.rm=TRUE)
  mg_se   <- apply(lr_mat, 2, sd, na.rm=TRUE) / sqrt(N_v)
  mg_t    <- mg_mean / mg_se
  mg_p    <- 2 * pt(-abs(mg_t), df=N_v - 1)

  if (verbose) {
    cat(sprintf("\nCCEMG (Pesaran 2006) — N=%d countries\n", N_v))
    cat("Long-run coefficients:\n")
    for (j in seq_along(x_names)) {
      stars <- ifelse(mg_p[j]<0.01,"***",ifelse(mg_p[j]<0.05,"**",ifelse(mg_p[j]<0.10,"*","")))
      cat(sprintf("  %-22s β = %7.4f  SE = %.4f  t = %6.3f  p = %.4f %s\n",
                  x_names[j], mg_mean[j], mg_se[j], mg_t[j], mg_p[j], stars))
    }
  }

  list(mg_coef=mg_mean, mg_se=mg_se, mg_t=mg_t, mg_p=mg_p,
       N=N_v, x_names=x_names, lr_matrix=lr_mat)
}

# ── AMG Estimator (Bond & Eberhardt 2009) ─────────────────────────────────────
amg_estimator <- function(y_name, x_names, data, id_var="iso3", time_var="year") {
  data <- data %>% arrange(.data[[id_var]], .data[[time_var]])

  # Step 1: FD pooled regression with year dummies
  df_fd <- data %>%
    group_by(.data[[id_var]]) %>%
    mutate(across(all_of(c(y_name, x_names)),
                  ~c(NA_real_, diff(.)),   # fix: pad with NA to keep length
                  .names="d_{.col}")) %>%
    ungroup() %>%
    drop_na(starts_with("d_"))

  d_y_name <- paste0("d_", y_name)
  d_x_names <- paste0("d_", x_names)

  year_dummies <- model.matrix(~ factor(df_fd[[time_var]]) - 1)
  X_pool <- cbind(as.matrix(df_fd[, d_x_names]), year_dummies)
  Y_pool <- df_fd[[d_y_name]]

  cc  <- complete.cases(X_pool, Y_pool)
  mu_vec <- rep(0, nrow(year_dummies))
  if (sum(cc) > ncol(X_pool)) {
    m_pool <- tryCatch(lm(Y_pool[cc] ~ X_pool[cc,] - 1), error=function(e) NULL)
    if (!is.null(m_pool)) {
      yd_idx <- grep("factor", names(coef(m_pool)))
      if (length(yd_idx) > 0) mu_vec[cc][seq_along(yd_idx)] <- coef(m_pool)[yd_idx]
    }
  }

  # Step 2: Country-by-country OLS augmented with cumsum(μ_t)
  countries <- unique(data[[id_var]])
  lr_coefs  <- vector("list", length(countries))

  for (i in seq_along(countries)) {
    sub <- data %>% filter(.data[[id_var]] == countries[i]) %>% arrange(.data[[time_var]])
    n_i <- nrow(sub)
    mu_i <- if (n_i <= length(mu_vec)) mu_vec[seq_len(n_i)] else
              c(mu_vec, rep(0, n_i - length(mu_vec)))
    mu_cum <- cumsum(replace_na(mu_i, 0))

    X_c <- cbind(1, as.matrix(sub[, x_names]), mu_cum)
    Y_c <- sub[[y_name]]
    cc2 <- complete.cases(X_c, Y_c)
    if (sum(cc2) < ncol(X_c) + 2) next

    m <- tryCatch(lm(Y_c[cc2] ~ X_c[cc2,] - 1), error=function(e) NULL)
    if (is.null(m)) next
    cf <- coef(m)
    if (length(cf) >= 1 + length(x_names)) {
      lr_coefs[[i]] <- cf[2:(1 + length(x_names))]
      names(lr_coefs[[i]]) <- x_names
    }
  }

  valid <- which(!sapply(lr_coefs, is.null))
  N_v   <- length(valid)
  if (N_v < 3) return(NULL)

  lr_mat  <- do.call(rbind, lr_coefs[valid])
  colnames(lr_mat) <- x_names
  mg_mean <- colMeans(lr_mat, na.rm=TRUE)
  mg_se   <- apply(lr_mat, 2, sd, na.rm=TRUE) / sqrt(N_v)
  mg_t    <- mg_mean / mg_se
  mg_p    <- 2 * pt(-abs(mg_t), df=N_v - 1)

  cat(sprintf("\nAMG (Bond & Eberhardt 2009) — N=%d countries\n", N_v))
  for (j in seq_along(x_names)) {
    stars <- ifelse(mg_p[j]<0.01,"***",ifelse(mg_p[j]<0.05,"**",ifelse(mg_p[j]<0.10,"*","")))
    cat(sprintf("  %-22s β = %7.4f  SE = %.4f  t = %6.3f  p = %.4f %s\n",
                x_names[j], mg_mean[j], mg_se[j], mg_t[j], mg_p[j], stars))
  }
  list(mg_coef=mg_mean, mg_se=mg_se, mg_t=mg_t, mg_p=mg_p,
       N=N_v, x_names=x_names, lr_matrix=lr_mat)
}

# ── Run Estimations ───────────────────────────────────────────────────────────
cat("═══ Main Estimation: CCEMG + AMG ═══\n")

res_ccemg <- tryCatch(
  ccemg_estimator("ln_tfp", x_vars_full, df_est),
  error=function(e) { cat("CCEMG error:", conditionMessage(e), "\n"); NULL }
)

res_amg <- tryCatch(
  amg_estimator("ln_tfp", x_vars_full, df_est),
  error=function(e) { cat("AMG error:", conditionMessage(e), "\n"); NULL }
)

# ── Table 5: Main Results ─────────────────────────────────────────────────────
var_labels <- c(
  mps_share  = "MPS Share (coupled)",
  gsse_share = "GSSE Share (decoupled)",
  ln_gdppc   = "ln(GDP per capita)",
  rural_share= "Rural pop. share",
  ln_fert    = "ln(Fertilizer use)",
  ln_agl     = "ln(Agric. land)"
)

build_row <- function(res, method) {
  if (is.null(res)) return(data.frame())
  do.call(rbind, lapply(res$x_names, function(xn) {
    j <- which(res$x_names == xn)
    stars <- ifelse(res$mg_p[j]<0.01,"***",ifelse(res$mg_p[j]<0.05,"**",ifelse(res$mg_p[j]<0.10,"*","")))
    data.frame(
      Variable = var_labels[xn] %||% xn,
      Method   = method,
      Coef     = sprintf("%.4f%s", res$mg_coef[j], stars),
      SE       = sprintf("(%.4f)", res$mg_se[j]),
      stringsAsFactors = FALSE
    )
  }))
}

tab5_long <- bind_rows(
  build_row(res_ccemg, "CCEMG"),
  build_row(res_amg,   "AMG")
)

if (nrow(tab5_long) > 0) {
  tab5_out <- tab5_long %>%
    pivot_wider(names_from=Method, values_from=c(Coef, SE))
  cat("\n\nTable 5 — Long-run Coefficients:\n")
  print(tab5_out, n=Inf)

  tab5_xt <- xtable(tab5_out,
    caption=paste0("Long-run coefficients: CCEMG and AMG estimators. ",
                   "Standard errors in parentheses. *, **, *** = 10\\%, 5\\%, 1\\%."),
    label="tab:main_results"
  )
  print(tab5_xt,
    file=file.path(TBLS, "tab5_main_results.tex"),
    include.rownames=FALSE, booktabs=TRUE, caption.placement="top",
    sanitize.text.function=identity
  )
  cat("→ Saved: tab5_main_results.tex\n")
}

# ── Webb Wild Cluster Bootstrap ────────────────────────────────────────────────
cat("\n── Webb Wild Cluster Bootstrap (N=27 < 30 → mandatory) ──\n")
tryCatch({
  fe_model <- plm(as.formula(paste("ln_tfp ~", paste(x_vars_full, collapse="+"))),
                  data=pdata.frame(df_est, index=c("iso3","year")),
                  model="within", effect="twoways")
  boot_res <- boottest(fe_model, clustid="iso3", param=x_vars_full[1],
                       B=999, type="webb", seed=2026)
  cat(sprintf("Webb bootstrap CI for %s:\n", x_vars_full[1]))
  print(summary(boot_res))
}, error=function(e) cat("Bootstrap note:", conditionMessage(e), "\n"))

cat("\n✓ Step 5 complete.\n")
cat("  Next: source('06_causality_robustness.R')\n")
