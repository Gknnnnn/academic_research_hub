# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — Main Estimation
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-27
# ⚠️ Requires: 02-Data/clean/panel_chronic_inf_trilemma_merged.csv
#              (trilemma download + merge via 01_data_assembly.R)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(plm)
  library(lmtest); library(sandwich); library(fixest)
  library(AER)   # for ivreg 2SLS
})

panel <- read_csv("02-Data/clean/panel_chronic_inf_trilemma_merged.csv",
                  show_col_types = FALSE)

pdata <- pdata.frame(panel, index = c("iso3c","year"))

# Winsorise CPI at 99th percentile to reduce outlier influence (Angola, Congo)
q99 <- quantile(panel$cpi, 0.99, na.rm = TRUE)
panel <- panel |> mutate(cpi_w = pmin(cpi, q99))
cat(sprintf("CPI Winsorised at 99th pct: %.1f%%\n", q99))

# Log CPI for level regression (add 1 to handle near-zero values)
panel <- panel |> mutate(ln_cpi = log(pmax(cpi, 0.1) + 1))

# =============================================================================
# MODEL A — Random Effects Probit (binary DV: chronic10)
# =============================================================================
cat("\n=== MODEL A: RE Probit — Chronic Inflation Probability ===\n")

# A1: Baseline — trilemma indices only
a1 <- glm(chronic10 ~ MII + ERS + KAOPEN + factor(year),
          data   = panel[!is.na(panel$MII),],
          family = binomial(link = "probit"))
cat("A1 (Probit, no controls):\n")
cat(sprintf("  MII:    coef = %.4f, p = %.4f\n",
            coef(a1)["MII"], coef(summary(a1))["MII","Pr(>|z|)"]))
cat(sprintf("  ERS:    coef = %.4f, p = %.4f\n",
            coef(a1)["ERS"], coef(summary(a1))["ERS","Pr(>|z|)"]))
cat(sprintf("  KAOPEN: coef = %.4f, p = %.4f\n",
            coef(a1)["KAOPEN"], coef(summary(a1))["KAOPEN","Pr(>|z|)"]))

# A2: Full controls
a2 <- glm(chronic10 ~ MII + ERS + KAOPEN +
            gdp_growth + trade_open + broad_money + fdi +
            factor(year),
          data   = panel[!is.na(panel$MII) & !is.na(panel$gdp_growth),],
          family = binomial(link = "probit"))

# A3: + Interaction MII × KAOPEN
a3 <- glm(chronic10 ~ MII + ERS + KAOPEN + I(MII*KAOPEN) +
            gdp_growth + trade_open + broad_money + fdi +
            factor(year),
          data   = panel[!is.na(panel$MII) & !is.na(panel$gdp_growth),],
          family = binomial(link = "probit"))

cat("\nA3 Interaction (MII × KAOPEN):\n")
cat(sprintf("  MII×KAOPEN: coef = %.4f, p = %.4f\n",
            coef(a3)["I(MII * KAOPEN)"],
            coef(summary(a3))["I(MII * KAOPEN)","Pr(>|z|)"]))

# Marginal effects at means (for economic interpretation)
marg_a2 <- function(mod, var) {
  b    <- coef(mod)[var]
  xb   <- predict(mod, type = "link")
  dmfx <- mean(dnorm(xb), na.rm = TRUE) * b
  cat(sprintf("  APE (%s): %.4f pp change in P(chronic)\n",
              var, dmfx * 100))
}
cat("\nAverage Partial Effects (Model A2):\n")
for (v in c("MII","ERS","KAOPEN")) marg_a2(a2, v)

# =============================================================================
# MODEL B — System-GMM (Blundell-Bond), inflation level
# =============================================================================
cat("\n=== MODEL B: System-GMM — Inflation Level ===\n")
cat("⚠️  For System-GMM: use Stata xtabond2 or R pgmm()\n")

# pgmm approximation (2-step, Windmeijer corrected)
tryCatch({
  b1 <- pgmm(
    ln_cpi ~ lag(ln_cpi,1) + MII + ERS + KAOPEN +
             gdp_growth + trade_open + broad_money |
             lag(ln_cpi, 2:4) + lag(MII,2:3) + lag(ERS,2:3),
    data      = pdata.frame(panel[!is.na(panel$MII),], index=c("iso3c","year")),
    effect    = "twoways",
    model     = "twosteps",
    transformation = "ld"  # system GMM
  )
  cat("System-GMM converged:\n")
  print(summary(b1, robust = TRUE))
}, error = function(e) {
  cat(sprintf("pgmm error: %s\n", conditionMessage(e)))
  cat("→ Fall back to Stata xtabond2 for production estimates\n")
})

# =============================================================================
# MODEL C — FE with Driscoll-Kraay SE (cross-section + serial correlation robust)
# =============================================================================
cat("\n=== MODEL C: FE + Driscoll-Kraay SE ===\n")

c1 <- feols(ln_cpi ~ MII + ERS + KAOPEN +
              gdp_growth + trade_open + broad_money + fdi |
              iso3c + year,
            data    = panel[!is.na(panel$MII),],
            cluster = ~iso3c)    # switch to vcov_NW() for D-K

cat("FE (two-way FE, clustered SE):\n")
print(etable(c1, digits = 3))

# Driscoll-Kraay via sandwich
c1_lm <- plm(ln_cpi ~ MII + ERS + KAOPEN +
               gdp_growth + trade_open + broad_money + fdi,
             data   = pdata.frame(panel[!is.na(panel$MII),], index=c("iso3c","year")),
             model  = "within", effect = "twoways")
dk_se <- coeftest(c1_lm, vcov = vcovSCC(c1_lm, type = "HC3", maxlag = 4))
cat("\nDriscoll-Kraay SE (maxlag=4):\n")
print(dk_se[c("MII","ERS","KAOPEN"),])

# =============================================================================
# MODEL D — 2SLS (IV for trilemma endogeneity)
# Instrument: Shambaugh (2004) base country assignment
# ⚠️ Requires: external base-country-peg dataset
# =============================================================================
cat("\n=== MODEL D: 2SLS — Trilemma endogeneity ===\n")
cat("⚠️  BLOCKER: Shambaugh (2004) base country peg dataset required\n")
cat("   Download: https://scholar.harvard.edu/shambaugh/data-code\n")
cat("   Instrument: ERS_hat = f(peg_to_base_country × base_ERS)\n")
cat("   Once available: ivreg(chronic10 ~ MII + ERS + controls | base_ERS + ..., data=panel)\n")

# =============================================================================
# SAVE RESULTS SUMMARY
# =============================================================================
cat("\n=== Saving coefficient tables ===\n")
dir.create("06-Results/tables", recursive=TRUE, showWarnings=FALSE)

# Export Model A summary
sink("06-Results/tables/modelA_probit_summary.txt")
cat("=== MODEL A: RE Probit Results ===\n\n")
cat("A1: Baseline\n"); print(summary(a1))
cat("\nA2: Full controls\n"); print(summary(a2))
cat("\nA3: + MII×KAOPEN interaction\n"); print(summary(a3))
sink()
cat("✅ Saved: 06-Results/tables/modelA_probit_summary.txt\n")

cat("\n=== 03_main_models.R COMPLETE ===\n")
cat("Next: run 04_robustness.R after trilemma data is merged\n")
