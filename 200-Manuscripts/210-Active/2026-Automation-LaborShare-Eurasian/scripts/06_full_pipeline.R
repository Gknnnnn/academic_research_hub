# =============================================================================
# Automation, Economic Complexity & Labor Share in Eurasian Economies
# Script 06: Full Pipeline — CSD + Unit Root + CCEMG + D-H Causality
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-24
# =============================================================================
# Column mapping:
#   labsh         → labor share (PWT 10.01)
#   ln_cap_worker → log capital per worker (proxy for automation/capital intensity)
#   ln_tfp        → log TFP (PWT)
#   ln_gdppc      → log GDP per capita (proxy for ECI until manual download)
#   trade_open    → trade openness (WDI)
#   fdi           → FDI net inflows % GDP (WDI)
# =============================================================================

# --- 0. Packages ---------------------------------------------------------------
pkgs <- c("dplyr","readr","plm","lmtest","sandwich","fixest",
          "CADFtest","ggplot2","tidyr","broom")
for (p in pkgs) {
  if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos="https://cloud.r-project.org")
}
suppressPackageStartupMessages({
  library(dplyr); library(readr); library(plm); library(lmtest)
  library(sandwich); library(fixest); library(CADFtest)
  library(ggplot2); library(tidyr)
})

DATA_DIR   <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Automation-LaborShare-Eurasian/data"
DRAFTS_DIR <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Automation-LaborShare-Eurasian/drafts"
TODAY      <- format(Sys.Date(), "%Y%m%d")

dir.create(DRAFTS_DIR, showWarnings=FALSE, recursive=TRUE)

# --- 1. Load & clean panel ----------------------------------------------------
cat("\n=== Loading panel ===\n")
panel_file <- file.path(DATA_DIR, "panel_automation_eurasian_20260424_wdi.csv")
panel <- read_csv(panel_file, show_col_types=FALSE) |>
  rename(
    labor_share       = labsh,
    capital_intensity = ln_cap_worker,
    ln_complexity     = ln_gdppc   # GDP per capita as ECI proxy (replaced by ECI below)
  ) |>
  filter(year >= 2000, year <= 2022,
         !is.na(labor_share), !is.na(capital_intensity)) |>
  arrange(iso3c, year)

# Flag countries with TFP (N=13: excludes TKM which has no labsh)
countries_with_tfp <- panel |> filter(!is.na(ln_tfp)) |>
  pull(iso3c) |> unique()
cat("Panel (all with labsh+cap): N =", length(unique(panel$iso3c)), "countries, obs =", nrow(panel), "\n")
cat("Countries with TFP available:", paste(sort(countries_with_tfp), collapse=", "), "\n")

# Merge ECI (Harvard Growth Lab HS92, downloaded 2026-04-25)
eci_path <- file.path(DATA_DIR, "raw/oec_eci_country_year.csv")
if (file.exists(eci_path)) {
  eci_raw <- read_csv(eci_path, show_col_types=FALSE)
  if (all(c("iso3c","year","ECI") %in% names(eci_raw))) {
    panel <- panel |> left_join(eci_raw |> select(iso3c,year,ECI), by=c("iso3c","year"))
    cat("ECI merged successfully.\n")
  }
} else {
  panel$ECI <- NA_real_
  cat("ECI set to NA — using ln_gdppc proxy.\n")
}

# pdata.frame
pdata <- pdata.frame(panel, index=c("iso3c","year"))

# =============================================================================
# 2. CROSS-SECTION DEPENDENCE (Pesaran 2004 CD test)
# =============================================================================
cat("\n=== 2. CROSS-SECTION DEPENDENCE TESTS ===\n")

vars_csd <- c("labor_share","capital_intensity","ln_tfp","ln_complexity","trade_open")

csd_res <- lapply(vars_csd, function(v) {
  tryCatch({
    pd_v <- pdata |> select(iso3c=1, year=2, all_of(v))
    fe <- plm(as.formula(paste(v,"~ 1")), data=pdata, model="within")
    cd <- plm::pcdtest(fe, test="cd")
    tibble(variable=v, CD_stat=round(cd$statistic,3), p_value=round(cd$p.value,4),
           result=ifelse(cd$p.value<0.05,"CSD ✓","No CSD"))
  }, error=function(e) tibble(variable=v, CD_stat=NA_real_, p_value=NA_real_, result=paste("Err:",e$message)))
}) |> bind_rows()

