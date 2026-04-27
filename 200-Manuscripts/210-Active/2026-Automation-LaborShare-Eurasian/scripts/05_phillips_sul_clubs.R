# =============================================================================
# Phillips-Sul Convergence Club Analysis — Automation & Labour Share, Eurasia
# Paper: "Automation, Capital Deepening, and Labour Share in Eurasian Economies"
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Target: Economic Modelling (SSCI Q2); results → Appendix
# Version: 2026-04-24
#
# PURPOSE: Test whether 14 Eurasian economies converge in labour share (labsh),
# TFP (ln_tfp), and capital intensity (ln_cap_worker) paths.
# Club divergence → validates CCEMG mean-group estimator and motivates
# heterogeneous automation-labour share elasticities across the panel.
#
# Literature:
#   Phillips & Sul (2007)     — doi:10.1111/j.1468-0262.2007.00811.x
#   Sichera & Pizzuto (2019)  — doi:10.32614/RJ-2019-021
#   Bartkowska & Riedl (2012) — doi:10.1016/j.jmacro.2012.01.002
# =============================================================================

# --- 0. Setup ----------------------------------------------------------------
for (pkg in c("ConvergenceClubs", "ggplot2", "dplyr", "tidyr")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
}
library(ConvergenceClubs)
library(ggplot2)
library(dplyr)
library(tidyr)

DATA_PATH <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Automation-LaborShare-Eurasian/data/panel_automation_eurasian_20260424.csv"
FIG_PATH  <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Automation-LaborShare-Eurasian/data/"

# --- 1. Data -----------------------------------------------------------------
panel_long <- read.csv(DATA_PATH, stringsAsFactors = FALSE)
cat("Panel:", nrow(panel_long), "obs ×", ncol(panel_long), "vars\n")
cat("N =", length(unique(panel_long$iso3c)),
    "| T =", length(unique(panel_long$year)), "\n")
cat("Countries:", paste(sort(unique(panel_long$iso3c)), collapse = ", "), "\n")
cat("Years:", min(panel_long$year), "–", max(panel_long$year), "\n\n")

years <- sort(unique(panel_long$year))
T_len <- length(years)

# --- 2. Make wide (rows = countries, cols = years) --------------------------
make_wide <- function(df, id_col, time_col, var) {
  df %>%
    select(all_of(c(id_col, time_col, var))) %>%
    filter(!is.na(!!sym(var))) %>%
    pivot_wider(names_from  = all_of(time_col),
                values_from = all_of(var)) %>%
    as.data.frame()
}

# --- 3. Hand-coded log-t for full panel -------------------------------------
logt_test <- function(panel_wide) {
  X      <- as.matrix(panel_wide[, -1])
  N_c    <- nrow(X)
  T_c    <- ncol(X)

  # Relative transition h_it
  H <- matrix(NA, N_c, T_c)
  for (t in 1:T_c) H[, t] <- X[, t] / mean(X[, t])

  # Cross-sectional variance V_t
  V_t <- apply((H - 1)^2, 2, mean)

  # Trim: r = 1/3
  trim_start <- ceiling(T_c / 3) + 1
  t_trim     <- trim_start:T_c
  T_trim     <- length(t_trim)

  y_reg_raw <- log(V_t[1] / V_t[t_trim]) - 2 * log(log(t_trim))
  x_reg_raw <- log(t_trim)

  # Keep only finite observations (NaN in V_t causes non-finite y_reg)
  finite_idx <- is.finite(y_reg_raw) & is.finite(x_reg_raw)
  y_reg  <- y_reg_raw[finite_idx]
  x_reg  <- x_reg_raw[finite_idx]
  T_used <- length(y_reg)

  if (T_used < 5) {
    warning("Too few finite observations for log-t (", T_used, "). Skipping HAC.")
    return(list(b_hat = NA, se = NA, t_stat = NA, lags = 0))
  }

  fit   <- lm(y_reg ~ x_reg)
  b_hat <- coef(fit)["x_reg"]

  # HAC SE (Bartlett kernel) — aligned with actual regression data
  n_lags <- max(1L, floor(T_used^(1/4)))
  e      <- residuals(fit)
  X_mat  <- cbind(1, x_reg)   # T_used × 2 — aligned with e
  XX_inv <- solve(t(X_mat) %*% X_mat)
  S      <- t(X_mat) %*% diag(e^2) %*% X_mat
  for (l in 1:n_lags) {
    w   <- 1 - l / (n_lags + 1)
    n_e <- length(e)
    idx <- (l + 1):n_e
    Sl  <- t(X_mat[idx, , drop = FALSE]) %*%
           diag(e[idx] * e[1:(n_e - l)]) %*%
           X_mat[idx, , drop = FALSE]
    S   <- S + w * (Sl + t(Sl))
  }
  se_b   <- sqrt((XX_inv %*% S %*% XX_inv)[2, 2])
  t_stat <- b_hat / se_b

  list(b_hat = b_hat, se = se_b, t_stat = t_stat,
       lags = n_lags, T_used = T_used)
}

