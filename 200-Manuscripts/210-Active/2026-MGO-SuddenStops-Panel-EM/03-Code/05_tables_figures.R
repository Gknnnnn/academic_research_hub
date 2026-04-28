# =============================================================================
# Tables & Figures — Sudden Stops Paper
# Paper: Global Uncertainty, Domestic Credit, and Sudden Stops
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-28
# Run AFTER: 03_panel_probit_estimation.R (results must exist)
# Output: LaTeX tables → 04-Manuscript/tables/ ; figures → 04-Manuscript/figures/
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(knitr)
library(kableExtra)
library(scales)
library(zoo)

RESULTS_DIR <- "07-Results/"
TABLE_DIR   <- "04-Manuscript/tables/"
FIG_DIR     <- "04-Manuscript/figures/"
dir.create(TABLE_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR,   recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# TABLE 1: DESCRIPTIVE STATISTICS
# =============================================================================

make_table1_desc_stats <- function(df_clean) {
  # Variables to describe
  vars <- c(
    "sudden_stop", "vix", "ffr", "us_gdp_growth", "us_10y_yield",
    "ca_pct_gdp", "credit_pct_gdp", "log_reserves_usd",
    "trade_open", "ka_open", "ers", "gpr", "mpp_index"
  )
  labels <- c(
    "Sudden Stop (0/1)", "VIX (log)", "Fed Funds Rate (%)",
    "US GDP Growth (% q/q)", "US 10Y Yield (%)",
    "Current Account/GDP (%)", "Credit/GDP (%)",
    "Log International Reserves (USD)",
    "Trade Openness (% GDP)", "Capital Account Openness (ACI)",
    "Exchange Rate Stability (ACI)", "GPR Index",
    "Macroprudential Index (iMaPP)"
  )

  desc_list <- lapply(seq_along(vars), function(i) {
    x <- df_clean[[vars[i]]]
    x <- x[!is.na(x)]
    data.frame(
      Variable     = labels[i],
      N            = length(x),
      Mean         = round(mean(x), 3),
      SD           = round(sd(x), 3),
      Min          = round(min(x), 3),
      P25          = round(quantile(x, 0.25), 3),
      Median       = round(median(x), 3),
      P75          = round(quantile(x, 0.75), 3),
      Max          = round(max(x), 3),
      stringsAsFactors = FALSE
    )
  })
  bind_rows(desc_list)
}

format_table1 <- function(desc_tbl, output_file = file.path(TABLE_DIR, "table1_desc_stats.tex")) {
  kbl(desc_tbl,
      format   = "latex",
      booktabs = TRUE,
      caption  = "Descriptive Statistics",
      label    = "tab:desc_stats",
      col.names = c("Variable", "N", "Mean", "SD", "Min", "Q25", "Median", "Q75", "Max"),
      align    = c("l", rep("r", 8))
  ) %>%
    kable_styling(font_size = 9, latex_options = c("hold_position", "scale_down")) %>%
    pack_rows("Global Push Factors", 2, 5) %>%
    pack_rows("Domestic Pull Factors", 6, 11) %>%
    pack_rows("Policy Variables", 12, 13) %>%
    footnote(general = paste(
      "Sample: quarterly panel of N countries, 1990Q1--2024Q4.",
      "Sudden Stop is 1 in quarters meeting the Forbes-Warnock (2012) episode definition.",
      "VIX: log-transformed. Credit/GDP and other ratios winsorised at 1st/99th percentile.",
      "ACI: Aizenman-Chinn-Ito trilemma indexes (0 to 1 scale).",
      "GPR: Caldara-Iacoviello (2022) global geopolitical risk index."
    ), general_title = "\\textit{Notes:} ", escape = FALSE) %>%
    save_kable(output_file)
  message("Table 1 saved: ", output_file)
}

# =============================================================================
# TABLE 2: EPISODE FREQUENCY
# =============================================================================

make_table2_episodes <- function(df_clean) {
  # Overall
  overall <- df_clean %>%
    summarise(
      Group   = "Full sample",
      N_obs   = n(),
      N_ctry  = n_distinct(iso3),
      N_ss    = sum(sudden_stop, na.rm = TRUE),
      Pct_ss  = round(100 * mean(sudden_stop, na.rm = TRUE), 2)
    )

  # By income group
  by_group <- df_clean %>%
    group_by(Group = income_group) %>%
    summarise(
      N_obs   = n(),
      N_ctry  = n_distinct(iso3),
      N_ss    = sum(sudden_stop, na.rm = TRUE),
      Pct_ss  = round(100 * mean(sudden_stop, na.rm = TRUE), 2),
      .groups = "drop"
    )

  # By crisis period
  by_crisis <- df_clean %>%
    mutate(
      period = case_when(
        date >= as.Date("2008-07-01") & date <= as.Date("2009-12-31") ~ "GFC (2008Q3-2009Q4)",
        date >= as.Date("2020-01-01") & date <= as.Date("2020-12-31") ~ "COVID-19 (2020Q1-Q4)",
        TRUE                                                            ~ "Non-crisis quarters"
      )
    ) %>%
    group_by(Group = period) %>%
    summarise(
      N_obs   = n(),
      N_ctry  = n_distinct(iso3),
      N_ss    = sum(sudden_stop, na.rm = TRUE),
      Pct_ss  = round(100 * mean(sudden_stop, na.rm = TRUE), 2),
      .groups = "drop"
    )

  bind_rows(overall, by_group, by_crisis)
}

format_table2 <- function(ep_tbl, output_file = file.path(TABLE_DIR, "table2_episodes.tex")) {
  kbl(ep_tbl,
      format   = "latex",
      booktabs = TRUE,
      caption  = "Sudden Stop Episode Frequency",
      label    = "tab:episodes",
      col.names = c("Group", "Obs.", "Countries", "SS Episodes", "SS Freq. (\\%)"),
      align    = c("l","r","r","r","r"),
      escape   = FALSE
  ) %>%
    kable_styling(font_size = 10, latex_options = "hold_position") %>%
    footnote(general = paste(
      "Sudden Stop defined following Forbes and Warnock (2012):",
      "four-quarter rolling change in gross inflows $\\\\geq 1\\\\sigma$ below",
      "rolling 5-year mean in sustained phase, with at least one quarter",
      "$\\\\geq 2\\\\sigma$ below mean. GFC: 2008Q3--2009Q4.",
      "COVID-19: 2020Q1--2020Q4."
    ), general_title = "\\textit{Notes:} ", escape = FALSE) %>%
    save_kable(output_file)
  message("Table 2 saved: ", output_file)
}

# =============================================================================
# TABLE 3: PESARAN CD PRE-TEST RESULTS
# =============================================================================

format_table3_cd <- function(cd_results, output_file = file.path(TABLE_DIR, "table3_cd_tests.tex")) {
  # cd_results: data.frame with columns: variable, label, cd_stat, p_value, avg_corr
  cd_results <- cd_results %>%
    mutate(
      stars     = case_when(p_value < 0.01 ~ "***", p_value < 0.05 ~ "**",
                            p_value < 0.10 ~ "*", TRUE ~ ""),
      cd_fmt    = sprintf("%.3f%s", cd_stat, stars),
      p_fmt     = sprintf("%.3f", p_value),
      rho_fmt   = sprintf("%.3f", avg_corr),
      inference = ifelse(p_value < 0.05, "CSD present", "No CSD")
    )

  kbl(cd_results[, c("label","cd_fmt","p_fmt","rho_fmt","inference")],
      format   = "latex",
      booktabs = TRUE,
      caption  = "Pesaran (2004) Cross-Sectional Dependence Tests",
      label    = "tab:cd_tests",
      col.names = c("Variable", "$CD$", "$p$-value", "$\\bar{\\rho}$", "Inference"),
      align    = c("l","r","r","r","l"),
      escape   = FALSE
  ) %>%
    kable_styling(font_size = 10, latex_options = "hold_position") %>%
    footnote(
      general = paste(
        "The CD statistic follows $\\\\mathcal{N}(0,1)$ under the null of cross-sectional independence.",
        "$\\\\bar{\\\\rho}$ is the average pairwise correlation coefficient.",
        "***/**/* denote significance at 1\\\\%/5\\\\%/10\\\\% levels.",
        "Near-universal CSD motivates Driscoll-Kraay (1998) standard errors throughout."
      ),
      general_title = "\\textit{Notes:} ", escape = FALSE
    ) %>%
    save_kable(output_file)
  message("Table 3 saved: ", output_file)
}

# =============================================================================
# TABLE 4: BASELINE PANEL PROBIT RESULTS (M1–M5)
# =============================================================================

format_table4_probit <- function(model_list, output_file = file.path(TABLE_DIR, "table4_probit.tex")) {
  # model_list: named list with M1..M5 summary data frames
  # Each element: data.frame(term, coef, se, stars)

  # Stack all models into wide format
  all_terms <- c(
    "vix","ffr","us_gdp_growth","us_10y_yield","gpr",
    "ca_pct_gdp","credit_pct_gdp","log_reserves_usd","trade_open","ka_open","ers",
    "mpp_index","credit_pct_gdp:mpp_index"
  )
  term_labels <- c(
    "VIX (log)", "Fed Funds Rate", "US GDP Growth", "US 10Y Yield", "GPR Index",
    "Current Account/GDP", "Credit/GDP", "Log Reserves", "Trade Openness",
    "Capital Acc. Openness", "Exchange Rate Stability",
    "MPP Index", "Credit/GDP $\\times$ MPP"
  )

  # Build display table
  rows <- lapply(seq_along(all_terms), function(i) {
    row_coef <- c(term_labels[i])
    row_se   <- c("")
    for (mn in names(model_list)) {
      m <- model_list[[mn]]
      idx <- which(m$term == all_terms[i])
      if (length(idx) == 1) {
        row_coef <- c(row_coef, paste0(sprintf("%.3f", m$coef[idx]), m$stars[idx]))
        row_se   <- c(row_se,   paste0("(", sprintf("%.3f", m$se[idx]), ")"))
      } else {
        row_coef <- c(row_coef, "")
        row_se   <- c(row_se,   "")
      }
    }
    rbind(row_coef, row_se)
  })

  # Flatten and add separator rows
  mat <- do.call(rbind, rows)
  rownames(mat) <- NULL

  # Add model stats rows
  stat_rows <- lapply(c("N","Pseudo-R2","Log-Lik","Country FE"), function(stat) {
    vals <- sapply(model_list, function(m) {
      v <- m$stats[[stat]]
      if (is.null(v)) return("")
      if (stat == "Country FE") return(v)
      if (stat == "N") return(formatC(v, format="d", big.mark=","))
      sprintf("%.3f", v)
    })
    c(stat, vals)
  })
  stat_mat <- do.call(rbind, stat_rows)

  full_mat <- as.data.frame(rbind(mat, stat_mat), stringsAsFactors=FALSE)

  model_names <- paste0("\\textbf{", names(model_list), "}")

  kbl(full_mat,
      format   = "latex",
      booktabs = TRUE,
      caption  = "Panel Probit Estimates: Determinants of Sudden Stops (M1--M5)",
      label    = "tab:probit",
      col.names = c("Variable", model_names),
      align    = c("l", rep("c", length(model_list))),
      escape   = FALSE
  ) %>%
    kable_styling(font_size = 9, latex_options = c("hold_position","scale_down")) %>%
    add_header_above(c(" " = 1,
                       "Push only" = 1, "Pull only" = 1,
                       "Push+Pull" = 1, "+MPP" = 1, "+MPP×Credit" = 1)) %>%
    footnote(
      general = paste(
        "Standard errors are Driscoll-Kraay (1998) robust to cross-sectional dependence",
        "and serial correlation (lag order $\\\\ell = 4$ quarters).",
        "Country fixed effects included throughout.",
        "***/**/* denote significance at 1\\\\%/5\\\\%/10\\\\% levels.",
        "M5 is the preferred specification."
      ),
      general_title = "\\textit{Notes:} ", escape = FALSE
    ) %>%
    save_kable(output_file)
  message("Table 4 saved: ", output_file)
}

# =============================================================================
# TABLE 5: AVERAGE MARGINAL EFFECTS
# =============================================================================

format_table5_ame <- function(ame_df, output_file = file.path(TABLE_DIR, "table5_ame.tex")) {
  # ame_df: AME from M5; columns: variable, label, ame, se, ci_lo, ci_hi, stars
  ame_df <- ame_df %>%
    mutate(
      ame_fmt  = sprintf("%.4f%s", ame, stars),
      se_fmt   = sprintf("(%.4f)", se),
      ci_fmt   = sprintf("[%.4f, %.4f]", ci_lo, ci_hi),
      pp_fmt   = sprintf("%.4f pp", ame * 100)  # per 1-unit change in X
    )

  kbl(ame_df[, c("label","ame_fmt","se_fmt","ci_fmt","pp_fmt")],
      format   = "latex",
      booktabs = TRUE,
      caption  = "Average Marginal Effects (AME) --- Preferred Model M5",
      label    = "tab:ame",
      col.names = c("Variable", "AME", "(SE)", "95\\% CI", "Economic magnitude"),
      align    = c("l","r","r","r","r"),
      escape   = FALSE
  ) %>%
    kable_styling(font_size = 10, latex_options = "hold_position") %>%
    footnote(
      general = paste(
        "AMEs computed at sample means; delta-method standard errors.",
        "Economic magnitude column reports pp change in sudden stop probability",
        "per one-unit change in the regressor.",
        "Benchmark from Hakhverdyan et al. (2026): VIX $\\\\to$ +0.39 pp per 1-point increase.",
        "***/**/* denote significance at 1\\\\%/5\\\\%/10\\\\% levels."
      ),
      general_title = "\\textit{Notes:} ", escape = FALSE
    ) %>%
    save_kable(output_file)
  message("Table 5 saved: ", output_file)
}

# =============================================================================
# TABLE 6: ROBUSTNESS BATTERY
# =============================================================================

format_table6_robustness <- function(robust_list, output_file = file.path(TABLE_DIR, "table6_robustness.tex")) {
  # robust_list: list of AME and CI for VIX across specifications
  # columns: spec, ame_vix, ci_lo, ci_hi, n_obs, note

  kbl(robust_list,
      format   = "latex",
      booktabs = TRUE,
      caption  = "Robustness Checks --- VIX Average Marginal Effect",
      label    = "tab:robustness",
      col.names = c("Specification", "VIX AME", "95\\% CI", "N", "Note"),
      align    = c("l","r","r","r","l"),
      escape   = FALSE
  ) %>%
    kable_styling(font_size = 9, latex_options = "hold_position") %>%
    pack_rows("Alternative link functions", 1, 3) %>%
    pack_rows("Alternative episode definitions", 4, 5) %>%
    pack_rows("Crisis-period exclusions", 6, 7) %>%
    pack_rows("Alternative SE", 8, 9) %>%
    footnote(
      general = paste(
        "Baseline M5 specification throughout; only the estimation method or",
        "sample varies across rows.",
        "Logit and cloglog link functions address rare-events concern",
        "(Eichengreen \\\\& Gupta, 2016).",
        "``No GFC'' excludes 2008Q3--2009Q4; ``No COVID'' excludes 2020Q1--2020Q4.",
        "Net flows: gross inflows replaced with net financial account balance."
      ),
      general_title = "\\textit{Notes:} ", escape = FALSE
    ) %>%
    save_kable(output_file)
  message("Table 6 saved: ", output_file)
}

# =============================================================================
# TABLE 7: SUBSAMPLE RESULTS
# =============================================================================

format_table7_subsample <- function(sub_list, output_file = file.path(TABLE_DIR, "table7_subsample.tex")) {
  kbl(sub_list,
      format   = "latex",
      booktabs = TRUE,
      caption  = "Subsample Analysis: Eurasian/CIS vs. Advanced vs. Emerging",
      label    = "tab:subsample",
      col.names = c("Variable", "Full Sample", "Advanced", "Emerging", "Eurasian/CIS"),
      align    = c("l", rep("c", 4)),
      escape   = FALSE
  ) %>%
    kable_styling(font_size = 9, latex_options = c("hold_position","scale_down")) %>%
    footnote(
      general = paste(
        "M5 specification in each subsample.",
        "Eurasian/CIS results use Webb (2023) wild cluster bootstrap (9999 draws)",
        "because $N_{\\\\text{cluster}} < 30$.",
        "AMEs reported; bootstrapped 95\\\\% CIs in brackets.",
        "``Structural premium'' row reports the Eurasian/CIS country fixed-effect",
        "average relative to Advanced economies, in percentage points."
      ),
      general_title = "\\textit{Notes:} ", escape = FALSE
    ) %>%
    save_kable(output_file)
  message("Table 7 saved: ", output_file)
}

# =============================================================================
# FIGURE 1: EPISODE FREQUENCY OVER TIME
# =============================================================================

make_figure1_timeline <- function(df_clean,
                                   output_file = file.path(FIG_DIR, "fig1_episode_timeline.pdf")) {
  quarterly_ss <- df_clean %>%
    mutate(year_q = as.Date(date)) %>%
    group_by(year_q) %>%
    summarise(
      ss_pct    = 100 * mean(sudden_stop, na.rm = TRUE),
      n_ss      = sum(sudden_stop, na.rm = TRUE),
      .groups   = "drop"
    )

  crisis_bands <- data.frame(
    xmin = as.Date(c("2008-07-01", "2019-10-01")),
    xmax = as.Date(c("2009-12-31", "2020-12-31")),
    label = c("GFC", "COVID-19")
  )

  p <- ggplot(quarterly_ss, aes(x = year_q, y = ss_pct)) +
    geom_rect(data = crisis_bands,
              aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
              fill = "grey80", alpha = 0.5, inherit.aes = FALSE) +
    geom_col(fill = "#2c7bb6", alpha = 0.75, width = 60) +
    geom_text(data = crisis_bands,
              aes(x = xmin + (xmax - xmin) / 2, y = max(quarterly_ss$ss_pct, na.rm = TRUE) * 0.9,
                  label = label),
              size = 3, inherit.aes = FALSE) +
    scale_x_date(breaks = seq(as.Date("1990-01-01"), as.Date("2024-01-01"), by = "5 years"),
                 date_labels = "%Y") +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      title   = "Sudden Stop Episode Frequency by Quarter",
      x       = NULL,
      y       = "Share of countries in sudden stop (%)"
    ) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank()
    )

  ggsave(output_file, plot = p, width = 16, height = 7, units = "cm", dpi = 300)
  # Also save PNG for quick preview
  ggsave(sub(".pdf", ".png", output_file), plot = p, width = 16, height = 7, units = "cm", dpi = 300)
  message("Figure 1 saved: ", output_file)
}

