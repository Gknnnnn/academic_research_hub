# =============================================================================
# Automation, Economic Complexity & Labor Share in Eurasian Economies
# Script 03: Cointegration + CS-ARDL + CCEMG + AMG Estimation
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-24
# =============================================================================

library(dplyr)
library(readr)
library(plm)
library(ARDL)       # for individual ARDL; install.packages("ARDL")
library(fixest)     # feols for FE baseline

# For CCEMG / AMG / CS-ARDL: use custom functions or xtdcce2 Stata equivalent
# R option: "gets" package + manual CCEMG, or use mgu package

# -----------------------------------------------------------------------------
# 0. LOAD PANEL
# -----------------------------------------------------------------------------
data_dir <- here::here("data")
panel_files <- list.files(data_dir, pattern = "panel_automation_eurasian_.*\\.csv", full.names = TRUE)
panel <- read_csv(panel_files[length(panel_files)], show_col_types = FALSE) |>
  arrange(iso3c, year) |>
  group_by(iso3c) |>
  mutate(
    # First differences for robustness
    d_labor_share = labor_share - lag(labor_share),
    d_ln_tfp      = ln_tfp - lag(ln_tfp),
    d_eci         = eci - lag(eci),
    # ECI interaction: TFP × ECI (centered)
    eci_centered  = eci - mean(eci, na.rm = TRUE),
    tfp_eci       = ln_tfp * eci_centered
  ) |>
  ungroup()

pdata <- pdata.frame(panel, index = c("iso3c", "year"))

# =============================================================================
# 1. WESTERLUND (2007) COINTEGRATION TEST
# =============================================================================
# Requires: westerlund package or manual implementation
# install.packages("pdR") # or use cointmonitoR

message("\n========== WESTERLUND COINTEGRATION ==========\n")

tryCatch({
  if (requireNamespace("pdR", quietly = TRUE)) {
    library(pdR)
    # Westerlund panel cointegration
    # H0: no cointegration (all panels)
    west <- coint.test(panel |> select(iso3c, year, labor_share, ln_tfp) |>
                         drop_na() |> pdata.frame(index = c("iso3c","year")),
                       type = "Gt")
    print(west)
  } else {
    message("pdR not available — use Pedroni test as alternative")
    # Pedroni via plm
    pedroni <- plm::pcotest(
      plm(labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
          data = pdata, model = "within"),
      test = "Pedroni"
    )
    print(pedroni)
  }
}, error = function(e) message("Cointegration test error: ", e$message))

# =============================================================================
# 2. BASELINE FE MODEL (Driscoll-Kraay SE)
# =============================================================================
message("\n========== BASELINE FE (Driscoll-Kraay) ==========\n")

library(lmtest); library(sandwich)

fe_base <- plm(
  labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open + ln_hc,
  data  = pdata,
  model = "within",
  effect = "twoways"
)

# Driscoll-Kraay robust SE
dk_se <- coeftest(fe_base, vcov = vcovSCC(fe_base, type = "HC3", cluster = "group"))

message("FE baseline (Driscoll-Kraay SEs):")
print(dk_se)

# =============================================================================
# 3. CS-ARDL — Cross-Sectionally Augmented ARDL
# =============================================================================
message("\n========== CS-ARDL ==========\n")

# Manual CS-ARDL implementation:
# Step 1: Add cross-section means (CSA) as augmentation
# Step 2: Run ARDL per country with CSA as regressors
# Step 3: Average long-run coefficients (MG estimator)

# Cross-section means
cs_means <- panel |>
  group_by(year) |>
  summarise(
    cm_labor_share = mean(labor_share, na.rm = TRUE),
    cm_ln_tfp      = mean(ln_tfp, na.rm = TRUE),
    cm_eci         = mean(eci, na.rm = TRUE),
    cm_trade_open  = mean(trade_open, na.rm = TRUE),
    cm_ln_gdppc    = mean(ln_gdppc, na.rm = TRUE)
  )

panel_csa <- panel |> left_join(cs_means, by = "year")

# CS-ARDL per country (p=1, q=1 as baseline; AIC selection optional)
countries <- unique(panel_csa$iso3c)

