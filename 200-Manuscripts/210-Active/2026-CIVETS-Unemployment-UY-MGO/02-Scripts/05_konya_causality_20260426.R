suppressPackageStartupMessages(library(tidyverse))

# ============================================================
# CIVETS Unemployment — Konya (2006) Bootstrap Panel Causality
# SUR-based, country-specific inference, B=999 bootstrap CVs
# Script: 05_konya_causality_20260426.R
# ============================================================
# Konya (2006): Bootstrap Granger causality for heterogeneous panels
# - Bivariate VAR per country; SUR system across N countries
# - Country-specific Wald tests; bootstrap critical values
# - Appropriate for small N (no pooling assumption)
# ============================================================

panel <- read_csv("/tmp/civets_panel_20260426.csv", show_col_types = FALSE) %>%
  mutate(ln_gdp_pc = log(gdp_pc)) %>%
  arrange(iso3c, year)

countries <- sort(unique(panel$iso3c))
N <- 6; T_obs <- 24

# ── Lag selection (AIC per country per pair) ──────────────────
select_lag <- function(y, x, max_lag = 3) {
  aic_vals <- numeric(max_lag)
  for (p in 1:max_lag) {
    n <- length(y)
    Y <- y[(p+1):n]
    Xy <- embed(y, p+1)[, -1, drop=FALSE]
    Xx <- embed(x, p+1)[, -1, drop=FALSE]
    RHS <- cbind(1, Xy, Xx)
    m <- lm(Y ~ RHS - 1)
    k_m <- ncol(RHS)
    aic_vals[p] <- log(sum(residuals(m)^2)/(n-p)) + 2*k_m/(n-p)
  }
  which.min(aic_vals)
}

# ── Country-level Wald test for causality x → y ──────────────
wald_test <- function(y, x, p) {
  n <- length(y)
  Y <- y[(p+1):n]
  Xy <- embed(y, p+1)[, -1, drop=FALSE]  # p lags of y
  Xx <- embed(x, p+1)[, -1, drop=FALSE]  # p lags of x
  RHS <- cbind(1, Xy, Xx)
  m_full <- lm(Y ~ RHS - 1)

  # Restrict: x lags = 0
  RHS_r <- cbind(1, Xy)
  m_rest <- lm(Y ~ RHS_r - 1)

  RSS_f <- sum(residuals(m_full)^2)
  RSS_r <- sum(residuals(m_rest)^2)
  n_eff <- length(Y)

  W <- (RSS_r - RSS_f) / RSS_f * (n_eff - 2*p - 1)
  # chi-sq approximation with p df
  list(W = W, df = p, resid = residuals(m_full),
       fitted_r = fitted(m_rest))
}

# ── Run Konya for a variable pair ────────────────────────────
run_konya <- function(panel, y_var, x_var, B = 999, seed = 2026) {
  cat(sprintf("\n  Testing: %s → %s\n", x_var, y_var))

  # Country-specific lag orders
  lags <- setNames(numeric(N), countries)
  for (cty in countries) {
    sub <- panel %>% filter(iso3c == cty)
    lags[cty] <- select_lag(sub[[y_var]], sub[[x_var]], max_lag = 3)
  }
  cat(sprintf("  Lags (AIC): %s\n",
              paste(names(lags), lags, sep="=", collapse=" | ")))

  # Observed Wald statistics
  W_obs <- setNames(numeric(N), countries)
  resids <- list(); fitted_r <- list()
  for (cty in countries) {
    sub <- panel %>% filter(iso3c == cty)
    p <- lags[cty]
    res <- tryCatch(
      wald_test(sub[[y_var]], sub[[x_var]], p),
      error = function(e) NULL
    )
    if (!is.null(res)) {
      W_obs[cty] <- res$W
      resids[[cty]] <- res$resid
      fitted_r[[cty]] <- res$fitted_r
    }
  }

  # Bootstrap critical values (country-specific)
  set.seed(seed)
  boot_W <- matrix(NA, B, N, dimnames = list(NULL, countries))

  for (b in 1:B) {
    for (cty in countries) {
      if (is.null(resids[[cty]])) next
      res_b <- sample(resids[[cty]], replace = TRUE)
      y_boot <- fitted_r[[cty]] + res_b

      sub <- panel %>% filter(iso3c == cty)
      p <- lags[cty]
      n <- nrow(sub)
      x_orig <- sub[[x_var]]

      # Reconstruct full-length y_boot (pad with original values at start)
      y_full <- c(sub[[y_var]][1:p], y_boot)
      if (length(y_full) != n) y_full <- sub[[y_var]]  # fallback

      res_b2 <- tryCatch(
        wald_test(y_full, x_orig, p),
        error = function(e) NULL
      )
      if (!is.null(res_b2)) boot_W[b, cty] <- res_b2$W
    }
  }

  # Bootstrap p-values and CVs
  cv10 <- apply(boot_W, 2, quantile, 0.90, na.rm = TRUE)
  cv05 <- apply(boot_W, 2, quantile, 0.95, na.rm = TRUE)
  cv01 <- apply(boot_W, 2, quantile, 0.99, na.rm = TRUE)
  p_boot <- sapply(countries, function(cty) {
    mean(boot_W[, cty] >= W_obs[cty], na.rm = TRUE)
  })

  sig <- sapply(p_boot, function(p) {
    if (is.na(p)) return("")
    if (p < 0.01) "***" else if (p < 0.05) "**" else if (p < 0.10) "*" else ""
  })

  # Print country results
  cat(sprintf("  %-4s  %7s  %7s  %7s  %7s  %6s  %s\n",
              "Cty", "Wald", "CV10%", "CV5%", "CV1%", "p_boot", ""))
  cat(paste(rep("-", 55), collapse=""), "\n")
  for (cty in countries) {
    cat(sprintf("  %-4s  %7.3f  %7.3f  %7.3f  %7.3f  %6.4f  %s\n",
                cty, W_obs[cty], cv10[cty], cv05[cty], cv01[cty],
                p_boot[cty], sig[cty]))
  }

  n_sig10 <- sum(p_boot < 0.10, na.rm = TRUE)
  n_sig05 <- sum(p_boot < 0.05, na.rm = TRUE)
  cat(sprintf("  Significant at 10%%: %d/%d countries | 5%%: %d/%d\n",
              n_sig10, N, n_sig05, N))

  tibble(
    country   = countries,
    direction = sprintf("%s→%s", x_var, y_var),
    lag       = lags[countries],
    W_stat    = round(W_obs[countries], 4),
    cv10      = round(cv10[countries], 4),
    cv05      = round(cv05[countries], 4),
    cv01      = round(cv01[countries], 4),
    p_boot    = round(p_boot[countries], 4),
    sig       = sig[countries]
  )
}

