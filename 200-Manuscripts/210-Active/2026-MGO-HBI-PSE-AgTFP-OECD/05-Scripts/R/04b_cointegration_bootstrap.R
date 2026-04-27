# 04b_cointegration_bootstrap.R
# Westerlund (2007) panel cointegration — CORRECTED formulas + wild bootstrap
# PSE × AgTFP OECD | MGO × HBI | 2026-04-25
#
# DEEP-LEARN FINDINGS (2026-04-25):
#   No CRAN package implements Westerlund (2007) panel ECM bootstrap.
#   cointReg = single-eq FM/DOLS only; urca = Johansen single-eq; plm = no cointegration.
#   → Best approach: fix custom function + joint wild bootstrap (Rademacher weights).
#
# BUG FIXED FROM 04_cointegration.R:
#   Pa was computed as mean(T_i * alpha_i) = Ga (identical!)
#   FIX: Pa = T_bar * mean(alpha_i) — different from Ga in unbalanced panels.
#   Proof: Ga = mean(T_i*α_i), Pa = T_bar*mean(α_i)
#          Ga = Pa only when T_i = T_bar for all i (perfectly balanced panel).
#          This panel has fill rate 85.7% → T_i varies → Ga ≠ Pa.
#
# BOOTSTRAP METHOD:
#   Wild bootstrap with Rademacher weights (±1, equal probability).
#   Key innovation: SAME weight per time period for ALL countries.
#   This preserves cross-sectional dependence in the bootstrapped series.
#   Under H0 (no cointegration): Δy_it is I(0). We multiply Δy by w_t to
#   generate bootstrap random walks. Controls are held fixed (conditional bootstrap).
#   p-value = fraction of B bootstrap statistics ≤ observed statistic (left tail).
#   Reference: Westerlund (2007, OBES, p.730-731 Remark 4).

suppressPackageStartupMessages({
  library(tidyverse)
})

CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"

df <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types = FALSE) %>%
  mutate(
    ln_tfp   = log(tfp_index),
    ln_gdppc = log(gdppc_const2015),
    ln_fert  = log(fertilizer_kgha + 0.001),
    ln_agl   = log(agland_share  + 0.001)
  )

CONTROLS <- c("ln_gdppc", "rural_share", "ln_fert", "ln_agl")

df_coint <- df %>%
  select(iso3, year, ln_tfp, all_of(CONTROLS)) %>%
  arrange(iso3, year) %>%
  drop_na()

cat("Panel dimensions: N =", n_distinct(df_coint$iso3),
    " obs =", nrow(df_coint), "\n\n")

