## EK2011 (Emirmahmutoğlu-Köse 2011) Panel Causality — CIVETS Unemployment
## Bootstrap TY-based Fisher panel causality, heterogeneous panels
## Script: 08_ek2011_causality_20260428.R
## Parallel to Konya (2006) in 05_konya_causality_20260426.R
## Adds panel-level Fisher statistic: -2∑ln(p_i) ~ χ²(2N)

suppressPackageStartupMessages({
  library(tidyverse)
  library(vars)
  library(aod)
})

EK_SRC <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/600-Methods/EYS25_Panel_Emirmahmutoglu/EK2011_R"
source(file.path(EK_SRC, "TYGC.R"))
source(file.path(EK_SRC, "EK.R"))

DATA_PATH <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-CIVETS-Unemployment-UY-MGO/01-Data/raw/civets_panel_full_20260428.csv"

panel <- read_csv(DATA_PATH, show_col_types = FALSE) %>%
  arrange(iso3c, year) %>%
  filter(year >= 2000, year <= 2023)

countries <- sort(unique(panel$iso3c))  # COL, EGY, IDN, TUR, VNM, ZAF
NN <- length(countries)  # N = 6
T_obs <- length(unique(panel$year))  # T = 24

cat("CIVETS panel: N =", NN, "| T =", T_obs, "\n")
cat("Countries:", paste(countries, collapse = ", "), "\n\n")

# ── Helper: build stacked matrix for EK ──────────────────────────────
# EK requires: each country's T observations stacked vertically
# Rows: country1_t1..T, country2_t1..T, ..., countryN_t1..T
# Cols: [dep_var, cause_var]
build_stacked <- function(dep_var, cause_var, df, countries) {
  mat_list <- lapply(countries, function(cty) {
    d <- df %>% filter(iso3c == cty) %>% arrange(year)
    cbind(d[[dep_var]], d[[cause_var]])
  })
  do.call(rbind, mat_list)
}

# ── dmax: integration order per country ──────────────────────────────
# From pretests: all key series I(1) (confirmed by CIPS unit root)
dmax_vec <- rep(1, NN)

# ── Causality pairs (matching Konya test) ────────────────────────────
pairs <- list(
  list(dep = "unemp", cause = "gdp_growth",  label = "gdp_growth → unemp"),
  list(dep = "unemp", cause = "inflation",   label = "inflation → unemp"),
  list(dep = "unemp", cause = "fdi",         label = "fdi → unemp"),
  list(dep = "unemp", cause = "trade",       label = "trade → unemp"),
  list(dep = "gdp_growth", cause = "unemp",  label = "unemp → gdp_growth")
)

# ── Run EK for each pair ──────────────────────────────────────────────
results <- lapply(pairs, function(pr) {
  cat("Running:", pr$label, "...\n")

  mat <- build_stacked(pr$dep, pr$cause, panel, countries)

  tryCatch({
    ek_out <- EK(series = mat, NN = NN, dmax = dmax_vec,
                 lag.max = 3, ic = "AIC", type = "constant")

    # Fisher stat: row = dep (i), col = cause (j)
    # dep = col 1, cause = col 2 → direction: cause → dep = [1,2]
    fisher_stat <- ek_out$Fisher_Stat[1, 2]
    fisher_p    <- ek_out$p_value[1, 2]

    # Individual country stats
    ind_wald <- ek_out$Individual_Wald[1, 2, ]
    ind_p    <- ek_out$Individual_pvalue[1, 2, ]
    ind_lag  <- ek_out$Individual_LagOrder

    cat("  Fisher χ²(", 2*NN, ") =", round(fisher_stat, 3),
        "| p =", round(fisher_p, 4), "\n")

    tibble(
      direction   = pr$label,
      fisher_chi2 = round(fisher_stat, 4),
      fisher_df   = 2 * NN,
      fisher_p    = round(fisher_p, 4),
      sig         = case_when(
        fisher_p < 0.01  ~ "***",
        fisher_p < 0.05  ~ "**",
        fisher_p < 0.10  ~ "*",
        TRUE             ~ ""
      ),
      country_pvals = paste(countries, round(ind_p, 3), sep = "=", collapse = "; "),
      country_lags  = paste(countries, ind_lag, sep = "=", collapse = "; "),
      date_run = "2026-04-28"
    )
  }, error = function(e) {
    cat("  ERROR:", conditionMessage(e), "\n")
    tibble(direction = pr$label, fisher_chi2 = NA, fisher_df = 2*NN,
           fisher_p = NA, sig = "ERROR", country_pvals = e$message,
           country_lags = NA, date_run = "2026-04-28")
  })
})

ek_results <- bind_rows(results)

cat("\n=== EK2011 Panel Causality Results ===\n")
print(ek_results %>% dplyr::select(direction, fisher_chi2, fisher_df, fisher_p, sig))

# Save
out_path <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-CIVETS-Unemployment-UY-MGO/03-Output/ek2011_causality_results_20260428.csv"
write_csv(ek_results, out_path)
cat("\nResults saved to:", out_path, "\n")