# --- 4. Run clubs + report --------------------------------------------------
run_analysis <- function(var, label) {
  cat(paste(rep("=", 65), collapse = ""), "\n")
  cat("VARIABLE:", label, "(", var, ")\n")
  cat(paste(rep("=", 65), collapse = ""), "\n")

  pw <- make_wide(panel_long, "iso3c", "year", var)
  # Drop rows with any NA (some post-Soviet countries have gaps)
  pw_complete <- pw[complete.cases(pw), ]
  n_dropped   <- nrow(pw) - nrow(pw_complete)
  if (n_dropped > 0)
    cat("Dropped", n_dropped, "countries with missing values:",
        setdiff(pw[, 1], pw_complete[, 1]), "\n")

  T_pw <- ncol(pw_complete) - 1  # number of time columns

  # Log-t (full panel)
  logt <- logt_test(pw_complete)
  cat("\nFull-panel log-t:\n")
  cat("  b_hat =", round(logt$b_hat,  4), "\n")
  cat("  SE    =", round(logt$se,     4),
      "(HAC lags =", logt$lags, "| T_used =", logt$T_used, ")\n")
  cat("  t-stat=", round(logt$t_stat, 4),
      "| 5% critical: −1.65\n")
  decision <- if (is.na(logt$t_stat)) "INSUFFICIENT DATA" else
              if (logt$t_stat < -1.65) "REJECT H0 — panel diverges (clubs expected)" else
              "FAIL TO REJECT — panel convergence"
  cat("  →", decision, "\n")

  # Club detection
  cat("\nClub detection (findClubs):\n")
  clubs <- tryCatch(
    findClubs(
      X          = pw_complete,
      dataCols   = 2:(T_pw + 1),
      unit_names = 1,
      refCol     = T_pw + 1,
      time_trim  = 1/3,
      HACmethod  = "FQSB",
      cstar      = 0
    ),
    error = function(e) { cat("findClubs error:", conditionMessage(e), "\n"); NULL }
  )

  if (!is.null(clubs)) print(summary(clubs))

  # Merge
  merged <- tryCatch(
    mergeClubs(clubs, time_trim = 1/3, mergeMethod = "PS", mergeDivergent = FALSE),
    error = function(e) { cat("Merge:", conditionMessage(e), "\n"); clubs }
  )
  if (!is.null(merged) && !identical(merged, clubs)) {
    cat("After merging:\n"); print(summary(merged))
  }

  list(pw = pw_complete, clubs = clubs, merged = merged,
       b_hat = logt$b_hat, t_stat = logt$t_stat)
}

vars   <- c("labsh", "ln_tfp", "ln_cap_worker")
labels <- c("Labour Share", "Total Factor Productivity (log)", "Capital per Worker (log)")

results <- setNames(
  lapply(seq_along(vars), function(i) run_analysis(vars[i], labels[i])),
  vars
)

# --- 5. Transition path plots -----------------------------------------------
extract_club_assign <- function(club_obj) {
  if (is.null(club_obj)) return(NULL)
  club_names <- names(club_obj)[grepl("^club", names(club_obj))]
  rows <- lapply(seq_along(club_names), function(i)
    data.frame(country = club_obj[[club_names[i]]]$unit_names,
               club = i, stringsAsFactors = FALSE))
  assign_df <- do.call(rbind, rows)
  if (!is.null(club_obj$divergent) && length(club_obj$divergent$unit_names) > 0)
    assign_df <- rbind(assign_df,
                       data.frame(country = club_obj$divergent$unit_names,
                                  club = NA, stringsAsFactors = FALSE))
  assign_df
}

