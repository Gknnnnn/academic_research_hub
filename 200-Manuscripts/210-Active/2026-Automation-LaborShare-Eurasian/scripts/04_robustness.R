# =============================================================================
# Automation, Economic Complexity & Labor Share in Eurasian Economies
# Script 04: Robustness Checks
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-24
# =============================================================================

library(dplyr); library(readr); library(plm); library(lmtest); library(sandwich)

data_dir <- here::here("data")
panel_files <- list.files(data_dir, pattern = "panel_automation_eurasian_.*\\.csv", full.names = TRUE)
panel <- read_csv(panel_files[length(panel_files)], show_col_types = FALSE) |>
  arrange(iso3c, year)
pdata <- pdata.frame(panel, index = c("iso3c", "year"))

# =============================================================================
# R1. Alternative TFP proxy: ICT goods imports (% total imports)
# =============================================================================
message("R1: Alternative TFP proxy — ICT import intensity")

if ("ict_import" %in% names(panel)) {
  r1 <- plm(labor_share ~ log(pmax(ict_import, 0.01)) + capital_intensity +
              ln_gdppc + trade_open + ln_hc,
            data = pdata, model = "within", effect = "twoways")
  message("ICT imports coef: ", round(coef(r1)["log(pmax(ict_import, 0.01))"], 4))
} else {
  message("⚠️  ict_import not in panel — skip R1 until WDI download complete")
}

# =============================================================================
# R2. PWT labor share as dependent variable (instead of ILO)
# =============================================================================
message("\nR2: PWT labsh as DV cross-check")

if ("labsh" %in% names(panel)) {
  r2 <- plm(labsh ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
            data = pdata, model = "within", effect = "twoways")
  message("PWT labsh ~ ln_tfp coef: ", round(coef(r2)["ln_tfp"], 4))
  message("Compare to ILO labor_share result from script 03")
} else {
  message("⚠️  PWT labsh not in panel")
}

# =============================================================================
# R3. Sub-period analysis: Pre-2010 vs Post-2010
# =============================================================================
message("\nR3: Sub-period analysis")

pdata_pre  <- pdata.frame(panel |> filter(year <= 2010), index = c("iso3c","year"))
pdata_post <- pdata.frame(panel |> filter(year >  2010), index = c("iso3c","year"))

tryCatch({
  r3a <- plm(labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
             data = pdata_pre, model = "within", effect = "twoways")
  r3b <- plm(labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
             data = pdata_post, model = "within", effect = "twoways")
  message("Pre-2010  TFP coef: ", round(coef(r3a)["ln_tfp"], 4))
  message("Post-2010 TFP coef: ", round(coef(r3b)["ln_tfp"], 4))
}, error = function(e) message("Sub-period error: ", e$message))

# =============================================================================
# R4. Exclude Russia & Türkiye (dominant economies)
# =============================================================================
message("\nR4: Exclude Russia + Türkiye")

panel_excl <- panel |> filter(!iso3c %in% c("RUS", "TUR"))
pdata_excl <- pdata.frame(panel_excl, index = c("iso3c","year"))

tryCatch({
  r4 <- plm(labor_share ~ ln_tfp + capital_intensity + ln_gdppc + trade_open,
            data = pdata_excl, model = "within", effect = "twoways")
  message("Excl. RUS+TUR TFP coef: ", round(coef(r4)["ln_tfp"], 4))
}, error = function(e) message("R4 error: ", e$message))

# =============================================================================
# R5. System-GMM (Blundell-Bond) — endogeneity of TFP
# =============================================================================
message("\nR5: System-GMM (Blundell-Bond)")

tryCatch({
  if (requireNamespace("pgmm", quietly = TRUE)) {
    library(pgmm)
    r5 <- pgmm(
      labor_share ~ lag(labor_share, 1) + ln_tfp + capital_intensity +
        ln_gdppc + trade_open |
        lag(labor_share, 2:4) + lag(ln_tfp, 2:3),
      data   = pdata,
      effect = "twoways",
      model  = "twosteps",
      transformation = "ld"  # Blundell-Bond
    )
    message("System-GMM TFP coef: ", round(coef(r5)["ln_tfp"], 4))
    # Sargan/Hansen test
    message("Hansen J-test: ", round(summary(r5)$sargan$p.value, 4))
  } else {
    message("pgmm not installed — install.packages('pgmm')")
  }
}, error = function(e) message("GMM error: ", e$message))

message("\n✅ Script 04 complete — robustness suite done")
message("Next: 05_tables_figures.R → then draft QMD")
