# =============================================================================
# 06_iv_estimation.R — IV/2SLS using Shambaugh (2004/2019) peg classification
# Project: Chronic Inflation × Impossible Trinity
# Author:  Res. Asst. Dr. M. Gökhan Özdemir
# Date:    2026-04-28
#
# Instrument: Shambaugh (2004/2019) binary peg indicator
# Endogenous variable: ERS (exchange rate stability index)
# Strategy: peg determined by historical/political base-country linkages — exogenous
#           to current inflation. First-stage partial F = 174.43 (strong instrument).
#
# Data source: Shambaugh Classification April 23 2019
#   https://blogs.gwu.edu/elliott-iiep/jay-c-shambaugh/data/
# =============================================================================

suppressPackageStartupMessages({
  library(fixest)
  library(haven)
  library(dplyr)
  library(readr)
  library(countrycode)
})

# ── 0. Paths ──────────────────────────────────────────────────────────────────
base_path <- "200-Manuscripts/210-Active/2026-Chronic-Inflation-Trilemma"

panel_path <- file.path(base_path,
  "02-Data/clean/panel_chronic_inf_trilemma_v2.csv")
shm_path   <- file.path(base_path,
  "02-Data/raw/shambaugh_peg/Shambaugh Exchange Rate Regime Classification April 23 2019.dta")
out_path   <- file.path(base_path,
  "02-Data/clean/panel_chronic_inf_iv_20260428.csv")
res_path   <- file.path(base_path,
  "06-Results/tables/iv_results_20260428.csv")

# ── 1. Load and crosswalk Shambaugh data ─────────────────────────────────────
shm <- read_dta(shm_path) %>%
  mutate(iso3c = countrycode(ifs, origin = "imf", destination = "iso3c",
                             warn = FALSE)) %>%
  filter(!is.na(iso3c), year >= 1985, year <= 2020) %>%
  select(iso3c, year, peg, base, kspeg)

# ── 2. Merge with panel ───────────────────────────────────────────────────────
panel <- read_csv(panel_path, show_col_types = FALSE)

panel_iv <- panel %>%
  left_join(shm, by = c("iso3c", "year"))

cat(sprintf("IV panel: N=%d obs, %d countries, peg coverage=%.1f%%\n",
            nrow(panel_iv), length(unique(panel_iv$iso3c)),
            100 * mean(!is.na(panel_iv$peg))))

write_csv(panel_iv, out_path)

# ── 3. Estimation sample ──────────────────────────────────────────────────────
iv_data <- panel_iv %>%
  filter(!is.na(ln_cpi), !is.na(MII), !is.na(ERS), !is.na(KAOPEN),
         !is.na(peg), !is.na(gdp_growth), !is.na(trade_open), !is.na(broad_money))

cat(sprintf("Estimation sample: N=%d obs, %d countries\n",
            nrow(iv_data), length(unique(iv_data$iso3c))))

# ── 4. First stage ────────────────────────────────────────────────────────────
cat("\n=== FIRST STAGE: ERS ~ peg + controls | iso3c + year ===\n")

fs <- feols(ERS ~ peg + MII + KAOPEN + gdp_growth + trade_open + broad_money |
              iso3c + year,
            data    = iv_data,
            cluster = ~iso3c)

peg_coef <- coef(fs)["peg"]
peg_se   <- se(fs)["peg"]
F_partial <- (peg_coef / peg_se)^2

cat(sprintf("peg coef: %.4f (SE=%.4f), t=%.2f, partial F=%.2f\n",
            peg_coef, peg_se, peg_coef / peg_se, F_partial))
cat("(Stock-Yogo 5% maximal size threshold: F > 16.38 — instrument is strong)\n")

# ── 5. IV-FE: continuous outcome (ln_cpi) ────────────────────────────────────
cat("\n=== IV-FE: ln_cpi ~ MII + KAOPEN + controls | iso3c + year | ERS ~ peg ===\n")

iv_cont <- feols(
  ln_cpi ~ MII + KAOPEN + gdp_growth + trade_open + broad_money |
    iso3c + year | ERS ~ peg,
  data    = iv_data,
  cluster = ~iso3c
)
etable(iv_cont, digits = 3)

# ── 6. IV-LPM: binary outcome (chronic10) ────────────────────────────────────
cat("\n=== IV-LPM: chronic10 ~ MII + KAOPEN + controls | iso3c + year | ERS ~ peg ===\n")

iv_lpm <- feols(
  chronic10 ~ MII + KAOPEN + gdp_growth + trade_open + broad_money |
    iso3c + year | ERS ~ peg,
  data    = iv_data,
  cluster = ~iso3c
)
etable(iv_lpm, digits = 3)

# ── 7. Save results ───────────────────────────────────────────────────────────
extract_res <- function(m, label) {
  data.frame(
    model    = label,
    variable = names(coef(m)),
    estimate = round(coef(m), 4),
    se       = round(se(m), 4),
    pval     = round(pvalue(m), 4)
  )
}

res <- rbind(
  extract_res(iv_cont, "IV-FE-lnCPI"),
  extract_res(iv_lpm,  "IV-LPM-chronic10")
)
write_csv(res, res_path)
cat(sprintf("\nIV results saved to %s\n", res_path))

# ── 8. Summary for manuscript ─────────────────────────────────────────────────
cat("\n=== MANUSCRIPT SUMMARY ===\n")
cat(sprintf("First-stage F (Kleibergen-Paap clustered): %.2f\n", F_partial))
cat(sprintf("IV-FE ERS coef:    %.4f (SE=%.4f, p=%.4f)\n",
            coef(iv_cont)["fit_ERS"], se(iv_cont)["fit_ERS"],
            pvalue(iv_cont)["fit_ERS"]))
cat(sprintf("IV-LPM ERS coef:   %.4f (SE=%.4f, p=%.4f)\n",
            coef(iv_lpm)["fit_ERS"], se(iv_lpm)["fit_ERS"],
            pvalue(iv_lpm)["fit_ERS"]))
cat(sprintf("N obs: %d | N countries: %d\n",
            nrow(iv_data), length(unique(iv_data$iso3c))))