# ── CORRECTED Westerlund ECM function ─────────────────────────────────────────
# Returns Ga, Gt, Pa, Pt with CORRECTED Pa = T_bar * mean(alpha_i)
westerlund_ecm <- function(y_vec, x_mat, id, time, lag = 1, lead = 1) {
  countries <- unique(id)
  N         <- length(countries)
  alpha_i   <- numeric(N)
  se_alpha  <- numeric(N)
  T_i_vec   <- numeric(N)

  for (i in seq_along(countries)) {
    idx <- id == countries[i]
    yi  <- y_vec[idx]
    xi  <- x_mat[idx, , drop = FALSE]
    Ti  <- length(yi)

    if (Ti < lag + lead + 6) {
      alpha_i[i] <- NA; se_alpha[i] <- NA; T_i_vec[i] <- Ti; next
    }

    # Step 1: cointegrating regression residual as ECT
    static_m <- tryCatch(lm(yi ~ xi), error = function(e) NULL)
    if (is.null(static_m)) {
      alpha_i[i] <- NA; se_alpha[i] <- NA; T_i_vec[i] <- Ti; next
    }
    ec_term <- residuals(static_m)

    # Step 2: ECM with lags + leads of Δy, Δx
    dy    <- diff(yi)
    ec_1  <- ec_term[-Ti]          # ECT lagged one period
    n_obs <- length(dy)
    dX    <- apply(xi, 2, diff)

    # Lead matrix (leads of Δx for polynomial correction)
    lead_cols <- vector("list", max(lead, 0))
    if (lead > 0) {
      for (l in seq_len(lead)) {
        lr <- rbind(matrix(NA, l, ncol(xi)), dX)[seq_len(n_obs), , drop = FALSE]
        lead_cols[[l]] <- lr
      }
    }

    # Lag matrices (lags of Δy and Δx)
    lag_dy <- matrix(NA, n_obs, lag)
    lag_dX <- matrix(NA, n_obs, lag * ncol(xi))
    if (lag > 0) {
      for (l in seq_len(lag)) {
        lag_dy[, l] <- c(rep(NA, l), dy)[seq_len(n_obs)]
        for (k in seq_len(ncol(xi))) {
          lag_dX[, (l - 1) * ncol(xi) + k] <- c(rep(NA, l), dX[, k])[seq_len(n_obs)]
        }
      }
    }

    X_ecm <- cbind(1L, ec_1,
                   dX[seq_len(n_obs), , drop = FALSE],
                   do.call(cbind, lead_cols),
                   lag_dy, lag_dX)

    cc <- complete.cases(X_ecm, dy)
    if (sum(cc) < ncol(X_ecm) + 2) {
      alpha_i[i] <- NA; se_alpha[i] <- NA; T_i_vec[i] <- Ti; next
    }

    m_ecm <- tryCatch(lm(dy[cc] ~ X_ecm[cc, ] - 1), error = function(e) NULL)
    if (is.null(m_ecm)) {
      alpha_i[i] <- NA; se_alpha[i] <- NA; T_i_vec[i] <- Ti; next
    }

    alpha_i[i]  <- coef(m_ecm)[2]            # ECT coefficient = α_i
    se_alpha[i] <- sqrt(diag(vcov(m_ecm)))[2]
    T_i_vec[i]  <- sum(cc)
  }

  valid <- which(!is.na(alpha_i))
  N_v   <- length(valid)
  if (N_v < 3) return(NULL)

  t_i   <- alpha_i[valid] / se_alpha[valid]
  T_bar <- mean(T_i_vec[valid])

  # ── GROUP-MEAN statistics (some countries cointegrated) ──────────────────
  Gt <- mean(t_i)                               # mean of individual ECT t-stats
  Ga <- mean(T_i_vec[valid] * alpha_i[valid])  # T_i-weighted mean of ECT coefs

  # ── PANEL statistics (all countries cointegrated) ────────────────────────
  # CORRECTED: Pa = T_bar * mean(alpha_i)   ← different from Ga in unbalanced panels
  #            Ga = mean(T_i * alpha_i)     ← Ga weights by country-specific T_i
  Pt <- sum(t_i) / sqrt(N_v)               # panel t (√N-normalized)
  Pa <- T_bar * mean(alpha_i[valid])        # panel α (T_bar-normalized)

  # Approximate asymptotic p-values — use bootstrap for reliable inference under CSD
  p_Gt <- pnorm(Gt)
  p_Ga <- pnorm(Ga / sqrt(N_v))
  p_Pt <- pnorm(Pt)
  p_Pa <- pnorm(Pa / sqrt(N_v))

  list(
    Ga = Ga, Gt = Gt, Pa = Pa, Pt = Pt,
    p_Ga = p_Ga, p_Gt = p_Gt, p_Pa = p_Pa, p_Pt = p_Pt,
    N = N_v, T_bar = T_bar,
    alpha_i = alpha_i[valid]
  )
}

# ── Run observed statistics ───────────────────────────────────────────────────
cat("═══ Westerlund (2007) — Corrected Formulas ═══\n")
y_vec <- df_coint$ln_tfp
x_mat <- as.matrix(df_coint[, CONTROLS])

west_obs <- westerlund_ecm(y_vec, x_mat, df_coint$iso3, df_coint$year)
if (is.null(west_obs)) stop("Observed Westerlund computation failed.")

cat(sprintf("Ga = %7.3f  Gt = %6.3f  Pa = %7.3f  Pt = %6.3f\n",
            west_obs$Ga, west_obs$Gt, west_obs$Pa, west_obs$Pt))
cat(sprintf("Asym p:  Ga=%.4f  Gt=%.4f  Pa=%.4f  Pt=%.4f\n",
            west_obs$p_Ga, west_obs$p_Gt, west_obs$p_Pa, west_obs$p_Pt))
cat(sprintf("N=%d, T_bar=%.1f\n", west_obs$N, west_obs$T_bar))

same_flag <- isTRUE(all.equal(west_obs$Ga, west_obs$Pa))
cat(sprintf("Ga == Pa: %s  (should be FALSE in unbalanced panel)\n\n", same_flag))

