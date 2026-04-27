# =============================================================================
# AI Strategy Carbon DiD — Script 06
# did2s (Gardner/Borusyak imputation) + staggered (Roth-Sant'Anna 2023)
# Methodological upgrade: BESTFIT_METHOD_MATRIX_20260425 Rank-4
#
# Author : Res. Asst. Dr. M. Gökhan Özdemir
# Date   : 2026-04-25
#
# Background
# ----------
# Main analysis (02_analysis.R) uses Callaway-Sant'Anna CS-ATT + HonestDiD.
# This script adds two efficiency/robustness checks per the 2024 DiD literature:
#
# (A) did2s (Gardner 2021 / Borusyak-Jaravel-Spiess 2024)
#     "Imputation" DiD: fits a no-treatment model on clean controls/pre-periods,
#     imputes counterfactual, takes residual as treatment effect.
#     More efficient than CS-ATT when T is short (<20 periods).
#
# (B) staggered (Roth-Sant'Anna 2023)
#     Efficiency-optimized version of CS-ATT that exploits randomization
#     or parallel trends to sharpen standard errors.
#
# Both are ROBUSTNESS checks — primary estimator remains CS-ATT.
# =============================================================================

pkgs <- c("did2s", "staggered", "fixest", "dplyr", "readr", "ggplot2", "here")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    message("Installing: ", p)
    install.packages(p, repos = "https://cloud.r-project.org")
  }
}

suppressPackageStartupMessages({
  library(did2s); library(staggered); library(fixest)
  library(dplyr); library(readr); library(ggplot2); library(here)
})

PROJ_ROOT <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-AI-Strategy-Carbon-DiD"
OUT_DIR   <- file.path(PROJ_ROOT, "03-Results")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ── Load panel (same as script 02) ───────────────────────────────────────────
panel_path <- file.path(PROJ_ROOT, "02-Methods", "400-Data", "processed", "ai_strategy_panel.rds")
if (!file.exists(panel_path)) {
  stop("Panel RDS not found at: ", panel_path)
}

panel <- readRDS(panel_path) %>%
  filter(year >= 2005, year <= 2023) %>%
  group_by(iso_code) %>% filter(n() >= 10) %>% ungroup()

message(sprintf("Panel: %d obs | %d countries | %d years",
                nrow(panel), n_distinct(panel$iso_code), n_distinct(panel$year)))

# Treatment variable: adopt_year = year of AI strategy adoption (NA = never treated)
# Rename to 'g' for compatibility; 0 = never treated for did2s
panel <- panel %>%
  mutate(
    g         = adopt_year,
    g_did2s   = if_else(is.na(adopt_year), 0L, as.integer(adopt_year)),
    post_did2s = if_else(!is.na(adopt_year) & year >= adopt_year, 1L, 0L)
  )

# ── A. did2s — Gardner / Borusyak Imputation DiD ─────────────────────────────
message("\n=== A. did2s (Imputation DiD) ===")

run_did2s <- function(yvar, label) {
  df_sub <- panel %>% filter(!is.na(.data[[yvar]]), !is.na(ln_gdppc))
  # Precompute reference year outside formula to avoid fixest scoping issue
  ref_yr <- min(df_sub$year[df_sub$post_did2s == 1], na.rm = TRUE) - 1
  tryCatch({
    res <- did2s(
      data         = df_sub,
      yname        = yvar,
      treatment    = "post_did2s",
      first_stage  = ~ ln_gdppc | iso_code + year,
      second_stage = as.formula(paste0("~ i(year, ref = ", ref_yr, ")")),
      cluster_var  = "iso_code"
    )
    att <- coef(res)
    att_agg <- mean(att[grepl("^year::", names(att)) & !grepl("Ref", names(att))],
                    na.rm = TRUE)
    se_agg  <- mean(sqrt(diag(vcov(res)))[grepl("^year::", names(coef(res)))], na.rm = TRUE)
    message(sprintf("  %-30s ATT (did2s) = %.4f  SE = %.4f  t = %.2f",
                    label, att_agg, se_agg, att_agg / se_agg))
    list(model = res, att = att_agg, se = se_agg, yvar = yvar, label = label)
  }, error = function(e) {
    message("  ERROR for ", label, ": ", e$message); NULL
  })
}

did2s_co2 <- run_did2s("ln_co2pc",             "ln CO₂ per capita")
did2s_ren <- run_did2s("renewables_share_energy", "Renewables share (%)")

# ── B. staggered (Roth-Sant'Anna 2023) ───────────────────────────────────────
message("\n=== B. staggered (Roth-Sant'Anna efficiency correction) ===")

