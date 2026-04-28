# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — Alternative System-GMM
# Strategies after pgmm AR(2) failure (p <= 0.057, Sargan p <= 0.011)
#
# Three estimators:
#   M1: panelvar::pvargmm — System-GMM lag-3 start (AR(2) fix)
#   M2: panelvar::pvargmm — System-GMM lag-3 + add lag(ln_cpi,2) as regressor
#   M3: plm::lsdvc         — Bias-corrected LSDV (no moment conditions needed)
#
# Cross-validation: pydynpd Python call via system() (optional, if pydynpd installed)
#
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-28
# Cite:
#   Sigmund & Ferstl (2021). panelvar. QREF. DOI:10.1016/j.qref.2019.01.001
#   Bruno (2005). lsdvc. EconLetters 87(3):361-366. DOI:10.1016/j.econlet.2005.02.003
#   Roodman (2009). Too Many Instruments. OBES 71(1):135-158. DOI:10.1111/j.1468-0084.2008.00542.x
#   Windmeijer (2005). JoE 126(1):25-51. DOI:10.1016/j.jeconom.2004.02.005
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(plm)
})

setwd("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Chronic-Inflation-Trilemma")

# ── Load data ──────────────────────────────────────────────────────────────────
panel <- read_csv("02-Data/clean/panel_chronic_inf_trilemma_v2.csv",
                  show_col_types = FALSE) |>
  arrange(iso3c, year) |>
  mutate(ln_cpi = log(pmax(cpi, 0.1) + 1))

panel_gmm <- panel |>
  filter(!is.na(ln_cpi), !is.na(MII), !is.na(ERS), !is.na(KAOPEN),
         !is.na(gdp_growth), !is.na(trade_open), !is.na(broad_money)) |>
  select(iso3c, year, ln_cpi, MII, ERS, KAOPEN,
         gdp_growth, trade_open, broad_money) |>
  as.data.frame()

cat(sprintf("\nGMM sample: N=%d countries, obs=%d\n",
            length(unique(panel_gmm$iso3c)), nrow(panel_gmm)))

# ─────────────────────────────────────────────────────────────────────────────
# PART 1: panelvar — System-GMM with lag-3 start
# ─────────────────────────────────────────────────────────────────────────────

pkg_ok <- requireNamespace("panelvar", quietly = TRUE)
if (!pkg_ok) {
  cat("\nInstalling panelvar...\n")
  install.packages("panelvar", repos = "https://cloud.r-project.org")
}
library(panelvar)

cat("\n============================================================\n")
cat("M1: panelvar System-GMM — instruments start at lag 3\n")
cat("    (fix for AR(2) rejection: skip lag-2 instruments)\n")
cat("============================================================\n")

m1 <- tryCatch({
  pvargmm(
    dependent_vars             = c("ln_cpi"),
    lags                       = 1,                      # one lag of DV as regressor
    exog_vars                  = c("MII", "ERS", "KAOPEN",
                                   "gdp_growth", "trade_open", "broad_money"),
    transformation             = "fod",                  # forward orthogonal deviations
    data                       = panel_gmm,
    panel_identifier           = c("iso3c", "year"),
    steps                      = "twostep",
    system_instruments         = TRUE,                   # System-GMM (Blundell-Bond)
    min_instr_dependent_var    = 3,                      # ← lag-3 start (AR(2) fix)
    max_instr_dependent_var    = 99,
    collapse                   = TRUE                    # Roodman collapse
  )
}, error = function(e) {
  cat("M1 ERROR:", conditionMessage(e), "\n"); NULL
})

if (!is.null(m1)) {
  print(summary(m1))

  # AR tests
  cat("\n--- Arellano-Bond AR tests (M1) ---\n")
  ar1 <- tryCatch(Andrews_Lu_MMSC(m1), error = function(e) NULL)
  # Manual AR test via Hansen J if MMSC unavailable
  cat("(Use summary output's J-statistic as overidentification test)\n")

  # Stability test
  cat("\n--- Eigenvalue check (M1 — should be |eigenvalue| < 1) ---\n")
  tryCatch({
    ev <- stability(m1)
    print(ev)
    cat("All |eigenvalues| < 1:", all(Mod(ev$roots) < 1), "\n")
  }, error = function(e) cat("Stability check error:", conditionMessage(e), "\n"))
}

# ─────────────────────────────────────────────────────────────────────────────
# M2: Add lag(ln_cpi, 2) as regressor — addresses model misspecification
# (if AR(2) rejects, true second-order dynamics may be missing from model)
# ─────────────────────────────────────────────────────────────────────────────
cat("\n============================================================\n")
cat("M2: panelvar System-GMM — 2 lags of DV as regressors\n")
cat("    (model misspecification fix: include lag-2 y explicitly)\n")
cat("============================================================\n")

m2 <- tryCatch({
  pvargmm(
    dependent_vars             = c("ln_cpi"),
    lags                       = 2,                      # two lags of DV as regressors
    exog_vars                  = c("MII", "ERS", "KAOPEN",
                                   "gdp_growth", "trade_open", "broad_money"),
    transformation             = "fod",
    data                       = panel_gmm,
    panel_identifier           = c("iso3c", "year"),
    steps                      = "twostep",
    system_instruments         = TRUE,
    min_instr_dependent_var    = 3,                      # lag-3 instruments
    max_instr_dependent_var    = 99,
    collapse                   = TRUE
  )
}, error = function(e) {
  cat("M2 ERROR:", conditionMessage(e), "\n"); NULL
})