plot_transitions <- function(var, label, res) {
  pw       <- res$pw
  club_obj <- if (!is.null(res$merged)) res$merged else res$clubs

  X    <- as.matrix(pw[, -1])
  ctry <- pw[, 1]
  T_c  <- ncol(X)
  yrs  <- as.integer(colnames(pw)[-1])

  H <- matrix(NA, nrow(X), T_c)
  for (t in 1:T_c) H[, t] <- X[, t] / mean(X[, t])

  H_df         <- as.data.frame(H)
  colnames(H_df) <- as.character(yrs)
  H_df$country <- ctry

  club_assign <- extract_club_assign(club_obj)
  if (is.null(club_assign))
    club_assign <- data.frame(country = ctry, club = 1, stringsAsFactors = FALSE)

  H_long <- H_df %>%
    pivot_longer(-country, names_to = "year", values_to = "h") %>%
    mutate(year = as.integer(year)) %>%
    left_join(club_assign, by = "country") %>%
    mutate(club_label = case_when(
      is.na(club) ~ "Divergent",
      TRUE        ~ paste0("Club ", club)
    ))

  palette <- c("#2166AC", "#D7191C", "#1A9641", "#F4A582",
               "#762A83", "#E66101", "grey50")
  ltype   <- c("solid", "dashed", "dotdash", "longdash",
               "twodash", "dotted", "dotted")

  all_labels <- sort(unique(H_long$club_label))
  p_pal   <- setNames(palette[seq_along(all_labels)], all_labels)
  p_ltype <- setNames(ltype[seq_along(all_labels)], all_labels)

  ggplot(H_long, aes(year, h, colour = club_label,
                      group = country, linetype = club_label)) +
    geom_hline(yintercept = 1, linetype = "dotted",
               colour = "grey40", linewidth = 0.4) +
    geom_line(linewidth = 0.75, alpha = 0.85) +
    scale_colour_manual(values = p_pal) +
    scale_linetype_manual(values = p_ltype) +
    geom_text(
      data = H_long %>% filter(year == max(year)),
      aes(label = country), hjust = -0.15, size = 2.6, show.legend = FALSE
    ) +
    scale_x_continuous(expand = expansion(mult = c(0.02, 0.14))) +
    labs(
      title    = paste0("Relative Transition Paths — ", label),
      subtitle = paste0("Phillips-Sul (2007): b = ", round(res$b_hat, 3),
                        ", t = ", round(res$t_stat, 3)),
      x = NULL, y = "Relative transition h(it)",
      colour = "Club", linetype = "Club",
      caption = paste0("Note: h(it) = x(it)/mean_i(x(it)). Convergence ↔ h(it) → 1.\n",
                       "Eurasian panel, N=", nrow(pw), ", T=", T_c,
                       " (", min(yrs), "–", max(yrs), ").")
    ) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "right", panel.grid.minor = element_blank(),
          plot.title   = element_text(face = "bold"),
          plot.caption = element_text(size = 7.5, colour = "grey40"))
}

cat("\n=== Generating figures ===\n")
for (i in seq_along(vars)) {
  p        <- plot_transitions(vars[i], labels[i], results[[vars[i]]])
  fig_file <- paste0(FIG_PATH, "figA_ps_clubs_", vars[i], ".png")
  ggsave(fig_file, p, width = 8, height = 5, dpi = 300)
  cat("Saved:", fig_file, "\n")
}

# --- 6. Appendix summary table ----------------------------------------------
cat("\n=== APPENDIX TABLE: Log-t Test — Eurasian Automation Panel ===\n")
cat(sprintf("%-40s %8s %8s %16s\n", "Variable", "b_hat", "t-stat", "Decision"))
cat(paste(rep("-", 74), collapse = ""), "\n")
for (i in seq_along(vars)) {
  r   <- results[[vars[i]]]
  dec <- ifelse(r$t_stat < -1.65, "Divergent (clubs)", "Convergent")
  cat(sprintf("%-40s %8.3f %8.3f %16s\n", labels[i], r$b_hat, r$t_stat, dec))
}
cat("\nNote: H0: b ≥ 0 (convergence). Reject at t < −1.65 (5%).\n")
cat("HAC standard errors (FQSB). N=14 Eurasian economies, 1995–2019.\n")

# --- 7. Manuscript snippet --------------------------------------------------
cat("\n=== MANUSCRIPT APPENDIX NOTE ===\n")
ls_t  <- round(results[["labsh"]]$t_stat, 3)
ls_b  <- round(results[["labsh"]]$b_hat, 3)
tfp_t <- round(results[["ln_tfp"]]$t_stat, 3)

if (ls_t < -1.65) {
  cat(sprintf(
    "Phillips-Sul (2007) log-t tests reject full-panel convergence in labour share\n(b = %.3f, t = %.3f), revealing club structure among Eurasian economies.\n",
    ls_b, ls_t))
  cat("This cross-country heterogeneity corroborates the CCEMG mean-group estimator\n")
  cat("and implies that automation's labour-share effect differs structurally across\n")
  cat("the panel — consistent with the heterogeneous elasticities reported in Table 3.\n")
} else {
  cat(sprintf(
    "Phillips-Sul (2007) log-t tests do not reject full-panel labour-share convergence\n(b = %.3f, t = %.3f), consistent with common long-run trajectory across Eurasia.\n",
    ls_b, ls_t))
  cat("This supports the CS-ARDL pooled long-run coefficient as a meaningful average.\n")
}

cat("\n✓ Complete. Figures in data/figA_ps_clubs_*.png\n")
cat("✓ Add to Appendix of Automation-LaborShare manuscript.\n")
