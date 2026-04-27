# 03_unit_root.R
# Second-generation panel unit root tests: CIPS / CADF
# PSE × AgTFP OECD | MGO × HBI
#
# Tests: CIPS (Pesaran 2007), CADF, IPS (first-gen, for comparison)
# All variables tested at level I(0) vs first difference I(1)

library(tidyverse); library(plm); library(urca); library(xtable)

CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"

df <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types=FALSE) %>%
  mutate(
    ln_tfp   = log(tfp_index),
    ln_gdppc = log(gdppc_const2015),
    ln_fert  = log(fertilizer_kgha + 0.001),
    ln_agl   = log(agland_share + 0.001),
    # PSE vars — will be NA if not yet merged
    mps_sh   = mps_share,
    gsse_sh  = gsse_share,
    pse_p    = pse_pct
  )

# ── CIPS Implementation (Pesaran 2007) ────────────────────────────────────────
# CIPS = cross-sectionally augmented IPS
# t_iCADF_i = OLS t-stat from: Δy_{it} = a_i + b_i*y_{i,t-1} + c_i*ȳ_{t-1} + Σd_ij*Δȳ_{t-j} + ε

cips_test <- function(x, id, time, max_lag=2, trend=FALSE) {
  df_x <- data.frame(id=id, time=time, x=x) %>%
    arrange(id, time) %>%
    drop_na(x)

  countries <- unique(df_x$id)
  years     <- sort(unique(df_x$time))
  N <- length(countries)
  T <- length(years)

  # Cross-section means
  cs_means <- df_x %>%
    group_by(time) %>%
    summarise(x_bar = mean(x, na.rm=TRUE), .groups="drop")
  df_x <- left_join(df_x, cs_means, by="time")

  cadf_stats <- numeric(N)

  for (i in seq_along(countries)) {
    sub <- df_x %>% filter(id == countries[i]) %>% arrange(time)
    y   <- sub$x
    yb  <- sub$x_bar
    T_i <- length(y)
    if (T_i < max_lag + 4) { cadf_stats[i] <- NA; next }

    # Build regressors
    dy  <- diff(y)
    dyb <- diff(yb)
    y1  <- y[-T_i]          # y_{t-1}
    yb1 <- yb[-T_i]         # ȳ_{t-1}
    n_obs <- length(dy)

    # Lag matrix
    lag_mat <- matrix(NA, nrow=n_obs, ncol=0)
    for (lag in 1:max_lag) {
      if (n_obs - lag < 1) break
      dy_lag  <- c(rep(NA, lag), dy)[1:n_obs]
      dyb_lag <- c(rep(NA, lag), dyb)[1:n_obs]
      lag_mat <- cbind(lag_mat, dy_lag, dyb_lag)
    }

    # Trim to complete cases
    if (trend) {
      trend_vec <- seq_len(n_obs)
      X <- cbind(1, y1[seq_len(n_obs)], yb1[seq_len(n_obs)], dyb[seq_len(n_obs)], lag_mat, trend_vec)
    } else {
      X <- cbind(1, y1[seq_len(n_obs)], yb1[seq_len(n_obs)], dyb[seq_len(n_obs)], lag_mat)
    }
    Y <- dy

    cc <- complete.cases(X, Y)
    if (sum(cc) < ncol(X) + 2) { cadf_stats[i] <- NA; next }
    X <- X[cc,]; Y <- Y[cc]

    m <- tryCatch(lm(Y ~ X - 1), error=function(e) NULL)
    if (is.null(m)) { cadf_stats[i] <- NA; next }

    # t-stat on y_{t-1} coefficient (column 2 of X)
    se <- tryCatch(sqrt(diag(vcov(m)))[2], error=function(e) NA)
    cadf_stats[i] <- coef(m)[2] / se
  }

  cips_stat  <- mean(cadf_stats, na.rm=TRUE)
  n_valid    <- sum(!is.na(cadf_stats))

  # Critical values (Pesaran 2007, Table 2, no-trend)
  cv_nt <- list(`1%`=-2.57, `5%`=-2.33, `10%`=-2.21)
  cv_tr <- list(`1%`=-3.10, `5%`=-2.86, `10%`=-2.73)
  cv <- if (trend) cv_tr else cv_nt

  list(
    CIPS = cips_stat,
    n_valid = n_valid,
    cv_1pct = cv[["1%"]], cv_5pct = cv[["5%"]], cv_10pct = cv[["10%"]],
    decision_5pct = ifelse(cips_stat < cv[["5%"]], "I(0) - Stationary", "I(1) - Non-stationary"),
    cadf_i = cadf_stats
  )
}

