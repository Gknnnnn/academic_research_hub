# ============================================================
# AI Strategy Carbon DiD — Cohort-Specific ATT Table (v0.4)
# Author: M. Gökhan Özdemir | 2026-04-10
# Output: 600-Results/Table_cohort.tex
# ============================================================
suppressPackageStartupMessages({
  library(dplyr); library(did); library(xtable)
})

PROJ <- "/Users/mehmetgokhanozdemir/OrbStack/docker/containers/env-n8n-1/data/project/200-Manuscripts/210-Active/2026-AI-Strategy-Carbon-DiD"
res  <- readRDS(file.path(PROJ, "600-Results/main_results.rds"))
cs_co2  <- res$cs_co2
cs_ren  <- res$cs_ren_agg  # simple agg for renewables (group-level if needed)

# ── Cohort (group-time) aggregate ATTs ────────────────────────────────────────
grp_co2 <- aggte(cs_co2, type = "group", na.rm = TRUE)

# Also get renewable counterpart
cs_ren_full <- res$cs_ren
grp_ren  <- aggte(cs_ren_full, type = "group", na.rm = TRUE)

# ── Build data frame ──────────────────────────────────────────────────────────
cohorts     <- grp_co2$egt          # adoption years (groups)
att_co2     <- grp_co2$att.egt
se_co2      <- grp_co2$se.egt
crit        <- qnorm(0.975)
ci_lo_co2   <- att_co2 - crit * se_co2
ci_hi_co2   <- att_co2 + crit * se_co2
p_co2       <- 2 * (1 - pnorm(abs(att_co2 / se_co2)))

# Stars helper
stars <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**",
                    ifelse(p < 0.10, "*", "")))

# Country counts per cohort (from adoption dates)
panel <- readRDS(file.path(PROJ, "400-Data/processed/ai_strategy_panel.rds"))
cohort_n <- panel %>%
  filter(g > 0) %>%
  distinct(iso_code, g) %>%
  count(g, name = "n_countries")

# Renewable ATTs per cohort
att_ren   <- grp_ren$att.egt
se_ren    <- grp_ren$se.egt
p_ren     <- 2 * (1 - pnorm(abs(att_ren / se_ren)))
ci_lo_ren <- att_ren - crit * se_ren
ci_hi_ren <- att_ren + crit * se_ren

# Align cohorts (in case ren has different ordering)
ren_df <- data.frame(
  g       = grp_ren$egt,
  att_ren = att_ren,
  se_ren  = se_ren,
  p_ren   = p_ren,
  ci_lo_ren = ci_lo_ren,
  ci_hi_ren = ci_hi_ren
)

tbl <- data.frame(
  cohort    = cohorts,
  att_co2   = att_co2,
  se_co2    = se_co2,
  p_co2     = p_co2,
  ci_lo_co2 = ci_lo_co2,
  ci_hi_co2 = ci_hi_co2
) %>%
  left_join(ren_df, by = c("cohort" = "g")) %>%
  left_join(cohort_n, by = c("cohort" = "g")) %>%
  arrange(cohort)

# ── Write LaTeX table ─────────────────────────────────────────────────────────
cat_tex <- function(path, tbl) {
  fmt_est <- function(x, p) sprintf("$%s%s$",
    formatC(x, digits=3, format="f"),
    stars(p))
  fmt_se  <- function(x) sprintf("$(%.3f)$", x)
  fmt_ci  <- function(lo, hi) sprintf("$[%.3f,\\,%.3f]$", lo, hi)

  lines <- c(
    "% Table: Cohort-Specific ATTs — AI Strategy Carbon DiD (v0.4)",
    "% Generated 2026-04-10 by 04_cohort_table.R",
    "\\begin{table}[htbp]",
    "  \\centering",
    "  \\caption{Cohort-Specific Average Treatment Effects on the Treated (CS-ATT)\\label{tab:cohort}}",
    "  \\small",
    "  \\begin{tabular}{lccccc}",
    "  \\toprule",
    "  Adoption & $N$ & \\multicolumn{2}{c}{$\\ln(\\text{CO}_2/\\text{cap})$} & \\multicolumn{2}{c}{Renewable share (pp)} \\\\",
    "  cohort & countries & ATT & 95\\% CI & ATT & 95\\% CI \\\\",
    "  \\midrule"
  )

  for (i in seq_len(nrow(tbl))) {
    r <- tbl[i, ]
    n_str <- ifelse(is.na(r$n_countries), "---", as.character(r$n_countries))
    lines <- c(lines, sprintf(
      "  %d & %s & %s & %s & %s & %s \\\\",
      r$cohort,
      n_str,
      fmt_est(r$att_co2, r$p_co2),
      fmt_ci(r$ci_lo_co2, r$ci_hi_co2),
      fmt_est(r$att_ren, r$p_ren),
      fmt_ci(r$ci_lo_ren, r$ci_hi_ren)
    ))
    lines <- c(lines, sprintf(
      "        & & %s & & %s & \\\\",
      fmt_se(r$se_co2),
      fmt_se(r$se_ren)
    ))
  }

  lines <- c(lines,
    "  \\bottomrule",
    "  \\end{tabular}",
    "  \\begin{tablenotes}\\footnotesize",
    "  \\item \\textit{Notes:} Callaway--Sant'Anna group-specific ATTs aggregated by adoption cohort",
    "  (\\texttt{type = \"group\"}, never-treated control group). Standard errors (in parentheses)",
    "  are clustered by country. 95\\% CIs use pointwise normal critical value $z_{0.975}=1.96$.",
    "  $^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$.",
    "  Small cohorts (2017: $n=3$; 2020: $n=4$) are under-powered; treat estimates as indicative.",
    "  \\end{tablenotes}",
    "\\end{table}"
  )
  writeLines(lines, path)
  invisible(lines)
}

out_path <- file.path(PROJ, "600-Results/Table_cohort.tex")
cat_tex(out_path, tbl)
message("Cohort ATT table written to: ", out_path)

# ── Print to console ──────────────────────────────────────────────────────────
cat("\n=== Cohort-Specific ATTs (CO2) ===\n")
for (i in seq_len(nrow(tbl))) {
  r <- tbl[i, ]
  cat(sprintf("  Cohort %d (n=%s): ATT=%.4f%s  SE=%.4f  95%%CI=[%.4f,%.4f]\n",
    r$cohort,
    ifelse(is.na(r$n_countries), "?", r$n_countries),
    r$att_co2, stars(r$p_co2),
    r$se_co2, r$ci_lo_co2, r$ci_hi_co2))
}
cat("\n=== Cohort-Specific ATTs (Renewables) ===\n")
for (i in seq_len(nrow(tbl))) {
  r <- tbl[i, ]
  cat(sprintf("  Cohort %d: ATT=%.4f%s  SE=%.4f  95%%CI=[%.4f,%.4f]\n",
    r$cohort, r$att_ren, stars(r$p_ren),
    r$se_ren, r$ci_lo_ren, r$ci_hi_ren))
}
message("\nDone.")
