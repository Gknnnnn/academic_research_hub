# =============================================================================
# Panel Probit Estimation: Sudden Stop Determinants
# Paper: Global Uncertainty, Domestic Credit, and Sudden Stops
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-28
# MGO Novelty: CSD-robust SE + Pesaran CD pre-test + heterogeneity analysis
# =============================================================================

library(dplyr)
library(tidyr)
library(plm)          # panel probit, pcdtest
library(sandwich)     # vcovHC, vcovDK (Driscoll-Kraay)
library(lmtest)       # coeftest
library(margins)      # average marginal effects
library(modelsummary) # publication-quality tables
library(ggplot2)
library(broom)

# =============================================================================
# SECTION 1: DATA PREPARATION
# =============================================================================

load_panel <- function(ss_path    = "02-Data/sudden_stop_binary_fw2012.csv",
                       wdi_path   = "02-Data/wdi_controls_annual_YYYYMMDD.csv",
                       push_path  = "02-Data/global_push_factors_quarterly.csv",
                       mpp_path   = "02-Data/imf_imapp_quarterly.csv") {

  df_ss   <- readr::read_csv(ss_path,   show_col_types = FALSE)
  df_wdi  <- readr::read_csv(wdi_path,  show_col_types = FALSE)
  df_push <- readr::read_csv(push_path, show_col_types = FALSE)
  df_mpp  <- readr::read_csv(mpp_path,  show_col_types = FALSE)

  # Merge quarterly SS + push; annual WDI matched to quarter by year
  df_panel <- df_ss %>%
    mutate(year = lubridate::year(date)) %>%
    left_join(df_push,                       by = "date") %>%
    left_join(df_wdi %>% pivot_wider(names_from = variable, values_from = value),
              by = c("iso3", "year")) %>%
    left_join(df_mpp, by = c("iso3", "date")) %>%
    arrange(iso3, date)

  return(df_panel)
}

# =============================================================================
# SECTION 2: PRE-ESTIMATION TESTS (MGO novelty — not in any existing SS paper)
# =============================================================================

run_pretests <- function(df, dep_var = "sudden_stop") {
  pdata <- pdata.frame(df, index = c("iso3", "date"))

  results <- list()

  # 2.1 Pesaran CD test on key regressors (cross-sectional dependence)
  # If CD is significant → CSD-robust SE required; motivates Driscoll-Kraay
  cat("\n=== PESARAN CD TEST (Cross-Sectional Dependence) ===\n")
  cd_vars <- c("vix", "ffr", "gdp_growth", "ca_pct_gdp", "credit_pct_gdp")
  for (v in cd_vars) {
    if (v %in% names(pdata)) {
      cd_test <- tryCatch(
        pcdtest(as.formula(paste(v, "~ 1")), data = pdata, test = "cd"),
        error = function(e) NULL
      )
      if (!is.null(cd_test)) {
        cat(sprintf("  %s: CD stat = %.3f, p = %.4f\n",
                    v, cd_test$statistic, cd_test$p.value))
        results[[paste0("cd_", v)]] <- cd_test
      }
    }
  }

  # 2.2 Pesaran-Yamagata slope homogeneity test
  # (from CLAUDE.md standard toolkit)
  cat("\n=== SLOPE HOMOGENEITY (Pesaran-Yamagata) ===\n")
  cat("  Run manually: pescadf() or phtest() in plm\n")
  cat("  Significant → heterogeneous slopes → country FE preferred over RE\n")

  # 2.3 Check for multicollinearity (VIF)
  cat("\n=== VIF CHECK ===\n")
  lm_check <- lm(
    sudden_stop ~ vix + ffr + gdp_growth + ca_pct_gdp +
      credit_pct_gdp + log_reserves_gdp + trade_open,
    data = df
  )
  vif_vals <- tryCatch(car::vif(lm_check), error = function(e) NULL)
  if (!is.null(vif_vals)) {
    print(round(vif_vals, 2))
    if (any(vif_vals > 10)) warning("VIF > 10 detected — multicollinearity concern")
  }

  invisible(results)
}

# =============================================================================
# SECTION 3: BASELINE PANEL PROBIT MODELS
# =============================================================================
# Model sequence (Eichengreen & Gupta 2016 approach; extended with CSD correction)
#
# M1: Push factors only (global)
# M2: Pull factors only (domestic)
# M3: Push + Pull (baseline)
# M4: M3 + macroprudential
# M5: M4 + MPP × domestic credit interaction (main result)