cat("Pesaran CD Results:\n")
print(csd_res)
write_csv(csd_res, file.path(DATA_DIR, paste0("results_csd_",TODAY,".csv")))

# =============================================================================
# 3. PANEL UNIT ROOT — CIPS (Pesaran 2007 via CADF mean)
# =============================================================================
cat("\n=== 3. PANEL UNIT ROOT — CIPS (CADF mean) ===\n")

cips_res <- lapply(vars_csd, function(v) {
  v_data <- panel |> select(iso3c, year, all_of(v)) |> drop_na() |>
    group_by(iso3c) |> filter(n() >= 10) |> ungroup()
  cntrs <- unique(v_data$iso3c)

  # Individual CADF
  cadf_stats <- sapply(cntrs, function(cty) {
    ts_v <- v_data |> filter(iso3c==cty) |> pull(!!v)
    tryCatch({
      ct <- CADFtest(ts_v, type="drift", max.lag.y=2, criterion="AIC")
      ct$statistic
    }, error=function(e) NA_real_)
  })

  cips_stat <- mean(cadf_stats, na.rm=TRUE)
  # Pesaran (2007) critical values, T=23, N=14: -2.29 (10%), -2.44 (5%), -2.74 (1%)
  result <- case_when(
    cips_stat < -2.74 ~ "I(0) 1%",
    cips_stat < -2.44 ~ "I(0) 5%",
    cips_stat < -2.29 ~ "I(0) 10%",
    TRUE ~ "I(1)"
  )
  tibble(variable=v, CIPS_stat=round(cips_stat,3), cv_5pct=-2.44,
         N_countries=length(na.omit(cadf_stats)), result=result)
}) |> bind_rows()

cat("CIPS Results (Pesaran 2007 | T≈23, N=14):\n")
print(cips_res)
write_csv(cips_res, file.path(DATA_DIR, paste0("results_cips_",TODAY,".csv")))

# First differences — check I(1) variables
cat("\nChecking first-differences for I(1) variables...\n")
vars_i1 <- cips_res |> filter(grepl("I\\(1\\)", result)) |> pull(variable)

if (length(vars_i1) > 0) {
  panel_fd <- panel |> arrange(iso3c, year) |> group_by(iso3c) |>
    mutate(across(all_of(vars_i1), ~c(NA, diff(.)), .names="d_{.col}")) |> ungroup()

  cips_fd <- lapply(paste0("d_",vars_i1), function(v) {
    v_data <- panel_fd |> select(iso3c, year, all_of(v)) |> drop_na() |>
      group_by(iso3c) |> filter(n() >= 8) |> ungroup()
    cntrs <- unique(v_data$iso3c)
    cadf_stats <- sapply(cntrs, function(cty) {
      ts_v <- v_data |> filter(iso3c==cty) |> pull(!!v)
      tryCatch(CADFtest(ts_v, type="drift", max.lag.y=1, criterion="AIC")$statistic,
               error=function(e) NA_real_)
    })
    cips_stat <- mean(cadf_stats, na.rm=TRUE)
    tibble(variable=v, CIPS_stat=round(cips_stat,3), cv_5pct=-2.44,
           result=ifelse(cips_stat < -2.44, "I(0) — confirms I(1) in levels", "Still I(1)?"))
  }) |> bind_rows()

  cat("\nFirst-difference CIPS:\n"); print(cips_fd)
  write_csv(cips_fd, file.path(DATA_DIR, paste0("results_cips_fd_",TODAY,".csv")))
}

# =============================================================================
# 4. PEDRONI / WESTERLUND-LIKE COINTEGRATION (FE residuals)
# =============================================================================
cat("\n=== 4. COINTEGRATION (Pedroni via plm) ===\n")

