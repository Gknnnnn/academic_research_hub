## CIVETS Unemployment — Stage 4: Konya (2006) Bootstrap Granger Causality
## Author: Res. Asst. Dr. M. Gökhan Özdemir
## Date: 2026-04-28
##
## Method: Konya (2006) bootstrap Granger causality
## Country-level OLS Wald tests + joint residual bootstrap (CSD-robust)
## Preferred over Dumitrescu-Hurlin (2012) for N=6 < 30 (Konya 2006, p.980)
##
## Reference: Konya (2006), Economic Modelling 23, 978-992
## DOI: 10.1016/j.econmod.2005.05.004

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(car)    # linearHypothesis for Wald test
})

set.seed(2026)

# ── 1. Load ──────────────────────────────────────────────────────────────────
df <- read_csv(
  "../01-Data/raw/civets_panel_full_20260428.csv",
  show_col_types = FALSE
) %>%
  arrange(iso3c, year)

countries <- unique(df$iso3c)
N <- length(countries)

cat("KONYA (2006) BOOTSTRAP GRANGER CAUSALITY\n")
cat("Method: OLS Wald statistics + joint residual bootstrap (B=499)\n")
cat("N=6 CIVETS, lags=2, cross-section dependence preserved\n\n")

# ── 2. Build lagged data for one country ─────────────────────────────────────
build_country_data <- function(panel_df, cty, dep, cause_var, lags) {
  d <- filter(panel_df, iso3c == cty) %>% arrange(year)
  y <- d[[dep]]
  x <- d[[cause_var]]
  T_i <- length(y)

  lag_df <- data.frame(y_dep = y, x_cause = x, year = d$year)
  for (l in seq_len(lags)) {
    lag_df[[paste0("y_l", l)]] <- c(rep(NA, l), y[seq_len(T_i - l)])
    lag_df[[paste0("x_l", l)]] <- c(rep(NA, l), x[seq_len(T_i - l)])
  }
  lag_df[complete.cases(lag_df), ]
}

# ── 3. Konya test function ────────────────────────────────────────────────────
konya_test <- function(panel_df, dep, cause_var, lags = 2, B = 499) {
  # Lags variable names
  y_lag_names <- paste0("y_l", seq_len(lags))
  x_lag_names <- paste0("x_l", seq_len(lags))

  # Build country data
  country_data <- lapply(countries, function(cty) {
    build_country_data(panel_df, cty, dep, cause_var, lags)
  })
  names(country_data) <- countries

  # Unrestricted and restricted OLS per country
  fit_unrestricted <- lapply(countries, function(cty) {
    d <- country_data[[cty]]
    formula_u <- as.formula(paste("y_dep ~",
      paste(c(y_lag_names, x_lag_names), collapse = " + ")))
    lm(formula_u, data = d)
  })
  names(fit_unrestricted) <- countries

  fit_restricted <- lapply(countries, function(cty) {
    d <- country_data[[cty]]
    formula_r <- as.formula(paste("y_dep ~",
      paste(y_lag_names, collapse = " + ")))
    lm(formula_r, data = d)
  })
  names(fit_restricted) <- countries

  # Observed Wald statistics (F-test for joint significance of x lags)
  obs_wald <- sapply(countries, function(cty) {
    fit_u <- fit_unrestricted[[cty]]
    # F-test: H0: x_l1 = x_l2 = 0
    restrictions <- paste(x_lag_names, "= 0")
    tryCatch({
      ht <- linearHypothesis(fit_u, restrictions, test = "Chisq")
      ht$Chisq[2]   # Chi-sq statistic
    }, error = function(e) NA)
  })

  # Residual matrices from restricted model (for bootstrap)
  # Align residuals across countries (same length T_eff)
  T_eff_vec <- sapply(countries, function(cty) length(residuals(fit_restricted[[cty]])))
  T_min <- min(T_eff_vec)

  resid_mat <- do.call(cbind, lapply(countries, function(cty) {
    r <- residuals(fit_restricted[[cty]])
    tail(r, T_min)   # use last T_min residuals (aligned)
  }))
  colnames(resid_mat) <- countries

  fitted_restricted <- lapply(countries, function(cty) {
    f <- fitted(fit_restricted[[cty]])
    tail(f, T_min)
  })
  names(fitted_restricted) <- countries

  # Bootstrap
  boot_wald <- matrix(NA_real_, B, N, dimnames = list(NULL, countries))

  for (b in seq_len(B)) {
    # Resample rows jointly → preserves CSD
    idx <- sample(seq_len(T_min), T_min, replace = TRUE)
    boot_resid <- resid_mat[idx, , drop = FALSE]

    # Generate bootstrap y under H0 (restricted model)
    boot_wald_b <- sapply(countries, function(cty) {
      d <- tail(country_data[[cty]], T_min)
      y_boot <- fitted_restricted[[cty]] + boot_resid[, cty]
      d$y_dep <- y_boot

      tryCatch({
        fit_u_b <- lm(as.formula(paste("y_dep ~",
          paste(c(y_lag_names, x_lag_names), collapse = " + "))), data = d)
        ht <- linearHypothesis(fit_u_b, paste(x_lag_names, "= 0"), test = "Chisq")
        ht$Chisq[2]
      }, error = function(e) NA)
    })
    boot_wald[b, ] <- boot_wald_b
  }

  # Bootstrap p-values (right-tail: large Wald → reject H0)
  pvals <- sapply(countries, function(cty) {
    mean(boot_wald[, cty] >= obs_wald[cty], na.rm = TRUE)
  })

  list(wald = obs_wald, pval = pvals, ok = TRUE)
}

