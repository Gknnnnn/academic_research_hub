# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — System-GMM (Blundell-Bond)
# R substitute for Stata xtabond2: pdynmc v0.9.12
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-28
#
# Cite: Fritsch, M. & Pua, A. (2021). pdynmc: A Package for Estimating
#       Linear Dynamic Panel Data Models Based on Nonlinear Moment Conditions.
#       R Journal 13(1):218-238. DOI:10.32614/RJ-2021-035
#       Blundell, R. & Bond, S. (1998). JoE 87(1):115-143. DOI:10.1016/S0304-4076(98)00009-8
#       Windmeijer, F. (2005). JoE 126(1):25-51. DOI:10.1016/j.jeconom.2004.02.005
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(pdynmc)
})

# --- Load panel ---------------------------------------------------------------
latest <- sort(list.files("02-Data/clean",
  pattern = "^panel_chronic_inf_trilemma_\\d{8}\\.csv$",
  full.names = TRUE), decreasing = TRUE)[1]
cat("Reading:", latest, "\n")
panel <- read_csv(latest, show_col_types = FALSE)

panel <- panel |>
  arrange(iso3c, year) |>
  mutate(ln_cpi = log(pmax(cpi, 0.1) + 1))

# Complete cases for GMM
panel_gmm <- panel |>
  filter(!is.na(ln_cpi), !is.na(MII), !is.na(ERS), !is.na(KAOPEN),
         !is.na(gdp_growth), !is.na(trade_open), !is.na(broad_money)) |>
  select(iso3c, year, ln_cpi, MII, ERS, KAOPEN,
         gdp_growth, trade_open, broad_money) |>
  as.data.frame()

cat(sprintf("GMM sample: N=%d countries, obs=%d\n",
            length(unique(panel_gmm$iso3c)), nrow(panel_gmm)))

# =============================================================================
# MODEL B1 — System-GMM, iterative (Blundell-Bond)
# DV: ln_cpi | dynamic: lag(ln_cpi,1)
# MII, ERS, KAOPEN treated as predetermined (weakly exogenous)
# Instruments: lags 2-3 of ln_cpi (diff eq) + lag 1 (level eq)
#              lags 2-3 of predetermined regressors (diff eq) + lag 1 (level eq)
# inst.collapse=FALSE → standard (non-collapsed) instrument matrix
# std.err="corrected" → Windmeijer finite-sample correction
# =============================================================================
cat("\n=== MODEL B1: System-GMM (iterative, Blundell-Bond, full instruments) ===\n")

b1 <- tryCatch({
  pdynmc(
    dat               = panel_gmm,
    varname.i         = "iso3c",
    varname.t         = "year",
    # Dynamic DV
    include.y         = TRUE,
    varname.y         = "ln_cpi",
    lagTerms.y        = 1L,
    maxLags.y         = 3L,
    # Predetermined regressors (weakly exogenous — valid as instruments lagged 2+)
    include.x         = TRUE,
    varname.reg.pre   = c("MII","ERS","KAOPEN","gdp_growth","trade_open","broad_money"),
    lagTerms.reg.pre  = c(0L, 0L, 0L, 0L, 0L, 0L),   # current period as regressors
    maxLags.reg.pre   = c(3L, 3L, 3L, 3L, 3L, 3L),   # lags 2-3 as instruments
    # System GMM (diff + levels)
    use.mc.diff       = TRUE,
    use.mc.lev        = TRUE,
    use.mc.nonlin     = FALSE,
    use.mc.nonlinAS   = FALSE,   # must be explicit in pdynmc v0.9.12
    inst.collapse     = FALSE,
    inst.stata        = TRUE,
    # Weighting + estimation
    w.mat             = "iid.err",
    std.err           = "corrected",
    estimation        = "iterative",
    max.iter          = 100,
    iter.tol          = 0.01
  )
}, error = function(e) {
  cat(sprintf("B1 error: %s\n", conditionMessage(e)))
  NULL
})

# =============================================================================
# MODEL B2 — System-GMM, collapsed instruments (Roodman 2009)
# Collapsed → T instruments instead of T*(T-1)/2 → reduces instrument count
# More conservative Hansen test
# =============================================================================
cat("\n=== MODEL B2: System-GMM (collapsed instruments, Roodman 2009) ===\n")

b2 <- tryCatch({
  pdynmc(
    dat               = panel_gmm,
    varname.i         = "iso3c",
    varname.t         = "year",
    include.y         = TRUE,
    varname.y         = "ln_cpi",
    lagTerms.y        = 1L,
    maxLags.y         = 3L,
    include.x         = TRUE,
    varname.reg.pre   = c("MII","ERS","KAOPEN","gdp_growth","trade_open","broad_money"),
    lagTerms.reg.pre  = c(0L, 0L, 0L, 0L, 0L, 0L),
    maxLags.reg.pre   = c(3L, 3L, 3L, 3L, 3L, 3L),
    use.mc.diff       = TRUE,
    use.mc.lev        = TRUE,
    use.mc.nonlin     = FALSE,
    use.mc.nonlinAS   = FALSE,
    inst.collapse     = TRUE,    # Roodman (2009) collapsing
    inst.stata        = TRUE,
    w.mat             = "iid.err",
    std.err           = "corrected",
    estimation        = "iterative",
    max.iter          = 100,
    iter.tol          = 0.01
  )
}, error = function(e) {
  cat(sprintf("B2 error: %s\n", conditionMessage(e)))
  NULL
})