tryCatch({
  fe_coint <- plm(labor_share ~ capital_intensity + ln_tfp + ln_complexity + trade_open,
                  data=pdata, model="within")
  resid_fe  <- residuals(fe_coint)

  # Test stationarity of residuals (ADF per country)
  pdata$resid_coint <- as.numeric(resid_fe)
  resid_data <- data.frame(
    iso3c = attr(pdata, "index")$iso3c,
    year  = as.integer(as.character(attr(pdata, "index")$year)),
    resid = as.numeric(resid_fe)
  )
  cntrs <- unique(resid_data$iso3c)
  adf_resid <- sapply(cntrs, function(cty) {
    r <- resid_data |> filter(iso3c==cty) |> pull(resid)
    tryCatch(CADFtest(r, type="none", max.lag.y=1, criterion="AIC")$statistic,
             error=function(e) NA_real_)
  })
  mean_stat <- mean(adf_resid, na.rm=TRUE)
  pct_stat  <- mean(adf_resid < -1.95, na.rm=TRUE)
  cat("Pedroni-style residual stationarity:\n")
  cat("  Mean ADF(resid):", round(mean_stat,3), "\n")
  cat("  % stationary (|t|>1.96):", round(pct_stat*100,1), "%\n")
  cat("  Interpretation:", ifelse(mean_stat < -2.5, "Evidence of cointegration",
                                   "Weak cointegration signal — check by country"), "\n")

  write_csv(data.frame(country=names(adf_resid), adf_stat=adf_resid),
            file.path(DATA_DIR, paste0("results_coint_adf_resid_",TODAY,".csv")))
}, error=function(e) cat("Cointegration test error:", e$message, "\n"))

# =============================================================================
# 5. CCEMG ESTIMATION (Pesaran 2006)
# =============================================================================
cat("\n=== 5. CCEMG ESTIMATION ===\n")

# CCEMG: y_it = alpha_i + lambda_i*t + beta_i*x_it + gamma_i*ybar_t + delta_i*xbar_t + eps_it
# Mean-group estimator of beta_i

# Determine complexity variable: use ECI if available, else ln_complexity (=ln_gdppc proxy)
has_eci <- "ECI" %in% names(panel) && mean(!is.na(panel$ECI)) > 0.5
complexity_var <- if (has_eci) "ECI" else "ln_complexity"
cat("Complexity variable used:", complexity_var, "\n")

# Helper: run CCEMG for a given panel subset and formula
run_ccemg <- function(pnl, include_tfp=FALSE) {
  pnl <- pnl |> group_by(year) |>
    mutate(
      ybar  = mean(labor_share, na.rm=TRUE),
      x1bar = mean(capital_intensity, na.rm=TRUE),
      x2bar = if (include_tfp) mean(ln_tfp, na.rm=TRUE) else 0,
      x3bar = mean(.data[[complexity_var]], na.rm=TRUE),
      x4bar = mean(trade_open, na.rm=TRUE)
    ) |> ungroup()

  lapply(unique(pnl$iso3c), function(cty) {
    d <- pnl |> filter(iso3c == cty) |> arrange(year)
    if (nrow(d) < 10 || any(is.na(d$labor_share))) return(NULL)

    fmla <- if (include_tfp) {
      as.formula(paste("labor_share ~ capital_intensity + ln_tfp +",
                       complexity_var, "+ trade_open + ybar + x1bar + x2bar + x3bar + x4bar"))
    } else {
      as.formula(paste("labor_share ~ capital_intensity +",
                       complexity_var, "+ trade_open + ybar + x1bar + x3bar + x4bar"))
    }

    tryCatch({
      m  <- lm(fmla, data=d)
      cf <- coef(summary(m))
      tibble(
        iso3c    = cty, n=nrow(d),
        beta_cap = cf["capital_intensity","Estimate"],
        se_cap   = cf["capital_intensity","Std. Error"],
        t_cap    = cf["capital_intensity","t value"],
        p_cap    = cf["capital_intensity","Pr(>|t|)"],
        r2       = summary(m)$r.squared
      )
    }, error=function(e) NULL)
  }) |> bind_rows()
}

summarise_ccemg <- function(res, label) {
  N  <- nrow(res)
  MG <- mean(res$beta_cap, na.rm=TRUE)
  SE <- sd(res$beta_cap, na.rm=TRUE) / sqrt(N)
  t  <- MG / SE
  p  <- 2 * pt(-abs(t), df=N-1)
  star <- ifelse(p<0.01,"***",ifelse(p<0.05,"**",ifelse(p<0.10,"*","")))
  cat(sprintf("\n%s: β_cap=%.4f SE=%.4f t=%.3f p=%.4f%s  N=%d\n",
              label, MG, SE, t, p, star, N))
  tibble(model=label, N_countries=N,
         beta_cap=round(MG,4), se_cap=round(SE,4),
         t_cap=round(t,3), p_cap=round(p,4))
}