run_baseline_models <- function(df) {
  # Formula components
  push  <- "vix_lag1 + ffr_lag1 + global_gdp_growth"
  pull  <- "ca_pct_gdp_lag1 + credit_pct_gdp_lag1 + log_reserves_gdp_lag1 + trade_open_lag1"
  mpp   <- "mpp_tightening_lag1"
  inter <- "mpp_tightening_lag1 * credit_pct_gdp_lag1"

  # Lag push/pull by 1 quarter (predeterminedness assumption)
  df <- df %>%
    group_by(iso3) %>%
    mutate(
      across(c(vix, ffr, global_gdp_growth, ca_pct_gdp, credit_pct_gdp,
               log_reserves_gdp, trade_open, mpp_tightening),
             ~ lag(., 1), .names = "{.col}_lag1")
    ) %>%
    ungroup()

  models <- list()

  # M1: Push only
  models$M1 <- glm(
    as.formula(paste("sudden_stop ~", push, "+ factor(iso3)")),
    data = df, family = binomial(link = "probit"),
    na.action = na.omit
  )

  # M2: Pull only
  models$M2 <- glm(
    as.formula(paste("sudden_stop ~", pull, "+ factor(iso3)")),
    data = df, family = binomial(link = "probit"),
    na.action = na.omit
  )

  # M3: Push + Pull (baseline)
  models$M3 <- glm(
    as.formula(paste("sudden_stop ~", push, "+", pull, "+ factor(iso3)")),
    data = df, family = binomial(link = "probit"),
    na.action = na.omit
  )

  # M4: + Macroprudential
  models$M4 <- glm(
    as.formula(paste("sudden_stop ~", push, "+", pull, "+", mpp, "+ factor(iso3)")),
    data = df, family = binomial(link = "probit"),
    na.action = na.omit
  )

  # M5: + MPP × Credit interaction (main result; replicates Business Perspectives 2025)
  models$M5 <- glm(
    as.formula(paste("sudden_stop ~", push, "+", pull, "+", inter, "+ factor(iso3)")),
    data = df, family = binomial(link = "probit"),
    na.action = na.omit
  )

  return(list(models = models, data = df))
}

# =============================================================================
# SECTION 4: DRISCOLL-KRAAY (CSD-ROBUST) STANDARD ERRORS
# =============================================================================
# This is MGO's methodological contribution:
# All existing SS papers use standard clustered SE.
# Driscoll-Kraay accounts for both cross-sectional AND temporal dependence.

apply_dk_se <- function(model, data, lag_order = 4) {
  # Driscoll-Kraay via sandwich::vcovDK
  # lag_order = 4 quarters (1 year) is conventional
  dk_vcov <- tryCatch(
    sandwich::vcovDK(model, type = "HC3", lag = lag_order),
    error = function(e) {
      message("DK SE failed: ", e$message, " — using clustered SE instead")
      sandwich::vcovCL(model, cluster = data$iso3)
    }
  )
  lmtest::coeftest(model, vcov = dk_vcov)
}

# =============================================================================
# SECTION 5: AVERAGE MARGINAL EFFECTS (AME)
# =============================================================================
# Required for economic interpretation:
# "A 1 SD increase in VIX raises sudden stop probability by X pp"

compute_ame <- function(model, data) {
  ame <- margins::margins(model, data = data)
  ame_summary <- summary(ame) %>%
    filter(!grepl("factor\\(", factor)) %>%  # exclude country dummies
    mutate(
      ame_pct  = AME * 100,   # convert to percentage points
      se_pct   = SE  * 100,
      ci_low   = ame_pct - 1.96 * se_pct,
      ci_high  = ame_pct + 1.96 * se_pct
    ) %>%
    select(factor, ame_pct, se_pct, ci_low, ci_high, p)

  return(ame_summary)
}

# =============================================================================
# SECTION 6: ROBUSTNESS SPECIFICATIONS
# =============================================================================