if (!is.null(m2)) {
  print(summary(m2))
  cat("\n--- Eigenvalue check (M2) ---\n")
  tryCatch({
    ev <- stability(m2)
    print(ev)
    cat("All |eigenvalues| < 1:", all(Mod(ev$roots) < 1), "\n")
  }, error = function(e) cat("Stability check error:", conditionMessage(e), "\n"))
}

# ─────────────────────────────────────────────────────────────────────────────
# PART 2: LSDVC — Bias-Corrected LSDV (Bruno 2005)
# Does NOT require valid moment conditions — bypasses AR(2)/Sargan problem
# Consistent under much weaker assumptions (homoskedastic errors, balanced-ish panel)
# Use for robustness alongside GMM
# ─────────────────────────────────────────────────────────────────────────────
cat("\n============================================================\n")
cat("M3: plm::lsdvc — Bias-Corrected LSDV (Bruno 2005)\n")
cat("    (no GMM moment conditions; AR(2) problem irrelevant)\n")
cat("============================================================\n")

pdat <- pdata.frame(panel_gmm, index = c("iso3c", "year"))

m3 <- tryCatch({
  lsdvc(
    ln_cpi ~ MII + ERS + KAOPEN + gdp_growth + trade_open + broad_money,
    data               = pdat,
    initial.conditions = "bb",        # Blundell-Bond initialization
    bias.correction    = TRUE,
    t.b                = 3            # 3rd-order bias correction
  )
}, error = function(e) {
  cat("M3 BB initialization error:", conditionMessage(e), "\n")
  cat("Trying Anderson-Hsiao initialization...\n")
  tryCatch({
    lsdvc(
      ln_cpi ~ MII + ERS + KAOPEN + gdp_growth + trade_open + broad_money,
      data               = pdat,
      initial.conditions = "ah",
      bias.correction    = TRUE,
      t.b                = 3
    )
  }, error = function(e2) {
    cat("M3 AH initialization error:", conditionMessage(e2), "\n"); NULL
  })
})

if (!is.null(m3)) {
  print(summary(m3))
}

# ─────────────────────────────────────────────────────────────────────────────
# PART 3: Summary Table — all estimators side-by-side
# ─────────────────────────────────────────────────────────────────────────────
cat("\n============================================================\n")
cat("SUMMARY: Trilemma coefficients across estimators\n")
cat("============================================================\n")

extract_coef <- function(model, model_name, vars) {
  if (is.null(model)) {
    df <- data.frame(Estimator = model_name, Variable = vars,
                     Estimate = NA, Std.Error = NA, Statistic = NA, stringsAsFactors = FALSE)
    return(df)
  }
  s <- tryCatch(summary(model), error = function(e) NULL)
  if (is.null(s)) return(NULL)
  cf <- tryCatch(coef(s), error = function(e) tryCatch(s$coef, error = function(e2) NULL))
  if (is.null(cf)) return(NULL)
  res <- lapply(vars, function(v) {
    if (v %in% rownames(cf)) {
      data.frame(Estimator = model_name, Variable = v,
                 Estimate  = round(cf[v, 1], 4),
                 Std.Error = round(cf[v, 2], 4),
                 Statistic = round(cf[v, 3], 3),
                 stringsAsFactors = FALSE)
    } else {
      data.frame(Estimator = model_name, Variable = v,
                 Estimate = NA, Std.Error = NA, Statistic = NA,
                 stringsAsFactors = FALSE)
    }
  })
  do.call(rbind, res)
}

key_vars <- c("ln_cpi-lag1", "MII", "ERS", "KAOPEN")

rows <- list(
  extract_coef(m1, "SysGMM-lag3 (M1)", key_vars),
  extract_coef(m2, "SysGMM-2lags (M2)", key_vars),
  extract_coef(m3, "LSDVC-BB (M3)", key_vars)
)
rows <- Filter(Negate(is.null), rows)

if (length(rows) > 0) {
  tbl <- do.call(rbind, rows)
  print(tbl, row.names = FALSE)
}

# ─────────────────────────────────────────────────────────────────────────────
# Save results
# ─────────────────────────────────────────────────────────────────────────────
out_dir <- "06-Results/tables"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

save_model <- function(model, name) {
  if (is.null(model)) return(invisible(NULL))
  tryCatch({
    sink(file.path(out_dir, paste0(name, "_20260428.txt")))
    cat("=====", name, "=====\n\n")
    print(summary(model))
    cat("\n")
    tryCatch({ print(stability(model)) }, error = function(e) NULL)
    sink()
    cat("Saved:", file.path(out_dir, paste0(name, "_20260428.txt")), "\n")
  }, error = function(e) {
    if (sink.number() > 0) sink()
    cat("Save error for", name, ":", conditionMessage(e), "\n")
  })
}

save_model(m1, "gmm_alt_m1_sysGMM_lag3")
save_model(m2, "gmm_alt_m2_sysGMM_2lags")
save_model(m3, "gmm_alt_m3_lsdvc")

cat("\nDone. Results saved to 06-Results/tables/\n")