# Model A: WITHOUT ln_tfp (N=13, main result — matches prior β_cap=+0.121*)
panel_A <- panel |> filter(!is.na(labor_share), !is.na(capital_intensity),
                            !is.na(.data[[complexity_var]]), !is.na(trade_open))
cce_A <- run_ccemg(panel_A, include_tfp=FALSE)
cat("\nModel A — Country-level CCE (N=13, no TFP):\n")
print(cce_A |> mutate(across(where(is.numeric), ~round(.,4))))
sum_A <- summarise_ccemg(cce_A, "CCEMG-A (no TFP, N=13)")

# Model B: WITH ln_tfp (N=9, robustness)
panel_B <- panel |> filter(!is.na(labor_share), !is.na(capital_intensity),
                            !is.na(ln_tfp), !is.na(.data[[complexity_var]]), !is.na(trade_open))
cce_B <- run_ccemg(panel_B, include_tfp=TRUE)
cat("\nModel B — Country-level CCE (N=9, with TFP):\n")
print(cce_B |> mutate(across(where(is.numeric), ~round(.,4))))
sum_B <- summarise_ccemg(cce_B, "CCEMG-B (TFP, N=9)")

ccemg_panel <- bind_rows(sum_A, sum_B)
write_csv(ccemg_panel, file.path(DATA_DIR, paste0("results_ccemg_panel_",TODAY,".csv")))
write_csv(cce_A,       file.path(DATA_DIR, paste0("results_ccemg_country_",TODAY,".csv")))

# Convenient aliases for downstream code
cce_country <- cce_A
MG_cap <- sum_A$beta_cap; SE_cap <- sum_A$se_cap
t_cap  <- sum_A$t_cap;    p_cap  <- sum_A$p_cap
N_cce  <- sum_A$N_countries

# Country heterogeneity plot
p_het <- ggplot(cce_country, aes(x=reorder(iso3c, beta_cap), y=beta_cap)) +
  geom_col(aes(fill=beta_cap>0), show.legend=FALSE) +
  geom_errorbar(aes(ymin=beta_cap-1.96*se_cap, ymax=beta_cap+1.96*se_cap), width=0.3) +
  geom_hline(yintercept=MG_cap, linetype="dashed", colour="navy") +
  scale_fill_manual(values=c("TRUE"="#2166AC","FALSE"="#D7191C")) +
  labs(title="CCEMG Country Estimates: β(Capital Intensity → Labor Share)",
       subtitle=paste0("Panel MG = ", round(MG_cap,3),
                       ifelse(p_cap<0.05," (p<0.05)",ifelse(p_cap<0.10," (p<0.10)"," (NS)"))),
       x=NULL, y="β coefficient") +
  coord_flip() +
  theme_minimal(base_size=11) +
  theme(panel.grid.major.y=element_blank(), plot.title=element_text(face="bold"))

ggsave(file.path(DATA_DIR, "fig_ccemg_panel_estimates.png"), p_het, width=7, height=5, dpi=300)
cat("Figure saved: fig_ccemg_panel_estimates.png\n")

# =============================================================================
# 6. DUMITRESCU-HURLIN CAUSALITY (2012)
# =============================================================================
cat("\n=== 6. DUMITRESCU-HURLIN CAUSALITY ===\n")

# DH: country-by-country Granger, then average Wald stat (W-bar) and Z-bar
# H0: no causal relationship for all i
# H1: at least one i has Granger causality