# ── Run CIPS for all key variables ────────────────────────────────────────────
cat("═══ Panel Unit Root Tests (CIPS) ═══\n")
cat("H0: Unit root (non-stationary) | H1: No unit root (stationary)\n\n")

vars_to_test <- list(
  ln_tfp   = "ln(AgTFP)",
  ln_gdppc = "ln(GDP per capita)",
  rural_share = "Rural share",
  ln_fert  = "ln(Fertilizer)",
  ln_agl   = "ln(Agric. land)"
)

# Add PSE vars if available
if ("pse_pct" %in% names(df) && !all(is.na(df$pse_pct))) {
  vars_to_test[["pse_p"]]  <- "% PSE"
  vars_to_test[["mps_sh"]] <- "MPS Share"
  vars_to_test[["gsse_sh"]]<- "GSSE Share"
}

results_list <- vector("list", length(vars_to_test))
names(results_list) <- names(vars_to_test)

for (vname in names(vars_to_test)) {
  cat(sprintf("Testing: %s ...\n", vars_to_test[[vname]]))

  x_vec <- df[[vname]]
  id_vec   <- df$iso3
  time_vec <- df$year

  # Level (no trend + with trend)
  res_nt <- tryCatch(
    cips_test(x_vec, id_vec, time_vec, max_lag=2, trend=FALSE),
    error=function(e) list(CIPS=NA, decision_5pct="Error", cv_5pct=NA)
  )
  res_tr <- tryCatch(
    cips_test(x_vec, id_vec, time_vec, max_lag=2, trend=TRUE),
    error=function(e) list(CIPS=NA, decision_5pct="Error", cv_5pct=NA)
  )

  # First difference
  df_diff <- df %>%
    group_by(iso3) %>%
    mutate(dx = c(NA, diff(.data[[vname]]))) %>%
    ungroup()
  res_fd_nt <- tryCatch(
    cips_test(df_diff$dx, df_diff$iso3, df_diff$year, max_lag=1, trend=FALSE),
    error=function(e) list(CIPS=NA, decision_5pct="Error", cv_5pct=NA)
  )

  results_list[[vname]] <- list(
    label = vars_to_test[[vname]],
    level_nt = res_nt,
    level_tr = res_tr,
    diff_nt  = res_fd_nt
  )

  cat(sprintf("  Level (no trend): CIPS=%.3f → %s\n", res_nt$CIPS, res_nt$decision_5pct))
  cat(sprintf("  Level (trend):    CIPS=%.3f → %s\n", res_tr$CIPS, res_tr$decision_5pct))
  cat(sprintf("  1st diff (NT):    CIPS=%.3f → %s\n\n", res_fd_nt$CIPS, res_fd_nt$decision_5pct))
}

# ── Table 3: Unit Root Summary ─────────────────────────────────────────────────
tab3_rows <- lapply(names(results_list), function(vn) {
  r <- results_list[[vn]]
  data.frame(
    Variable        = r$label,
    `Level (NT)`    = ifelse(is.na(r$level_nt$CIPS), "—",
                             sprintf("%.3f [%s]", r$level_nt$CIPS, r$level_nt$decision_5pct)),
    `Level (Trend)` = ifelse(is.na(r$level_tr$CIPS), "—",
                             sprintf("%.3f [%s]", r$level_tr$CIPS, r$level_tr$decision_5pct)),
    `1st Diff (NT)` = ifelse(is.na(r$diff_nt$CIPS), "—",
                             sprintf("%.3f [%s]", r$diff_nt$CIPS, r$diff_nt$decision_5pct)),
    check.names     = FALSE
  )
})
tab3 <- do.call(rbind, tab3_rows)
cat("\nTable 3 — CIPS Unit Root Results:\n")
print(tab3)

tab3_xt <- xtable(tab3,
  caption = paste0("Panel Unit Root Tests (CIPS, Pesaran 2007). ",
                   "Critical values (no trend): −2.57 (1\\%), −2.33 (5\\%), −2.21 (10\\%)."),
  label = "tab:unitroot"
)
print(tab3_xt,
  file=file.path(TBLS, "tab3_unit_root.tex"),
  include.rownames=FALSE, booktabs=TRUE, caption.placement="top",
  sanitize.text.function=identity
)
cat("→ Saved: tab3_unit_root.tex\n")
cat("✓ Step 3 complete.\n")
cat("  Next: source('04_cointegration.R')\n")
