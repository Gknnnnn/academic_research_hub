# ============================================================
# 02_unit_root.R
# LCF Turkey Bootstrap ARDL — Unit Root Battery
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Tests:
#   1. ADF (Augmented Dickey-Fuller) — baseline
#   2. PP (Phillips-Perron) — baseline
#   3. KPSS (Kwiatkowski-Phillips-Schmidt-Shin) — stationarity null
#   4. Zivot-Andrews (1992) — single endogenous structural break
#   5. Lee-Strazicich (2003) — double structural break [strongest]
# ============================================================

library(tidyverse)
library(tseries)      # adf.test, kpss.test
library(urca)         # ca.jo, ur.df, ur.pp, ur.za
library(strucchange)  # breakpoints
library(lmtest)

# ============================================================
# LOAD DATA
# ============================================================
panel_file <- list.files("data", pattern = "turkey_lcf_panel_", full.names = TRUE) |>
  sort() |> tail(1)

if (length(panel_file) == 0) stop("No panel data found. Run 01_data_download.R first.")
cat("Loading:", panel_file, "\n")
panel <- read_csv(panel_file, show_col_types = FALSE)

# Variables to test (levels and first differences)
# lnFDI excluded: FDI not in core model; too many NAs in Turkey sample
vars_level <- c("lnLCF", "lnGDP", "lnGDP2", "lnREN", "lnTrade")
vars_diff  <- paste0("d_", vars_level)

# Create first differences
panel_ts <- panel |>
  arrange(year) |>
  mutate(across(all_of(vars_level), ~ c(NA, diff(.)), .names = "d_{.col}"))

# ============================================================
# HELPER: Format unit root results into a table row
# ============================================================
ur_row <- function(varname, level_or_diff, test_stat, cv_1, cv_5, cv_10,
                   break_year = NA, decision) {
  tibble(
    Variable = varname,
    Specification = level_or_diff,
    Test_Stat = round(test_stat, 4),
    CV_1pct = cv_1,
    CV_5pct = cv_5,
    CV_10pct = cv_10,
    Break_Year = break_year,
    Decision = decision
  )
}

results <- list()

# ============================================================
# 1. ADF TEST (urca::ur.df)
# ============================================================
cat("\n=== ADF TEST ===\n")
for (v in vars_level) {
  series_l <- ts(na.omit(panel[[v]]))
  series_d <- ts(na.omit(panel_ts[[paste0("d_", v)]]))

  adf_l <- ur.df(series_l, type = "trend", selectlags = "AIC")
  adf_d <- ur.df(series_d, type = "drift", selectlags = "AIC")

  cat(v, "| Level t-stat:", round(adf_l@teststat[1], 3),
      "| 5% CV:", adf_l@cval[2, "5pct"],
      "| Diff t-stat:", round(adf_d@teststat[1], 3), "\n")
}

# ============================================================
# 2. PP TEST (urca::ur.pp)
# ============================================================
cat("\n=== PP TEST ===\n")
for (v in vars_level) {
  series_l <- ts(na.omit(panel[[v]]))
  series_d <- ts(na.omit(panel_ts[[paste0("d_", v)]]))

  pp_l <- ur.pp(series_l, type = "Z-tau", model = "trend")
  pp_d <- ur.pp(series_d, type = "Z-tau", model = "constant")

  cat(v, "| Level Z-tau:", round(pp_l@teststat, 3),
      "| 5% CV:", pp_l@cval[2],
      "| Diff Z-tau:", round(pp_d@teststat, 3), "\n")
}

# ============================================================
# 3. KPSS TEST (tseries::kpss.test)
# ============================================================
cat("\n=== KPSS TEST (H0: stationary) ===\n")
for (v in vars_level) {
  series_l <- na.omit(panel[[v]])
  kpss_l <- kpss.test(series_l, null = "Trend")
  cat(v, "| KPSS stat:", round(kpss_l$statistic, 4),
      "| p-value:", round(kpss_l$p.value, 4),
      "| Decision:", ifelse(kpss_l$p.value < 0.05, "REJECT H0 (non-stationary)", "Cannot reject (stationary)"), "\n")
}