dh_test <- function(y_var, x_var, data, lags=2) {
  cntrs <- unique(data$iso3c)
  wald_stats <- sapply(cntrs, function(cty) {
    d <- data |> filter(iso3c==cty) |> arrange(year)
    if (nrow(d) < lags + 5) return(NA_real_)
    y <- d[[y_var]]; x <- d[[x_var]]
    if (any(is.na(y)) || any(is.na(x))) return(NA_real_)
    tryCatch({
      n_obs <- length(y)
      # Build lagged matrix
      Y  <- tail(y, n_obs - lags)
      Xl <- sapply(1:lags, function(l) y[(lags - l + 1):(n_obs - l)])   # lags of y
      Xl_x <- sapply(1:lags, function(l) x[(lags - l + 1):(n_obs - l)]) # lags of x
      df_r <- data.frame(Y=Y, Xl)   # restricted: only y lags
      df_u <- data.frame(Y=Y, Xl, Xl_x)  # unrestricted: y + x lags

      m_r <- lm(Y ~ ., data=df_r)
      m_u <- lm(Y ~ ., data=df_u)

      # F → chi^2 Wald
      rss_r  <- sum(resid(m_r)^2)
      rss_u  <- sum(resid(m_u)^2)
      df_num <- lags
      df_den <- nrow(df_u) - ncol(df_u)
      F_stat <- ((rss_r - rss_u) / df_num) / (rss_u / df_den)
      F_stat * df_num  # Wald = F * K
    }, error=function(e) NA_real_)
  })

  valid_stats <- na.omit(wald_stats)
  N_dh  <- length(valid_stats)
  T_avg <- mean(sapply(cntrs, function(cty) sum(data$iso3c==cty)), na.rm=TRUE)
  Wbar  <- mean(valid_stats)
  # Zbar approximation (Dumitrescu-Hurlin 2012, eq.9)
  Zbar  <- sqrt(N_dh / (2 * lags)) * (Wbar - lags)
  p_z   <- 2 * pnorm(-abs(Zbar))

  tibble(
    direction   = paste0(x_var, " → ", y_var),
    N_countries = N_dh,
    lags        = lags,
    W_bar       = round(Wbar, 3),
    Z_bar       = round(Zbar, 3),
    p_value     = round(p_z, 4),
    result      = ifelse(p_z<0.01, "Granger ***",
                  ifelse(p_z<0.05, "Granger **",
                  ifelse(p_z<0.10, "Granger *", "No Granger")))
  )
}

cat("Testing causality directions (lag=2)...\n")
dh_results <- bind_rows(
  dh_test("labor_share", "capital_intensity", panel, lags=2),
  dh_test("capital_intensity", "labor_share",  panel, lags=2),
  dh_test("labor_share", "ln_tfp",            panel, lags=2),
  dh_test("ln_tfp",      "labor_share",        panel, lags=2),
  dh_test("labor_share", "trade_open",         panel, lags=2),
  dh_test("trade_open",  "labor_share",         panel, lags=2)
)

cat("\nDumitrescu-Hurlin Results:\n")
print(dh_results)
write_csv(dh_results, file.path(DATA_DIR, paste0("results_dh_causality_",TODAY,".csv")))

# =============================================================================
# 7. FE BASELINE WITH DRISCOLL-KRAAY SE
# =============================================================================
cat("\n=== 7. FE BASELINE (Driscoll-Kraay SE) ===\n")

tryCatch({
  library(lfe)
  fe_dk <- felm(labor_share ~ capital_intensity + ln_tfp + ln_complexity +
                  trade_open + fdi | iso3c + year | 0 | iso3c,
                data=panel)
  cat("FE with clustered SE (cluster=country):\n")
  print(summary(fe_dk))
}, error=function(e) {
  # Fallback: plm + vcovHC
  fe_plm <- plm(labor_share ~ capital_intensity + ln_tfp + ln_complexity + trade_open + fdi,
                data=pdata, model="within", effect="twoways")
  dk_se   <- sqrt(diag(vcovHC(fe_plm, type="HC1")))
  fe_coef <- coef(fe_plm)
  fe_t    <- fe_coef / dk_se
  fe_p    <- 2 * pt(-abs(fe_t), df=length(fe_coef))

  fe_table <- tibble(
    variable=names(fe_coef), beta=round(fe_coef,4), se_hc1=round(dk_se,4),
    t_stat=round(fe_t,3), p_value=round(fe_p,4),
    sig=ifelse(fe_p<0.01,"***",ifelse(fe_p<0.05,"**",ifelse(fe_p<0.10,"*","")))
  )
  cat("FE Twoways (HC1 SE):\n")
  print(fe_table)
  write_csv(fe_table, file.path(DATA_DIR, paste0("results_fe_baseline_",TODAY,".csv")))
})