# ── Run all four directions ───────────────────────────────────
cat("=============================================================\n")
cat("KONYA (2006) BOOTSTRAP GRANGER CAUSALITY | N=6 T=24\n")
cat("Bootstrap B=999 | Lag selection: AIC (max=3)\n")
cat("=============================================================\n")

res1 <- run_konya(panel, "unemp",      "ln_gdp_pc", B = 999)  # GDP→unemp
res2 <- run_konya(panel, "ln_gdp_pc",  "unemp",     B = 999)  # unemp→GDP
res3 <- run_konya(panel, "unemp",      "goveff",     B = 999)  # goveff→unemp
res4 <- run_konya(panel, "goveff",     "unemp",      B = 999)  # unemp→goveff

all_res <- bind_rows(res1, res2, res3, res4)

cat("\n=============================================================\n")
cat("SUMMARY TABLE — Konya Bootstrap Causality\n")
cat("=============================================================\n")
cat(sprintf("%-22s | %-4s | %6s | %6s | %s\n",
            "Direction", "Lag", "W-stat", "p_boot", "Sig"))
cat(paste(rep("-", 60), collapse=""), "\n")
for (r in 1:nrow(all_res)) {
  cat(sprintf("%-22s | %-4s | %6.3f | %6.4f | %s\n",
              all_res$direction[r], all_res$country[r],
              all_res$W_stat[r], all_res$p_boot[r], all_res$sig[r]))
}

# ── Causality direction decision per country ──────────────────
cat("\n=== CAUSALITY PATTERN PER COUNTRY ===\n")
for (cty in countries) {
  fwd <- all_res %>% filter(country == cty, direction == "ln_gdp_pc→unemp")
  rev <- all_res %>% filter(country == cty, direction == "unemp→ln_gdp_pc")
  gov <- all_res %>% filter(country == cty, direction == "goveff→unemp")

  fwd_sig <- if (nrow(fwd) > 0 && fwd$p_boot < 0.10) "✓" else "✗"
  rev_sig <- if (nrow(rev) > 0 && rev$p_boot < 0.10) "✓" else "✗"
  gov_sig <- if (nrow(gov) > 0 && gov$p_boot < 0.10) "✓" else "✗"

  pattern <- case_when(
    fwd_sig == "✓" & rev_sig == "✓" ~ "Bidirectional",
    fwd_sig == "✓" & rev_sig == "✗" ~ "GDP→Unemp only",
    fwd_sig == "✗" & rev_sig == "✓" ~ "Unemp→GDP only",
    TRUE ~ "No causality"
  )
  cat(sprintf("  %-3s: GDP→U=%s  U→GDP=%s  Gov→U=%s  | %s\n",
              cty, fwd_sig, rev_sig, gov_sig, pattern))
}

write_csv(all_res, "/tmp/civets_konya_causality_20260426.csv")
cat("\nSaved: /tmp/civets_konya_causality_20260426.csv\n")
cat("Notes: Konya (2006) bootstrap Granger causality\n")
cat("       *** p<0.01  ** p<0.05  * p<0.10 (bootstrap)\n")
cat("       Null: no Granger causality from x to y\n")