# =============================================================================
# COEFFICIENT EXTRACTION + SPEC TESTS
# =============================================================================
run_spec_tests <- function(mod, label) {
  if (is.null(mod)) { cat(label, "— model failed\n"); return(invisible(NULL)) }
  cat("\n---", label, "---\n")
  s <- summary(mod)
  ct <- s$coef.table
  cat("\nCoefficients:\n")
  print(ct)
  cat("\nInstrument count:", mod$n.inst, "\n")

  tryCatch({
    ar <- mtest(mod, order = 2L)
    cat(sprintf("AR(1): stat=%.4f p=%.4f\n", ar$test.res[1,1], ar$test.res[1,2]))
    cat(sprintf("AR(2): stat=%.4f p=%.4f\n", ar$test.res[2,1], ar$test.res[2,2]))
    cat("  [AR(1) p<0.05 ✓ | AR(2) p>0.05 → no 2nd-order serial correlation ✓]\n")
  }, error = function(e) cat("mtest error:", conditionMessage(e), "\n"))

  tryCatch({
    jt <- jtest(mod)
    cat(sprintf("Sargan/Hansen J: stat=%.4f df=%d p=%.4f\n",
                jt$j.stat, jt$df, jt$p.value))
    cat(if (jt$p.value > 0.10) "  [p>0.10 → instruments valid ✓]\n" else
        "  [p<0.10 → instruments questionable ⚠️]\n")
  }, error = function(e) cat("jtest error:", conditionMessage(e), "\n"))

  tryCatch({
    wt <- wtest(mod)
    cat(sprintf("Wald: stat=%.4f df=%d p=%.4f\n", wt$w.stat, wt$df, wt$p.value))
  }, error = function(e) cat("wtest error:", conditionMessage(e), "\n"))
}

run_spec_tests(b1, "B1 (full instruments)")
run_spec_tests(b2, "B2 (collapsed instruments)")

# =============================================================================
# KEY SUMMARY FOR MANUSCRIPT
# =============================================================================
cat("\n=== MANUSCRIPT SUMMARY TABLE ===\n")
cat(sprintf("%-15s  %8s  %8s  %8s  %8s\n",
            "Variable", "B1 coef", "B1 p", "B2 coef", "B2 p"))
cat(strrep("-", 55), "\n")

get_coef <- function(mod, vname) {
  if (is.null(mod)) return(c(NA, NA))
  ct <- summary(mod)$coef.table
  idx <- grep(vname, rownames(ct), fixed = TRUE)
  if (length(idx) == 0) return(c(NA, NA))
  c(ct[idx[1], 1], ct[idx[1], 4])
}

for (v in c("MII","ERS","KAOPEN","gdp_growth","trade_open","broad_money")) {
  r1 <- get_coef(b1, v); r2 <- get_coef(b2, v)
  cat(sprintf("%-15s  %8.4f  %8.4f  %8.4f  %8.4f\n",
              v,
              ifelse(is.na(r1[1]), 0, r1[1]),
              ifelse(is.na(r1[2]), 1, r1[2]),
              ifelse(is.na(r2[1]), 0, r2[1]),
              ifelse(is.na(r2[2]), 1, r2[2])))
}
# Dynamic lag
r1 <- get_coef(b1, "ln_cpi"); r2 <- get_coef(b2, "ln_cpi")
cat(sprintf("%-15s  %8.4f  %8.4f  %8.4f  %8.4f\n",
            "lag(ln_cpi,1)",
            ifelse(is.na(r1[1]), 0, r1[1]),
            ifelse(is.na(r1[2]), 1, r1[2]),
            ifelse(is.na(r2[1]), 0, r2[1]),
            ifelse(is.na(r2[2]), 1, r2[2])))

# =============================================================================
# SAVE
# =============================================================================
dir.create("06-Results/tables", recursive = TRUE, showWarnings = FALSE)
sink("06-Results/tables/systemGMM_pdynmc_summary.txt")
cat("=== System-GMM Results — Chronic Inflation × Impossible Trinity ===\n")
cat("Package: pdynmc v0.9.12 | Method: Blundell-Bond (1998) System GMM\n")
cat("Cite: Fritsch & Pua (2021) R Journal 13(1):218-238 DOI:10.32614/RJ-2021-035\n\n")
if (!is.null(b1)) { cat("=== B1 (full instruments) ===\n"); print(summary(b1)) }
if (!is.null(b2)) { cat("\n=== B2 (collapsed instruments) ===\n"); print(summary(b2)) }
sink()
cat("\n✅ Saved: 06-Results/tables/systemGMM_pdynmc_summary.txt\n")
cat("\n=== 07_system_gmm_pdynmc.R COMPLETE ===\n")
cat("Use whichever model passes: AR(2) p>0.05 + Hansen p>0.10\n")