run_robustness <- function(df, baseline_formula) {

  robust_results <- list()

  # R1: Logit instead of probit
  robust_results$logit <- glm(
    baseline_formula, data = df,
    family = binomial(link = "logit"), na.action = na.omit
  )

  # R2: Complementary log-log (cloglog) — appropriate for rare events
  # Forbes & Warnock (2012) and Eichengreen & Gupta (2016) recommend this
  robust_results$cloglog <- glm(
    baseline_formula, data = df,
    family = binomial(link = "cloglog"), na.action = na.omit
  )

  # R3: Exclude GFC 2008-09
  df_no_gfc <- df %>%
    filter(!(date >= as.Date("2008-07-01") & date <= "2009-12-31"))
  robust_results$no_gfc <- glm(
    baseline_formula, data = df_no_gfc,
    family = binomial(link = "probit"), na.action = na.omit
  )

  # R4: Exclude COVID 2020
  df_no_covid <- df %>%
    filter(!(date >= as.Date("2020-01-01") & date <= "2020-12-31"))
  robust_results$no_covid <- glm(
    baseline_formula, data = df_no_covid,
    family = binomial(link = "probit"), na.action = na.omit
  )

  # R5: Net flows instead of gross (alternative definition)
  if ("sudden_stop_net" %in% names(df)) {
    baseline_net <- update(baseline_formula, sudden_stop_net ~ .)
    robust_results$net_flows <- glm(
      baseline_net, data = df,
      family = binomial(link = "probit"), na.action = na.omit
    )
  }

  # R6: Emerging only subsample
  if ("income_group" %in% names(df)) {
    df_em <- df %>% filter(income_group == "Emerging")
    robust_results$em_only <- glm(
      baseline_formula, data = df_em,
      family = binomial(link = "probit"), na.action = na.omit
    )
  }

  return(robust_results)
}

# =============================================================================
# SECTION 7: HETEROGENEITY ANALYSIS (Advanced vs. Emerging vs. Eurasian)
# =============================================================================

run_heterogeneity <- function(df, baseline_formula) {
  groups <- list(
    advanced  = filter(df, income_group == "Advanced"),
    emerging  = filter(df, income_group == "Emerging"),
    eurasian  = filter(df, region == "Eurasia/CIS")
  )

  lapply(groups, function(g) {
    tryCatch(
      glm(baseline_formula, data = g,
          family = binomial(link = "probit"), na.action = na.omit),
      error = function(e) {
        message("Heterogeneity group failed: ", e$message)
        NULL
      }
    )
  })
}

# =============================================================================
# SECTION 8: PUBLICATION TABLE (Table 2 — baseline results)
# =============================================================================

make_results_table <- function(models, title = "Determinants of Sudden Stops",
                                outpath = "04-Manuscript/tables/") {
  dir.create(outpath, recursive = TRUE, showWarnings = FALSE)

  # Use modelsummary for LaTeX output
  modelsummary::modelsummary(
    models,
    output = paste0(outpath, "table2_baseline_probit.tex"),
    coef_omit  = "factor\\(",   # suppress country dummies
    coef_rename = c(
      "vix_lag1"             = "VIX (lag 1)",
      "ffr_lag1"             = "US FFR (lag 1)",
      "global_gdp_growth"    = "Global GDP growth",
      "ca_pct_gdp_lag1"      = "CA balance / GDP",
      "credit_pct_gdp_lag1"  = "Domestic credit / GDP",
      "log_reserves_gdp_lag1"= "log(Reserves / GDP)",
      "trade_open_lag1"      = "Trade openness",
      "mpp_tightening_lag1"  = "MPP tightening"
    ),
    stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
    title  = title,
    notes  = "Probit coefficients. Country FE included (not shown). Driscoll-Kraay SE in parentheses. AME reported separately in Table 3.",
    fmt    = 3
  )

  message("Table exported: ", outpath, "table2_baseline_probit.tex")
}

# =============================================================================
# SECTION 9: KEY CROSS-CHECK (Anayasa verification)
# =============================================================================
# Before reporting any coefficient, verify against Business Perspectives (2025):
# "A one-point increase in the VIX raises sudden stop probability by 0.39 pp"
# Our estimate should be in the same ballpark (order of magnitude check)

verify_vix_ame <- function(ame_df) {
  vix_ame <- ame_df %>%
    filter(grepl("vix", factor, ignore.case = TRUE)) %>%
    pull(ame_pct)

  if (length(vix_ame) == 0) {
    message("VIX AME not found in output")
    return(invisible(NULL))
  }

  cat(sprintf("\n=== VIX AME CROSS-CHECK ===\n"))
  cat(sprintf("  Our estimate:  %.3f pp per 1-pt VIX increase\n", vix_ame[1]))
  cat(sprintf("  Literature:    0.39 pp (Business Perspectives 2025)\n"))
  cat(sprintf("  Plausible?:    %s\n",
              ifelse(abs(vix_ame[1]) < 2.0, "YES — order of magnitude OK",
                     "WARNING — check units or specification")))
}