# =============================================================================
# FIGURE 2: AME COEFFICIENT PLOT (M5)
# =============================================================================

make_figure2_coefplot <- function(ame_df,
                                   output_file = file.path(FIG_DIR, "fig2_ame_coefplot.pdf")) {
  ame_plot <- ame_df %>%
    filter(!grepl("Interaction|FE", label)) %>%
    arrange(ame) %>%
    mutate(label = factor(label, levels = label),
           sig   = ifelse(ci_lo > 0 | ci_hi < 0, "Significant (p<0.05)", "Not significant"))

  p <- ggplot(ame_plot, aes(x = ame * 100, y = label, color = sig)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
    geom_errorbarh(aes(xmin = ci_lo * 100, xmax = ci_hi * 100), height = 0.2, linewidth = 0.7) +
    geom_point(size = 2.5) +
    scale_color_manual(values = c("Significant (p<0.05)" = "#d7191c",
                                   "Not significant"       = "#92c5de")) +
    labs(
      title = "Average Marginal Effects on Sudden Stop Probability (M5)",
      x     = "Change in Pr(Sudden Stop) in percentage points",
      y     = NULL,
      color = NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position   = "bottom",
      panel.grid.minor  = element_blank(),
      panel.grid.major.y = element_blank()
    )

  ggsave(output_file, plot = p, width = 16, height = 12, units = "cm", dpi = 300)
  ggsave(sub(".pdf", ".png", output_file), plot = p, width = 16, height = 12, units = "cm", dpi = 300)
  message("Figure 2 saved: ", output_file)
}

# =============================================================================
# FIGURE 3: SUBSAMPLE STRUCTURAL PREMIUM (Eurasian vs. others)
# =============================================================================

make_figure3_structural <- function(sub_results,
                                     output_file = file.path(FIG_DIR, "fig3_structural_premium.pdf")) {
  # sub_results: data.frame with group, ame_vix, ci_lo, ci_hi, baseline_prob
  p <- ggplot(sub_results, aes(x = group, y = baseline_prob * 100)) +
    geom_col(aes(fill = group), show.legend = FALSE, width = 0.6) +
    geom_errorbar(aes(ymin = ci_lo * 100, ymax = ci_hi * 100), width = 0.15, linewidth = 0.7) +
    scale_fill_manual(values = c("Advanced"    = "#4575b4",
                                  "Emerging"    = "#74add1",
                                  "Eurasian/CIS" = "#d73027")) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      title = "Baseline Sudden Stop Probability by Country Group",
      x     = NULL,
      y     = "Pr(Sudden Stop) at sample means (%)"
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank())

  ggsave(output_file, plot = p, width = 12, height = 8, units = "cm", dpi = 300)
  ggsave(sub(".pdf", ".png", output_file), plot = p, width = 12, height = 8, units = "cm", dpi = 300)
  message("Figure 3 saved: ", output_file)
}

# =============================================================================
# MASTER — run after estimation
# =============================================================================
# After running 03_panel_probit_estimation.R and obtaining:
#   - df_clean (panel data)
#   - m5_results (model summary list)
#   - ame_m5 (AME data frame)
#   - robustness_results (robustness data frame)
#   - subsample_results (subsample data frame)

# desc_tbl     <- make_table1_desc_stats(df_clean); format_table1(desc_tbl)
# ep_tbl       <- make_table2_episodes(df_clean);   format_table2(ep_tbl)
# # cd_results loaded from 03_panel_probit_estimation.R output
# format_table3_cd(cd_results)
# format_table4_probit(m1_to_m5_list)
# format_table5_ame(ame_m5)
# format_table6_robustness(robustness_results)
# format_table7_subsample(subsample_results)
# make_figure1_timeline(df_clean)
# make_figure2_coefplot(ame_m5)
# make_figure3_structural(sub_baseline)
