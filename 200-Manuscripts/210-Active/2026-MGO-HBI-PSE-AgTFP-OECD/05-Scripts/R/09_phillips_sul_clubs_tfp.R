# =============================================================================
# Script 09 — Phillips-Sul Convergence Clubs: AgTFP Paths, OECD-27
# Paper: "Agricultural Support Policy Composition and Total Factor Productivity:
#          A Panel Analysis of OECD Countries"
# Author: Res. Asst. Dr. M. Gökhan Özdemir × Prof. Dr. H. Bayram Işık
# Target: Food Policy (Q1, IF≈6.5)
# Version: 2026-04-24
#
# PURPOSE:
#   Test whether OECD-27 countries converge in agricultural TFP (ln_tfp) paths.
#   Club divergence validates CCEMG heterogeneous estimator and motivates the
#   finding that PSE composition effects differ structurally across countries.
#
#   Test variables:
#     (1) ln_tfp        — primary; does OECD converge in agricultural productivity?
#     (2) ln_mps        — secondary; do MPS support levels converge?
#     (3) ln_gsse       — secondary; do GSSE support levels converge?
#
# Literature:
#   Phillips & Sul (2007) — doi:10.1111/j.1468-0262.2007.00811.x
#   Sichera & Pizzuto (2019) — doi:10.32614/RJ-2019-021
# =============================================================================

for (pkg in c("ConvergenceClubs", "ggplot2", "dplyr", "tidyr")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
}
library(ConvergenceClubs)
library(ggplot2)
library(dplyr)
library(tidyr)

BASE_PATH <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-MGO-HBI-PSE-AgTFP-OECD"
DATA_PATH <- file.path(BASE_PATH, "06-Data/clean")
FIG_PATH  <- file.path(BASE_PATH, "03-Results/figures")
dir.create(FIG_PATH, recursive = TRUE, showWarnings = FALSE)

# --- 1. Data -----------------------------------------------------------------
panel_file <- if (file.exists(file.path(DATA_PATH, "panel_master_v2.csv")))
  file.path(DATA_PATH, "panel_master_v2.csv") else
  file.path(DATA_PATH, "panel_master.csv")

panel_long <- read.csv(panel_file, stringsAsFactors = FALSE)
cat("Panel:", nrow(panel_long), "obs\n")
cat("N =", length(unique(panel_long$iso3)),
    "| T =", length(unique(panel_long$year)), "\n")
cat("Countries:", paste(sort(unique(panel_long$iso3)), collapse = ", "), "\n")
cat("Years:", min(panel_long$year), "–", max(panel_long$year), "\n\n")

# --- 2. Wide format ----------------------------------------------------------
make_wide <- function(df, id_col, time_col, var) {
  df %>%
    select(all_of(c(id_col, time_col, var))) %>%
    filter(!is.na(!!sym(var))) %>%
    pivot_wider(names_from = all_of(time_col), values_from = all_of(var)) %>%
    as.data.frame()
}

# --- 3. Hand-coded log-t test ------------------------------------------------
logt_test <- function(panel_wide) {
  X      <- as.matrix(panel_wide[, -1])
  N_c    <- nrow(X)
  T_c    <- ncol(X)
  H      <- matrix(NA, N_c, T_c)
  for (t in 1:T_c) H[, t] <- X[, t] / mean(X[, t])
  V_t    <- apply((H - 1)^2, 2, mean)
  trim_s <- ceiling(T_c / 3) + 1
  t_trim <- trim_s:T_c

  y_raw  <- log(V_t[1] / V_t[t_trim]) - 2 * log(log(t_trim))
  x_raw  <- log(t_trim)
  ok     <- is.finite(y_raw) & is.finite(x_raw)
  y_reg  <- y_raw[ok]; x_reg <- x_raw[ok]; T_u <- length(y_reg)

  if (T_u < 5) {
    warning("Too few finite obs for log-t (", T_u, ")")
    return(list(b_hat = NA, se = NA, t_stat = NA, lags = 0, T_used = T_u))
  }

  fit    <- lm(y_reg ~ x_reg)
  b_hat  <- coef(fit)["x_reg"]
  n_lags <- max(1L, floor(T_u^(1/4)))
  e      <- residuals(fit)
  X_mat  <- cbind(1, x_reg)
  XX_inv <- solve(t(X_mat) %*% X_mat)
  S      <- t(X_mat) %*% diag(e^2) %*% X_mat
  for (l in 1:n_lags) {
    w    <- 1 - l / (n_lags + 1)
    n_e  <- length(e); idx <- (l+1):n_e
    Sl   <- t(X_mat[idx,,drop=FALSE]) %*%
            diag(e[idx]*e[1:(n_e-l)]) %*% X_mat[idx,,drop=FALSE]
    S    <- S + w * (Sl + t(Sl))
  }
  se_b   <- sqrt((XX_inv %*% S %*% XX_inv)[2, 2])
  list(b_hat = b_hat, se = se_b, t_stat = b_hat / se_b,
       lags = n_lags, T_used = T_u)
}