# ============================================================
# 4. ZIVOT-ANDREWS TEST (urca::ur.za)
# ============================================================
cat("\n=== ZIVOT-ANDREWS TEST (single structural break) ===\n")
za_results <- tibble()

for (v in vars_level) {
  series_l <- ts(na.omit(panel[[v]]))
  za <- ur.za(series_l, model = "both", lag = NULL)

  break_idx  <- which.min(za@teststat)
  break_year <- panel$year[!is.na(panel[[v]])][break_idx]

  cat(v, "| ZA stat:", round(za@teststat[break_idx], 3),
      "| Break year:", break_year,
      "| 5% CV:", za@cval[2], "\n")

  za_results <- bind_rows(za_results, tibble(
    variable   = v,
    za_stat    = round(za@teststat[break_idx], 3),
    break_year = break_year,
    cv_5pct    = za@cval[2],
    decision   = ifelse(za@teststat[break_idx] < za@cval[2],
                        "I(0) — stationary", "I(1) — unit root")
  ))
}

cat("\nZivot-Andrews Summary:\n")
print(za_results)

# ============================================================
# 5. LEE-STRAZICICH TEST (double break)
# ============================================================
# Lee-Strazicich (2003) LM unit root with two structural breaks
# R implementation via manual LM statistic or 'lsunit' package
# Using strucchange approach as approximation + urca for documentation
# Full LS test: use EViews or GAUSS for exact critical values
# R approximation via breakpoints() + lm residuals

cat("\n=== LEE-STRAZICICH (2-break) APPROXIMATION ===\n")
cat("Note: Exact LS (2003) critical values require EViews/GAUSS.\n")
cat("R approximation below — cross-check with EViews LM stat.\n\n")

ls_results <- tibble()

for (v in vars_level) {
  series_l <- na.omit(panel[[v]])
  t_series  <- ts(series_l, start = panel$year[!is.na(panel[[v]])][1])

  tryCatch({
    # Find two structural breaks using strucchange
    bp <- breakpoints(t_series ~ 1, breaks = 2)
    bp_years <- panel$year[!is.na(panel[[v]])][bp$breakpoints]

    # LM-type test: regress on trend + dummies at break points
    n <- length(series_l)
    t_idx <- 1:n
    d1 <- as.integer(t_idx > bp$breakpoints[1])
    d2 <- as.integer(t_idx > bp$breakpoints[2])
    lm_fit <- lm(series_l ~ t_idx + d1 + d2)
    lm_resid <- residuals(lm_fit)

    # ADF on residuals (approximate LM statistic)
    adf_res <- adf.test(lm_resid)
    cat(v, "| Break years:", paste(bp_years, collapse = ", "),
        "| ADF on detrended resid:", round(adf_res$statistic, 3),
        "| p:", round(adf_res$p.value, 4), "\n")

    ls_results <- bind_rows(ls_results, tibble(
      variable    = v,
      break_year1 = bp_years[1],
      break_year2 = bp_years[2],
      approx_stat = round(adf_res$statistic, 3),
      p_value     = round(adf_res$p.value, 4)
    ))
  }, error = function(e) {
    cat(v, "| LS approximation failed:", conditionMessage(e), "\n")
  })
}

cat("\nLee-Strazicich Approximation Summary:\n")
print(ls_results)

# ============================================================
# 6. INTEGRATION ORDER SUMMARY TABLE
# ============================================================
cat("\n=== INTEGRATION ORDER SUMMARY ===\n")
cat("Based on ADF + PP + KPSS + ZA results — manual review required for final decision.\n")
cat("Rule: I(1) if ADF & PP fail to reject unit root in levels but reject in first differences.\n")
cat("Expected: all variables I(1) — required for ARDL/FMOLS/CCR cointegration.\n\n")

# Print final note for Lissack compliance
cat("⚠️ LISSACK L1: All unit root results must be tabled with test stat + CV.\n")
cat("⚠️ Do NOT conclude 'I(1)' without both level non-rejection AND diff rejection.\n")

cat("\n=== 02_unit_root.R COMPLETE ===\n")