run_staggered <- function(yvar, label) {
  df_sub <- panel %>%
    filter(!is.na(.data[[yvar]]), !is.na(ln_gdppc)) %>%
    mutate(i = as.integer(factor(iso_code)),
           g_stag = if_else(g_did2s == 0, Inf, as.numeric(g_did2s)))
  tryCatch({
    res <- staggered(
      df      = df_sub,
      i       = "i",
      t       = "year",
      g       = "g_stag",
      y       = yvar,
      estimand = "simple"  # valid: "simple", "cohort", "calendar", "eventstudy"
    )
    message(sprintf("  %-30s ATT (staggered) = %.4f  SE = %.4f",
                    label, res$estimate, res$se))
    res
  }, error = function(e) {
    message("  ERROR for ", label, ": ", e$message); NULL
  })
}

stag_co2 <- run_staggered("ln_co2pc",              "ln CO₂ per capita")
stag_ren <- run_staggered("renewables_share_energy", "Renewables share (%)")

# ── C. Comparison Table ───────────────────────────────────────────────────────
message("\n=== C. Estimator Comparison ===")

build_row <- function(estimator, outcome, att, se, note = "") {
  data.frame(estimator = estimator, outcome = outcome,
             att = round(att, 4), se = round(se, 4),
             t_stat = round(att/se, 3), note = note,
             stringsAsFactors = FALSE)
}

rows <- list()

# CS-ATT from script 02 (hard-coded from known results — replace if rerun)
rows[[1]] <- build_row("Callaway-Sant'Anna (CS-ATT)", "ln_co2pc",
                        att = NA, se = NA, note = "See 02_analysis.R output")
rows[[2]] <- build_row("Callaway-Sant'Anna (CS-ATT)", "renewables_share_energy",
                        att = NA, se = NA, note = "See 02_analysis.R output")

if (!is.null(did2s_co2))
  rows[[3]] <- build_row("did2s (Borusyak/Gardner)", "ln_co2pc",
                          did2s_co2$att, did2s_co2$se, "Imputation DiD")
if (!is.null(did2s_ren))
  rows[[4]] <- build_row("did2s (Borusyak/Gardner)", "renewables_share_energy",
                          did2s_ren$att, did2s_ren$se, "Imputation DiD")

if (!is.null(stag_co2))
  rows[[5]] <- build_row("staggered (Roth-Sant'Anna)", "ln_co2pc",
                          stag_co2$estimate, stag_co2$se, "Efficiency-optimized CS-ATT")
if (!is.null(stag_ren))
  rows[[6]] <- build_row("staggered (Roth-Sant'Anna)", "renewables_share_energy",
                          stag_ren$estimate, stag_ren$se, "Efficiency-optimized CS-ATT")

comp_table <- do.call(rbind, rows[!sapply(rows, is.null)])
print(comp_table)
readr::write_csv(comp_table, file.path(OUT_DIR, "did2s_staggered_comparison.csv"))
message("Saved: 03-Results/did2s_staggered_comparison.csv")

# ── D. Event study plot from did2s ───────────────────────────────────────────
if (!is.null(did2s_co2)) {
  tryCatch({
    iplot(did2s_co2$model,
          main = "did2s Event Study — ln CO₂ per capita\n(Gardner/Borusyak Imputation DiD)",
          xlab = "Years relative to AI Strategy adoption",
          ylab = "ATT (log points)",
          ref.line = -1)
    ggsave(file.path(OUT_DIR, "fig_did2s_event_study_co2.png"), width = 7, height = 4.5, dpi = 300)
    message("Saved: fig_did2s_event_study_co2.png")
  }, error = function(e) message("Event plot error: ", e$message))
}

message("
╔══════════════════════════════════════════════════════════════════════════════╗
║  MANUSCRIPT INTEGRATION (§5 Robustness)                                      ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Add Table: 'Robustness to Alternative DiD Estimators'                       ║
║  Columns: Estimator | CO₂ ATT | Renewables ATT | SE (cluster-robust)         ║
║                                                                              ║
║  Key sentence: 'The ATT estimates are robust to alternative DiD             ║
║  approaches: the imputation estimator of Gardner (2021) and Borusyak        ║
║  et al. (2024) and the efficiency-optimized estimator of Roth and           ║
║  Sant'Anna (2023) yield qualitatively consistent results, with ATT          ║
║  magnitudes within [X%] of the baseline CS-ATT estimate.'                  ║
║                                                                              ║
║  References (DOIs to verify):                                                ║
║   Gardner (2021): J. Econometrics (Two-stage DiD)                           ║
║   Borusyak et al. (2024): Review of Economic Studies                        ║
║   Roth & Sant'Anna (2023): Econometrica (staggered package)                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
")

message("Script 06 complete.")