# --- 4. Main analysis --------------------------------------------------------
run_analysis <- function(var, label) {
  cat(paste(rep("=", 65), collapse = ""), "\n")
  cat("VARIABLE:", label, "(", var, ")\n")
  cat(paste(rep("=", 65), collapse = ""), "\n")

  pw <- make_wide(panel_long, "iso3", "year", var)
  pw_cc <- pw[complete.cases(pw), ]
  n_drop <- nrow(pw) - nrow(pw_cc)
  if (n_drop > 0)
    cat("Dropped", n_drop, "countries with NAs:",
        setdiff(pw[,1], pw_cc[,1]), "\n")

  T_pw <- ncol(pw_cc) - 1

  logt <- logt_test(pw_cc)
  cat("\nFull-panel log-t:\n")
  cat("  b_hat =", round(logt$b_hat, 4), "\n")
  cat("  SE    =", round(logt$se, 4), "(HAC lags =", logt$lags,
      "| T_used =", logt$T_used, ")\n")
  cat("  t-stat=", round(logt$t_stat, 4), "| 5% critical: −1.65\n")
  decision <- if (is.na(logt$t_stat)) "INSUFFICIENT DATA" else
              if (logt$t_stat < -1.65) "REJECT H0 — panel diverges (clubs expected)" else
              "FAIL TO REJECT — panel convergence"
  cat("  →", decision, "\n")

  # Club detection
  cat("\nClub detection:\n")
  clubs <- tryCatch(
    findClubs(pw_cc, dataCols = 2:(T_pw+1), unit_names = 1,
              refCol = T_pw+1, time_trim = 1/3,
              HACmethod = "FQSB", cstar = 0),
    error = function(e) { cat("findClubs error:", conditionMessage(e), "\n"); NULL }
  )
  if (!is.null(clubs)) print(summary(clubs))

  merged <- tryCatch(
    mergeClubs(clubs, time_trim = 1/3, mergeMethod = "PS", mergeDivergent = FALSE),
    error = function(e) { cat("Merge:", conditionMessage(e), "\n"); clubs }
  )
  if (!is.null(merged) && !identical(merged, clubs)) {
    cat("After merging:\n"); print(summary(merged))
  }

  list(pw = pw_cc, clubs = clubs, merged = merged,
       b_hat = logt$b_hat, t_stat = logt$t_stat)
}

vars   <- c("ln_tfp", "ln_mps", "ln_gsse")
labels <- c("Agricultural TFP (log)", "Market Price Support (log)", "GSSE Support (log)")

results <- setNames(
  lapply(seq_along(vars), function(i) run_analysis(vars[i], labels[i])),
  vars
)

# --- 5. Transition path plots ------------------------------------------------
extract_clubs <- function(club_obj) {
  if (is.null(club_obj)) return(NULL)
  nms <- names(club_obj)[grepl("^club", names(club_obj))]
  rows <- lapply(seq_along(nms), function(i)
    data.frame(country = club_obj[[nms[i]]]$unit_names,
               club = i, stringsAsFactors = FALSE))
  out <- do.call(rbind, rows)
  if (!is.null(club_obj$divergent) && length(club_obj$divergent$unit_names) > 0)
    out <- rbind(out, data.frame(country = club_obj$divergent$unit_names,
                                 club = NA, stringsAsFactors = FALSE))
  out
}

