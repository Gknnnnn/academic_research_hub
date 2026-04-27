# ============================================================
# 07_causality.R
# LCF Turkey Bootstrap ARDL — Toda-Yamamoto Causality
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-26
# ============================================================
# Method: Toda-Yamamoto (1995) modified Wald test
# Handles I(1) and cointegrated series without pre-testing bias
# VAR(p + d_max) where p = optimal VAR lag, d_max = max integration order
# d_max = 1 (all variables I(1))
# ============================================================

library(tidyverse)
library(vars)       # VAR, causality
library(aod)        # wald.test

# ============================================================
# LOAD DATA
# ============================================================
panel_file <- list.files("data", pattern = "turkey_lcf_panel_", full.names = TRUE) |>
  sort() |> tail(1)
panel <- read_csv(panel_file, show_col_types = FALSE)

df <- panel |>
  dplyr::select(year, lnLCF, lnGDP, lnREN, lnTrade) |>  # drop lnGDP2 for VAR causality
  drop_na() |>
  arrange(year)

cat("Toda-Yamamoto sample:", min(df$year), "–", max(df$year), "| T =", nrow(df), "\n\n")

# ============================================================
# 1. OPTIMAL VAR LAG SELECTION
# ============================================================
cat("=== VAR LAG SELECTION ===\n")

var_data <- df |> dplyr::select(lnLCF, lnGDP, lnREN, lnTrade) |> as.matrix()

var_select <- VARselect(var_data, lag.max = 4, type = "const")
cat("Lag order criteria:\n")
print(var_select$criteria)

# With T=27 and k=4, AIC may overfit (VAR(4) → 1 df; VAR(3) → 5 df)
# Cap at p=2 to ensure minimum 15 residual df (T - p - k*p - 1 > 10)
p_aic <- var_select$selection["AIC(n)"]
p_sc  <- var_select$selection["SC(n)"]
p_opt <- min(p_aic, 2)  # small-T safeguard: max lag = 2
cat("\nAIC-selected p:", p_aic, "| SC-selected p:", p_sc,
    "| Applied p (small-T cap):", p_opt, "\n")
cat("Toda-Yamamoto VAR order: p + d_max =", p_opt + 1, "(d_max = 1 since all I(1))\n\n")

# ============================================================
# 2. ESTIMATE VAR(p + d_max)
# ============================================================
cat("=== VAR(", p_opt + 1, ") ESTIMATION ===\n", sep = "")

var_ty <- VAR(var_data, p = p_opt + 1, type = "const")
cat("VAR summary (equation for lnLCF):\n")
print(summary(var_ty$varresult$lnLCF))

# ============================================================
# 3. TODA-YAMAMOTO MODIFIED WALD TESTS
# ============================================================
# The TY test: restrict only first p lags; ignore d_max extra lags
# Wald statistic is asymptotically χ²(p × k) distributed

cat("\n=== TODA-YAMAMOTO CAUSALITY RESULTS ===\n")
cat("H0: X does not Granger-cause Y\n\n")

n_vars <- ncol(var_data)
var_names <- colnames(var_data)

ty_results <- tibble()

for (cause in var_names) {
  for (effect in var_names) {
    if (cause == effect) next

    tryCatch({
      # Get coefficient indices for the causing variable (first p lags only)
      effect_eq <- var_ty$varresult[[effect]]
      coef_names <- names(coef(effect_eq))

      # Identify lags of 'cause' variable up to lag p (not p+1)
      cause_lag_pattern <- paste0("^", cause, "\\.l[1-", p_opt, "]$")
      restrict_idx <- which(grepl(cause_lag_pattern, coef_names))

      if (length(restrict_idx) == 0) {
        cat(cause, "→", effect, "| No coefficient indices found\n")
        next
      }

      # Wald test on first p lags
      wald <- aod::wald.test(
        b     = coef(effect_eq),
        Sigma = vcov(effect_eq),
        Terms = restrict_idx
      )

      w_stat <- wald$result$chi2["chi2"]
      w_df   <- wald$result$chi2["df"]
      w_p    <- wald$result$chi2["P"]

      cat(cause, "→", effect, "| χ²(", w_df, ")=", round(w_stat, 4),
          "| p =", round(w_p, 4),
          "|", ifelse(w_p < 0.01, "***",
                      ifelse(w_p < 0.05, "**",
                             ifelse(w_p < 0.10, "*", "NS"))), "\n")

      ty_results <- bind_rows(ty_results, tibble(
        Cause   = cause,
        Effect  = effect,
        Chi2    = round(w_stat, 4),
        df      = w_df,
        p_value = round(w_p, 4),
        Sig     = ifelse(w_p < 0.01, "***",
                         ifelse(w_p < 0.05, "**",
                                ifelse(w_p < 0.10, "*", "NS")))
      ))
    }, error = function(e) {
      cat(cause, "→", effect, "| Error:", conditionMessage(e), "\n")
    })
  }
}

cat("\nToda-Yamamoto Results Table:\n")
print(ty_results)

# Save
write_csv(ty_results, paste0("data/toda_yamamoto_results_", format(Sys.Date(), "%Y%m%d"), ".csv"))
cat("\n✅ Toda-Yamamoto results saved.\n")

# ============================================================
# 4. CAUSALITY DIRECTION SUMMARY
# ============================================================
cat("\n=== CAUSALITY DIRECTION SUMMARY ===\n")

sig_pairs <- ty_results |> filter(p_value < 0.10)
for (i in seq_len(nrow(sig_pairs))) {
  cat("✓", sig_pairs$Cause[i], "→", sig_pairs$Effect[i],
      "(", sig_pairs$Sig[i], ")\n")
}

if (nrow(sig_pairs) == 0) cat("No significant causal relationships at 10% level.\n")

# Check for feedback (bidirectional causality)
bidir <- sig_pairs |>
  inner_join(sig_pairs, by = c("Cause" = "Effect", "Effect" = "Cause")) |>
  filter(Cause < Effect)

if (nrow(bidir) > 0) {
  cat("\nBidirectional causality detected:\n")
  for (i in seq_len(nrow(bidir))) {
    cat("↔", bidir$Cause[i], "↔", bidir$Effect[i], "\n")
  }
}

cat("\n⚠️ GRANGER CAUSAL LANGUAGE RULE (ANAYASA):\n")
cat("NEVER: 'Granger causality tests reject reverse causality'\n")
cat("ALWAYS: 'indicate an absence of reverse predictive precedence,\n")
cat("         supporting X as an exogenous predictor. This constitutes\n")
cat("         predictive rather than structural causality (Granger, 1969).'\n")

cat("\n=== 07_causality.R COMPLETE ===\n")
cat("Pipeline complete. Ready to fill manuscript tables in 04-Manuscript/main.qmd\n")