# =============================================================================
# 8. AMG (Augmented Mean Group — Bond-Eberhardt 2009)
# =============================================================================
cat("\n=== 8. AMG ESTIMATOR ===\n")

# AMG: two-step
# Step 1: pool FD regression with year dummies → get common dynamic process μ_t
# Step 2: country MG with μ_t as additional regressor

tryCatch({
  # Step 1: FD with year dummies
  panel_fd_amg <- panel |> arrange(iso3c, year) |> group_by(iso3c) |>
    mutate(
      d_y  = labor_share    - lag(labor_share),
      d_x1 = capital_intensity - lag(capital_intensity),
      d_x2 = ln_tfp         - lag(ln_tfp),
      d_x3 = ln_complexity  - lag(ln_complexity),
      d_x4 = trade_open     - lag(trade_open)
    ) |> ungroup() |> filter(!is.na(d_y))

  pdata_fd <- pdata.frame(panel_fd_amg, index=c("iso3c","year"))
  fd_pool  <- plm(d_y ~ d_x1 + d_x2 + d_x3 + d_x4 + factor(year),
                  data=pdata_fd, model="pooling")

  year_coefs <- coef(fd_pool)[grepl("factor\\(year\\)",names(coef(fd_pool)))]
  year_vals  <- as.integer(gsub("factor\\(year\\)","",names(year_coefs)))
  mu_t       <- data.frame(year=year_vals, mu_t=as.numeric(year_coefs))

  panel_amg <- panel_fd_amg |> left_join(mu_t, by="year")

  # Step 2: Country MG with μ_t
  amg_country <- lapply(unique(panel_amg$iso3c), function(cty) {
    d <- panel_amg |> filter(iso3c==cty, !is.na(d_y), !is.na(mu_t))
    if (nrow(d) < 8) return(NULL)
    tryCatch({
      m <- lm(d_y ~ d_x1 + d_x2 + d_x3 + d_x4 + mu_t, data=d)
      cf <- coef(m)
      tibble(iso3c=cty, n=nrow(d),
             beta_cap=cf["d_x1"], beta_tfp=cf["d_x2"],
             beta_complex=cf["d_x3"], beta_trade=cf["d_x4"])
    }, error=function(e) NULL)
  }) |> bind_rows()

  AMG_cap <- mean(amg_country$beta_cap, na.rm=TRUE)
  AMG_tfp <- mean(amg_country$beta_tfp, na.rm=TRUE)
  SE_amg_cap <- sd(amg_country$beta_cap, na.rm=TRUE) / sqrt(nrow(amg_country))
  SE_amg_tfp <- sd(amg_country$beta_tfp, na.rm=TRUE) / sqrt(nrow(amg_country))

  cat("AMG Results:\n")
  cat("  β_cap:", round(AMG_cap,4), "| SE:", round(SE_amg_cap,4),
      " | t:", round(AMG_cap/SE_amg_cap,3), "\n")
  cat("  β_tfp:", round(AMG_tfp,4), "| SE:", round(SE_amg_tfp,4),
      " | t:", round(AMG_tfp/SE_amg_tfp,3), "\n")

  amg_panel <- tibble(estimator="AMG", N_countries=nrow(amg_country),
                      beta_cap=round(AMG_cap,4), se_cap=round(SE_amg_cap,4),
                      beta_tfp=round(AMG_tfp,4), se_tfp=round(SE_amg_tfp,4))
  write_csv(amg_panel,    file.path(DATA_DIR, paste0("results_amg_panel_",TODAY,".csv")))
  write_csv(amg_country,  file.path(DATA_DIR, paste0("results_amg_country_",TODAY,".csv")))

}, error=function(e) cat("AMG error:", e$message, "\n"))

# =============================================================================
# 9. SUMMARY TABLE
# =============================================================================
cat("\n=== FINAL RESULTS SUMMARY ===\n")
cat("CSD:         labor_share, capital_intensity, ln_tfp — check results_csd_*.csv\n")
cat("CIPS:        unit root orders — check results_cips_*.csv\n")
cat("CCEMG MG:    β_cap =", round(MG_cap,4), "(p =", round(p_cap,4),")\n")
cat("D-H causality: check results_dh_causality_*.csv\n")
cat("\n✅ Script 06 complete.\n")
cat("Next: write 04-Manuscript/main.qmd\n")