# ── 4. Run causality tests ────────────────────────────────────────────────────
test_pairs <- list(
  list(dep = "unemp",     cause = "gdp_growth", label = "gdp_growth → unemp"),
  list(dep = "unemp",     cause = "inflation",   label = "inflation  → unemp"),
  list(dep = "unemp",     cause = "fdi",         label = "fdi        → unemp"),
  list(dep = "unemp",     cause = "trade",       label = "trade      → unemp"),
  list(dep = "gdp_growth",cause = "unemp",       label = "unemp      → gdp_growth")
)

all_results <- list()
for (tp in test_pairs) {
  cat(sprintf("Testing: %-40s B=499...\n", tp$label))
  res <- konya_test(df, tp$dep, tp$cause, lags = 2, B = 499)
  all_results[[tp$label]] <- res
}

# ── 5. Report ─────────────────────────────────────────────────────────────────
cat("\n=======================================================\n")
cat("KONYA (2006) BOOTSTRAP GRANGER CAUSALITY — RESULTS\n")
cat("Chi-sq Wald statistic, bootstrap p-value (B=499)\n")
cat("H0: X does NOT Granger-cause Y in country i\n")
cat("=======================================================\n\n")

for (nm in names(all_results)) {
  res <- all_results[[nm]]
  cat(sprintf("Direction: %s\n", nm))
  cat(sprintf("  %-4s  %8s  %8s  %s\n", "Cty", "Wald χ²", "p(boot)", "Sig"))
  for (cty in countries) {
    w  <- res$wald[cty]
    pv <- res$pval[cty]
    sig <- if (!is.na(pv)) {
      ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**", ifelse(pv < 0.10, "*", "")))
    } else ""
    cat(sprintf("  %-4s  %8.4f  %8.4f  %s\n", cty,
                ifelse(is.na(w), 0, w), ifelse(is.na(pv), 1, pv), sig))
  }
  cat("\n")
}

# ── 6. Save ────────────────────────────────────────────────────────────────────
dir.create("../03-Output", showWarnings = FALSE)

results_df <- do.call(rbind, lapply(names(all_results), function(nm) {
  res <- all_results[[nm]]
  data.frame(
    direction = nm,
    country   = countries,
    wald_chi2 = as.numeric(res$wald),
    pval_boot = as.numeric(res$pval),
    lags      = 2L,
    B         = 499L,
    date_run  = "2026-04-28"
  )
}))

write_csv(results_df, "../03-Output/konya_causality_results_20260428.csv")
cat("Saved → 03-Output/konya_causality_results_20260428.csv\n\n")

# ── 7. Summary ────────────────────────────────────────────────────────────────
cat("=======================================================\n")
cat("CAUSALITY SUMMARY (p < 0.10)\n")
cat("=======================================================\n")
for (nm in names(all_results)) {
  res <- all_results[[nm]]
  sig_ctys <- countries[!is.na(res$pval) & res$pval < 0.10]
  cat(sprintf("%-42s %s\n", nm,
              ifelse(length(sig_ctys) > 0, paste(sig_ctys, collapse=", "),
                     "— none significant")))
}
cat("\nNote: Konya (2006) preferred over DH (2012) for N=6 < 30.\n")
cat("CSD preserved via joint row-resampling of restricted-model residuals.\n")