plot_transitions <- function(var, label, res) {
  pw <- res$pw
  co <- if (!is.null(res$merged)) res$merged else res$clubs
  X  <- as.matrix(pw[, -1])
  ct <- pw[, 1]
  yr <- as.integer(colnames(pw)[-1])
  T_c <- ncol(X)
  H   <- matrix(NA, nrow(X), T_c)
  for (t in 1:T_c) H[, t] <- X[, t] / mean(X[, t])
  H_df         <- as.data.frame(H)
  colnames(H_df) <- as.character(yr)
  H_df$country <- ct
  ca <- extract_clubs(co)
  if (is.null(ca)) ca <- data.frame(country=ct, club=1, stringsAsFactors=FALSE)

  H_long <- H_df %>%
    pivot_longer(-country, names_to="year", values_to="h") %>%
    mutate(year = as.integer(year)) %>%
    left_join(ca, by="country") %>%
    mutate(club_label = case_when(is.na(club)~"Divergent",
                                  TRUE~paste0("Club ",club)))

  pal  <- c("#2166AC","#D7191C","#1A9641","#F4A582","#762A83","#E66101","grey50")
  ltp  <- c("solid","dashed","dotdash","longdash","twodash","dotted","dotted")
  labs_u <- sort(unique(H_long$club_label))
  p_pal  <- setNames(pal[seq_along(labs_u)], labs_u)
  p_ltp  <- setNames(ltp[seq_along(labs_u)], labs_u)

  ggplot(H_long, aes(year, h, colour=club_label, group=country, linetype=club_label)) +
    geom_hline(yintercept=1, linetype="dotted", colour="grey40", linewidth=0.4) +
    geom_line(linewidth=0.75, alpha=0.85) +
    scale_colour_manual(values=p_pal) +
    scale_linetype_manual(values=p_ltp) +
    geom_text(data=H_long %>% filter(year==max(year)),
              aes(label=country), hjust=-0.15, size=2.6, show.legend=FALSE) +
    scale_x_continuous(expand=expansion(mult=c(0.02,0.14))) +
    labs(
      title    = paste0("Relative Transition Paths — ", label),
      subtitle = paste0("Phillips-Sul (2007): b=", round(res$b_hat,3),
                        ", t=", round(res$t_stat,3)),
      x=NULL, y="Relative transition h(it)",
      colour="Club", linetype="Club",
      caption = paste0("h(it) = x(it)/mean_i(x(it)). Convergence ↔ h(it)→1.\n",
                       "OECD panel N=", nrow(pw), ", T=", T_c,
                       " (", min(yr), "–", max(yr), ").")
    ) +
    theme_minimal(base_size=11) +
    theme(legend.position="right", panel.grid.minor=element_blank(),
          plot.title=element_text(face="bold"),
          plot.caption=element_text(size=7.5, colour="grey40"))
}

cat("\n=== Generating figures ===\n")
for (i in seq_along(vars)) {
  p <- plot_transitions(vars[i], labels[i], results[[vars[i]]])
  f <- file.path(FIG_PATH, paste0("figA_ps_clubs_", vars[i], ".png"))
  ggsave(f, p, width=8, height=5, dpi=300)
  cat("Saved:", f, "\n")
}

# --- 6. Summary table --------------------------------------------------------
cat("\n=== APPENDIX TABLE: Log-t Test — OECD AgTFP Panel ===\n")
cat(sprintf("%-40s %8s %8s %20s\n", "Variable", "b_hat", "t-stat", "Decision"))
cat(paste(rep("-", 76), collapse=""), "\n")
for (i in seq_along(vars)) {
  r   <- results[[vars[i]]]
  dec <- ifelse(is.na(r$t_stat), "N/A",
                ifelse(r$t_stat < -1.65, "Divergent (clubs)", "Convergent"))
  cat(sprintf("%-40s %8.3f %8.3f %20s\n", labels[i],
              r$b_hat, r$t_stat, dec))
}
cat("\nNote: H0: b ≥ 0 (convergence). Reject at t < −1.65 (5%).\n")

# --- 7. Manuscript snippet ---------------------------------------------------
tfp_t <- round(results[["ln_tfp"]]$t_stat, 3)
tfp_b <- round(results[["ln_tfp"]]$b_hat, 3)

cat("\n=== MANUSCRIPT APPENDIX LANGUAGE ===\n")
if (!is.na(tfp_t) && tfp_t < -1.65) {
  cat(sprintf(paste0(
    "Phillips-Sul (2007) log-t tests reject full-panel convergence in agricultural\n",
    "TFP (b=%.3f, t=%.3f < −1.65), revealing distinct club structure within the\n",
    "OECD panel. This cross-country heterogeneity validates the CCEMG mean-group\n",
    "estimator and implies that PSE composition effects on productivity differ\n",
    "structurally across economies — consistent with the investment lag mechanism\n",
    "and GSSE composition heterogeneity documented in Tables 5-8.\n"
  ), tfp_b, tfp_t))
} else if (!is.na(tfp_t)) {
  cat(sprintf(paste0(
    "Phillips-Sul (2007) log-t tests do not reject full-panel TFP convergence\n",
    "(b=%.3f, t=%.3f), suggesting a common long-run TFP trajectory within the OECD.\n",
    "This is consistent with technology diffusion across high-income agricultural\n",
    "economies. Heterogeneity in PSE composition effects is nevertheless confirmed\n",
    "by the CCEMG slope heterogeneity test (Δ̃=29273, p=0.000).\n"
  ), tfp_b, tfp_t))
}

cat("\n✓ Rank 8b (PS Clubs) complete. 3 figures: figA_ps_clubs_*.png\n")
cat("✓ Add convergence table to Appendix of PSE × AgTFP manuscript.\n")