csardl_results <- lapply(countries, function(cty) {
  df_c <- panel_csa |>
    filter(iso3c == cty) |>
    arrange(year) |>
    drop_na(labor_share, ln_tfp, capital_intensity, ln_gdppc,
            trade_open, cm_labor_share, cm_ln_tfp)

  if (nrow(df_c) < 15) {
    message("  Skip ", cty, ": insufficient obs (", nrow(df_c), ")")
    return(NULL)
  }

  tryCatch({
    # ARDL(1,1) with CSA augmentation
    df_c <- df_c |> mutate(
      L1_labor_share  = lag(labor_share),
      L1_ln_tfp       = lag(ln_tfp),
      L1_cm_ls        = lag(cm_labor_share),
      L1_cm_tfp       = lag(cm_ln_tfp)
    ) |> drop_na()

    model_c <- lm(
      labor_share ~ L1_labor_share + ln_tfp + L1_ln_tfp +
        capital_intensity + ln_gdppc + trade_open +
        cm_labor_share + cm_ln_tfp + L1_cm_ls + L1_cm_tfp,
      data = df_c
    )

    coefs <- coef(model_c)
    # Long-run coefficient: β_LR(tfp) = (b_tfp + b_L1tfp) / (1 - b_L1y)
    b_y1  <- coefs["L1_labor_share"]
    b_x   <- coefs["ln_tfp"]
    b_lx  <- coefs["L1_ln_tfp"]

    lr_tfp <- (b_x + b_lx) / (1 - b_y1)
    ec_speed <- -(1 - b_y1)  # error correction speed

    tibble(
      iso3c      = cty,
      n_obs      = nrow(df_c),
      lr_tfp     = lr_tfp,
      ec_speed   = ec_speed,
      r_squared  = summary(model_c)$r.squared
    )
  }, error = function(e) {
    message("  Error for ", cty, ": ", e$message)
    NULL
  })
}) |> bind_rows()

message("\nCS-ARDL country-level long-run TFP coefficients:")
print(csardl_results)

# MG (Mean Group) pooled long-run estimate
mg_lr_tfp  <- mean(csardl_results$lr_tfp,  na.rm = TRUE)
mg_ec      <- mean(csardl_results$ec_speed, na.rm = TRUE)
mg_se_tfp  <- sd(csardl_results$lr_tfp, na.rm = TRUE) / sqrt(sum(!is.na(csardl_results$lr_tfp)))

message("\n=== MG LONG-RUN ESTIMATES ===")
message("TFP → Labor Share (LR):  β = ", round(mg_lr_tfp, 4),
        "  SE = ", round(mg_se_tfp, 4),
        "  t = ", round(mg_lr_tfp / mg_se_tfp, 3))
message("Error Correction Speed:   ", round(mg_ec, 4))

# =============================================================================
# 4. ECI INTERACTION — Technology × Economic Complexity
# =============================================================================
message("\n========== ECI INTERACTION (Split Sample) ==========\n")

# Split countries by median ECI
if ("eci" %in% names(panel) && !all(is.na(panel$eci))) {
  median_eci <- median(panel$eci, na.rm = TRUE)

  panel_high_eci <- panel |> filter(eci >= median_eci)
  panel_low_eci  <- panel |> filter(eci <  median_eci)

  fe_high <- plm(labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
                 data = pdata.frame(panel_high_eci, index = c("iso3c","year")),
                 model = "within", effect = "twoways")

  fe_low  <- plm(labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
                 data = pdata.frame(panel_low_eci, index = c("iso3c","year")),
                 model = "within", effect = "twoways")

  message("High ECI countries — TFP coef: ", round(coef(fe_high)["ln_tfp"], 4))
  message("Low  ECI countries — TFP coef: ", round(coef(fe_low)["ln_tfp"], 4))
  message("Interpretation: Does technology reduce labor share more in complex vs. simple economies?")
} else {
  message("⚠️  ECI data not yet available — run after downloading OEC ECI file")
}

# =============================================================================
# 5. DUMITRESCU-HURLIN CAUSALITY
# =============================================================================
message("\n========== DUMITRESCU-HURLIN CAUSALITY ==========\n")

tryCatch({
  # plm::phtest gives Granger; for DH use xtgcause equivalent
  # Workaround: panel Granger via purtest on residuals or use lmtest::grangertest per country
  dh_results <- lapply(countries, function(cty) {
    df_c <- panel |> filter(iso3c == cty) |> arrange(year) |>
      drop_na(labor_share, ln_tfp)
    if (nrow(df_c) < 10) return(NULL)
    tryCatch({
      gt <- lmtest::grangertest(df_c$labor_share ~ df_c$ln_tfp, order = 2)
      tibble(iso3c = cty, F_stat = gt$F[2], p_value = gt$`Pr(>F)`[2])
    }, error = function(e) NULL)
  }) |> bind_rows()

  # Dumitrescu-Hurlin W-bar statistic
  n_sig  <- sum(dh_results$p_value < 0.05, na.rm = TRUE)
  w_bar  <- mean(dh_results$F_stat, na.rm = TRUE)
  message("Countries with TFP→LaborShare Granger causality (p<.05): ",
          n_sig, "/", nrow(dh_results))
  message("Average F-stat (W-bar proxy): ", round(w_bar, 3))
  print(dh_results)
}, error = function(e) message("DH causality error: ", e$message))

# =============================================================================
# 6. SAVE RESULTS
# =============================================================================
write_csv(csardl_results,
          file.path(data_dir, "results_csardl_country_20260424.csv"))

results_summary <- tibble(
  estimator   = c("MG (CS-ARDL)", "FE Baseline"),
  lr_tfp_coef = c(mg_lr_tfp,     coef(fe_base)["ln_tfp"]),
  note        = c("Mean Group LR", "FE two-way")
)
write_csv(results_summary, file.path(data_dir, "results_main_20260424.csv"))

message("\n✅ Script 03 complete. Next: 04_robustness.R")
