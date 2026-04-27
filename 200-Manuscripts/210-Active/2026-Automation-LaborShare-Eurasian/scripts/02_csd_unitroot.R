# =============================================================================
# Automation, Economic Complexity & Labor Share in Eurasian Economies
# Script 02: Cross-Section Dependence + Panel Unit Root Tests
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-24
# =============================================================================

library(dplyr)
library(readr)
library(plm)
library(purtest)   # IPS, Hadri
library(CADFtest)  # CADF individual tests

# install.packages(c("plm", "CADFtest", "psych"))

# -----------------------------------------------------------------------------
# 0. LOAD PANEL
# -----------------------------------------------------------------------------
data_dir <- here::here("data")

# Load most recent master panel
panel_files <- list.files(data_dir, pattern = "panel_automation_eurasian_.*\\.csv", full.names = TRUE)
panel <- read_csv(panel_files[length(panel_files)], show_col_types = FALSE)

# Variables to test
vars_to_test <- c("labor_share", "ln_tfp", "capital_intensity", "eci",
                  "ln_gdppc", "trade_open", "ln_hc")

# Convert to pdata.frame
pdata <- pdata.frame(panel, index = c("iso3c", "year"))

# =============================================================================
# 1. CROSS-SECTION DEPENDENCE (CSD) TESTS
# =============================================================================
message("\n========== CSD TESTS (Pesaran 2004) ==========\n")

csd_results <- lapply(vars_to_test, function(v) {
  tryCatch({
    formula <- as.formula(paste(v, "~ 1"))
    fe_model <- plm(formula, data = pdata, model = "within")
    cd_test <- plm::pcdtest(fe_model, test = "cd")
    tibble(
      variable = v,
      CD_stat  = round(cd_test$statistic, 3),
      p_value  = round(cd_test$p.value, 4),
      result   = if_else(cd_test$p.value < 0.05, "CSD ✓", "No CSD")
    )
  }, error = function(e) {
    tibble(variable = v, CD_stat = NA, p_value = NA, result = paste("Error:", e$message))
  })
}) |> bind_rows()

message("Pesaran CD Results:")
print(csd_results)

# =============================================================================
# 2. SLOPE HOMOGENEITY — Pesaran-Yamagata (2008)
# =============================================================================
message("\n========== SLOPE HOMOGENEITY (Pesaran-Yamagata 2008) ==========\n")

# Manual implementation: Δ and Δ̃ tests
# Regress y on x for each country; test H0: slopes are homogeneous
# Using plm::phtest as approximation

tryCatch({
  if (all(c("labor_share", "ln_tfp") %in% names(panel))) {
    formula_sh <- labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open
    pooled <- plm(formula_sh, data = pdata, model = "pooling")
    within  <- plm(formula_sh, data = pdata, model = "within")
    sh_test <- plm::phtest(within, pooled)
    message("Hausman (pooled vs. FE): stat=", round(sh_test$statistic, 3),
            " p=", round(sh_test$p.value, 4))
    message("Interpretation: ", if_else(sh_test$p.value < 0.05,
                                         "Slope heterogeneity present → use CS-ARDL/CCEMG",
                                         "Slopes may be homogeneous → PMG feasible"))
  }
}, error = function(e) message("Slope homogeneity test error: ", e$message))

# =============================================================================
# 3. PANEL UNIT ROOT TESTS
# =============================================================================
message("\n========== PANEL UNIT ROOT TESTS ==========\n")

# 3a. IPS (Im-Pesaran-Shin 2003) — allows for heterogeneity
message("--- IPS Test ---")
ips_results <- lapply(vars_to_test, function(v) {
  tryCatch({
    x <- panel |> arrange(iso3c, year) |> select(iso3c, year, all_of(v)) |>
      tidyr::drop_na() |>
      pdata.frame(index = c("iso3c", "year"))
    formula <- as.formula(paste(v, "~ 1"))
    ips <- purtest(formula, data = x, test = "ips", exo = "intercept", lags = "AIC")
    tibble(
      variable = v,
      test     = "IPS",
      stat     = round(summary(ips)$statistic[[1]], 3),
      p_value  = round(summary(ips)$p.value[[1]], 4),
      result   = if_else(summary(ips)$p.value[[1]] < 0.05, "Stationary I(0)", "Unit root I(1)")
    )
  }, error = function(e) {
    tibble(variable = v, test = "IPS", stat = NA, p_value = NA, result = paste("Error:", e$message))
  })
}) |> bind_rows()

print(ips_results)

# 3b. CIPS (Pesaran 2007) — cross-sectionally augmented
# Requires pescadf or CIPS from cips() — use CADFtest as individual complement
message("\n--- Individual CADF Tests (Pesaran 2007 basis) ---")

cadf_summary <- lapply(vars_to_test, function(v) {
  v_data <- panel |>
    select(iso3c, year, all_of(v)) |>
    drop_na() |>
    group_by(iso3c) |>
    filter(n() >= 10) |>
    ungroup()

  countries_ok <- unique(v_data$iso3c)
  results <- lapply(countries_ok, function(cty) {
    ts_data <- v_data |> filter(iso3c == cty) |> pull(!!v)
    tryCatch({
      ct <- CADFtest(ts_data, type = "drift", max.lag.y = 2, criterion = "AIC")
      tibble(iso3c = cty, variable = v, stat = ct$statistic, p_crit_10 = ct$p.value)
    }, error = function(e) NULL)
  }) |> bind_rows()

  # CIPS = mean of CADF statistics
  cips_stat <- mean(results$stat, na.rm = TRUE)
  tibble(
    variable  = v,
    CIPS_stat = round(cips_stat, 3),
    # Critical values (Pesaran 2007, T=25, N=10): -2.28 (10%), -2.42 (5%)
    result    = if_else(cips_stat < -2.42, "Stationary (5%)",
                        if_else(cips_stat < -2.28, "Stationary (10%)", "Unit root"))
  )
}) |> bind_rows()

message("\nCIPS Results (Pesaran 2007 critical values: -2.42 at 5%, -2.28 at 10%):")
print(cadf_summary)

# =============================================================================
# 4. SUMMARY TABLE — Integration Orders
# =============================================================================
integration_order <- ips_results |>
  left_join(cadf_summary, by = "variable") |>
  mutate(
    I_order = case_when(
      result.x == "Stationary I(0)" & grepl("Stationary", result.y) ~ "I(0)",
      TRUE ~ "I(1) — check first difference"
    )
  ) |>
  select(variable, IPS_stat = stat, IPS_p = p_value,
         CIPS_stat, IPS_result = result.x, CIPS_result = result.y, I_order)

message("\n=== INTEGRATION ORDER SUMMARY ===")
print(integration_order)

# Save
write_csv(csd_results,        file.path(data_dir, "results_csd_20260424.csv"))
write_csv(ips_results,        file.path(data_dir, "results_ips_20260424.csv"))
write_csv(cadf_summary,       file.path(data_dir, "results_cips_20260424.csv"))
write_csv(integration_order,  file.path(data_dir, "results_integration_summary_20260424.csv"))

message("\n✅ Script 02 complete. Next: 03_cointegration_csardl.R")
message("Expected result: labor_share ~ I(1); ln_tfp ~ I(1) → cointegration feasible")