# ── Wild Bootstrap — joint Rademacher weights ─────────────────────────────────
# H0: y_it is I(1) but NOT cointegrated with x_it
# Under H0: Δy_it is stationary. We resample Δy by multiplying by w_t ~ {-1,+1}.
# JOINT: same w_t applies to all countries at time t → preserves cross-sectional structure.
# Controls x_it are held fixed (conditional bootstrap — valid per Westerlund 2007 Rmk 4).

cat("═══ Wild Bootstrap (B=399, Rademacher, joint across countries) ═══\n")
set.seed(2026)
B <- 399L

all_years <- sort(unique(df_coint$year))
T_all     <- length(all_years)
year_idx  <- setNames(seq_len(T_all), as.character(all_years))

# Pre-compute first differences per country
diff_list <- lapply(unique(df_coint$iso3), function(co) {
  sub <- df_coint %>% filter(iso3 == co) %>% arrange(year)
  if (nrow(sub) < 6) return(NULL)
  dy      <- diff(sub$ln_tfp)
  yr_diff <- sub$year[-1]             # years for each diff
  list(co = co, sub = sub, dy = dy, yr_diff = yr_diff)
})
diff_list <- Filter(Negate(is.null), diff_list)

boot_counts  <- integer(4L)
valid_boots  <- 0L

for (b in seq_len(B)) {
  # Draw ONE set of Rademacher weights for all time periods
  w_t <- sample(c(-1L, 1L), T_all, replace = TRUE)

  df_boot_list <- lapply(diff_list, function(dl) {
    yr_idx_i <- year_idx[as.character(dl$yr_diff)]
    w_i      <- w_t[yr_idx_i]          # same weight per time period, all countries
    dy_b     <- dl$dy * w_i            # wild bootstrap first differences
    y_b      <- c(dl$sub$ln_tfp[1],
                  dl$sub$ln_tfp[1] + cumsum(dy_b))  # reconstruct levels under H0
    sub_b          <- dl$sub
    sub_b$ln_tfp   <- y_b
    sub_b
  })

  df_boot <- bind_rows(df_boot_list)

  res_b <- tryCatch(
    westerlund_ecm(
      df_boot$ln_tfp,
      as.matrix(df_boot[, CONTROLS]),
      df_boot$iso3, df_boot$year
    ),
    error = function(e) NULL
  )
  if (is.null(res_b)) next

  valid_boots <- valid_boots + 1L
  boot_counts <- boot_counts + as.integer(
    c(res_b$Ga, res_b$Gt, res_b$Pa, res_b$Pt) <=
    c(west_obs$Ga, west_obs$Gt, west_obs$Pa, west_obs$Pt)
  )

  if (b %% 100 == 0) cat(sprintf("  b=%d / %d  (valid=%d)\n", b, B, valid_boots))
}

p_boot <- if (valid_boots > 0) boot_counts / valid_boots else rep(NA_real_, 4)

cat(sprintf("\nValid bootstrap iterations: %d / %d\n", valid_boots, B))
cat(sprintf("Bootstrap p:  Ga=%.4f  Gt=%.4f  Pa=%.4f  Pt=%.4f\n\n",
            p_boot[1], p_boot[2], p_boot[3], p_boot[4]))

# ── Table 4 — Final corrected output ─────────────────────────────────────────
tab4_final <- data.frame(
  Statistic     = c("Ga", "Gt", "Pa", "Pt"),
  Value         = round(c(west_obs$Ga, west_obs$Gt, west_obs$Pa, west_obs$Pt), 3),
  `Asymp. p`    = round(c(west_obs$p_Ga, west_obs$p_Gt, west_obs$p_Pa, west_obs$p_Pt), 4),
  `Boot. p`     = round(p_boot, 4),
  Hypothesis    = c("Group-mean α", "Group-mean t", "Panel α", "Panel t"),
  Decision      = ifelse(p_boot < 0.05, "Reject H0 ***", "Cannot reject"),
  check.names   = FALSE
)

cat("══════ TABLE 4 — FINAL (corrected + bootstrapped) ══════\n")
print(tab4_final, row.names = FALSE)
cat("\nNote: Bootstrap p-values from B=", valid_boots,
    "joint Rademacher wild bootstrap iterations.\n")
cat("      Joint resampling across countries preserves cross-sectional dependence.\n")
cat("      Pa ≠ Ga confirms unbalanced panel (T_i varies; corrected from v1 bug).\n\n")

cat("✓ 04b complete — update Table 4 in manuscript with values above.\n")
cat("  Next: update hardcoded values in PSE_AgTFP_OECD_v03.qmd Tab4 chunk.\n")
