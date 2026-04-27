# =============================================================================
# IGI Global — Eurasian Energy & Geoeconomic Vulnerability
# Script 02: CSD Tests + CCEMG + AMG + CS-ARDL(1,0) Estimation
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-22
# Prerequisites: panel_eurasian_energy_20260422.csv from Script 01
# =============================================================================

library(plm)
library(dplyr)
library(tidyr)
library(fixest)
library(sandwich)
library(lmtest)

# -----------------------------------------------------------------------------
# 1. LOAD DATA
# -----------------------------------------------------------------------------
data_path <- "../02-Data/panel_eurasian_energy_20260422.csv"
panel <- read.csv(data_path, stringsAsFactors = FALSE)

panel <- panel %>%
  arrange(iso3c, year) %>%
  group_by(iso3c) %>%
  mutate(
    ln_gdppc   = log(gdppc),
    exrate_dep = (exrate - dplyr::lag(exrate, 1)) / dplyr::lag(exrate, 1) * 100
  ) %>%
  ungroup()

# Working sample: complete cases on key variables
panel_clean <- panel %>%
  filter(!is.na(ca_bal), !is.na(energy_dep),
         !is.na(gdppc),  !is.na(trade), !is.na(inflation))

cat("=== ESTIMATION SAMPLE ===\n")
cat("Obs:", nrow(panel_clean),
    "| Countries:", length(unique(panel_clean$iso3c)),
    "| Years:", min(panel_clean$year), "–", max(panel_clean$year), "\n")

pdata <- pdata.frame(panel_clean, index = c("iso3c", "year"))

# -----------------------------------------------------------------------------
# 2. PREREQUISITE — Pesaran CD Test (cross-section dependence)
# -----------------------------------------------------------------------------
cat("\n=== STEP 1: Pesaran CD Test ===\n")

fe_base <- plm(ca_bal ~ energy_dep + ln_gdppc + trade + inflation,
               data = pdata, model = "within", effect = "twoways")

cd <- pcdtest(fe_base, test = "cd")
cat("CD statistic:", round(cd$statistic, 3),
    "| p-value:", round(cd$p.value, 4), "\n")
cat(ifelse(cd$p.value < 0.05,
    "→ CSD CONFIRMED — CS estimators (CCEMG/AMG/CS-ARDL) required.\n",
    "→ No significant CSD detected.\n"))

# -----------------------------------------------------------------------------
# 3. PREREQUISITE — CIPS Panel Unit Root (Pesaran 2007)
# -----------------------------------------------------------------------------
cat("\n=== STEP 2: CIPS Panel Unit Root Tests ===\n")

vars_ur <- c("ca_bal", "energy_dep", "ln_gdppc", "trade", "inflation")
ur_results <- data.frame(variable=character(), stat=numeric(),
                          decision=character(), stringsAsFactors=FALSE)

for (v in vars_ur) {
  res <- tryCatch({
    ct <- cipstest(pdata[[v]], type = "trend", lags = 1, model = "cmg")
    data.frame(variable = v,
               stat     = round(ct$statistic, 3),
               decision = ifelse(ct$p.value < 0.10, "I(0)", "I(1)"),
               stringsAsFactors = FALSE)
  }, error = function(e) {
    # Fallback: IPS
    tryCatch({
      ip <- purtest(pdata[[v]], test = "ips", lags = 1, exo = "intercept")
      data.frame(variable = v,
                 stat     = round(ip$statistic$statistic, 3),
                 decision = ifelse(ip$statistic$p.value < 0.10, "I(0) [IPS]",
                                   "I(1) [IPS]"),
                 stringsAsFactors = FALSE)
    }, error = function(e2) {
      data.frame(variable=v, stat=NA, decision="Test failed",
                 stringsAsFactors=FALSE)
    })
  })
  ur_results <- rbind(ur_results, res)
}
print(ur_results)

# -----------------------------------------------------------------------------
# 4. CCEMG — Common Correlated Effects Mean Group (Pesaran 2006)
# -----------------------------------------------------------------------------
cat("\n=== STEP 3: CCEMG ===\n")

ccemg <- tryCatch(
  pmg(ca_bal ~ energy_dep + ln_gdppc + trade + inflation,
      data = pdata, model = "cmg"),
  error = function(e) { cat("CCEMG error:", e$message, "\n"); NULL }
)

if (!is.null(ccemg)) {
  s_ccemg <- summary(ccemg)
  print(s_ccemg)
  ccemg_b  <- coef(ccemg)["energy_dep"]
  ccemg_se <- sqrt(diag(vcov(ccemg)))["energy_dep"]
  ccemg_t  <- ccemg_b / ccemg_se
  ccemg_p  <- 2 * pt(abs(ccemg_t), df = length(unique(panel_clean$iso3c)) - 1,
                      lower.tail = FALSE)
  cat("CCEMG energy_dep: β =", round(ccemg_b, 4),
      "SE =", round(ccemg_se, 4),
      "p =", round(ccemg_p, 4), "\n")
}

# -----------------------------------------------------------------------------
# 5. MG — Mean Group (Pesaran & Smith 1995) — benchmark
# -----------------------------------------------------------------------------
cat("\n=== STEP 4: Mean Group (MG) ===\n")

mg <- tryCatch(
  pmg(ca_bal ~ energy_dep + ln_gdppc + trade + inflation,
      data = pdata, model = "mg"),
  error = function(e) { cat("MG error:", e$message, "\n"); NULL }
)

if (!is.null(mg)) {
  print(summary(mg))
  mg_b  <- coef(mg)["energy_dep"]
  mg_se <- sqrt(diag(vcov(mg)))["energy_dep"]
}

# -----------------------------------------------------------------------------
# 6. AMG — Augmented Mean Group (Bond & Eberhardt 2009)
# Manual: year-dummy CDP from first-differenced pooled regression
# -----------------------------------------------------------------------------
cat("\n=== STEP 5: AMG (manual) ===\n")

# First-difference panel
panel_fd <- panel_clean %>%
  group_by(iso3c) %>%
  arrange(year) %>%
  mutate(
    d_ca_bal     = ca_bal     - dplyr::lag(ca_bal),
    d_energy_dep = energy_dep - dplyr::lag(energy_dep),
    d_ln_gdppc   = ln_gdppc   - dplyr::lag(ln_gdppc),
    d_trade      = trade      - dplyr::lag(trade),
    d_inflation  = inflation  - dplyr::lag(inflation),
    year_f       = as.factor(year)
  ) %>%
  ungroup() %>%
  filter(!is.na(d_ca_bal), !is.na(d_energy_dep), !is.na(d_ln_gdppc),
         !is.na(d_trade),  !is.na(d_inflation))

# Stage 1: pooled FD with year dummies → Common Dynamic Process (CDP)
amg_s1 <- lm(d_ca_bal ~ d_energy_dep + d_ln_gdppc + d_trade + d_inflation + year_f,
              data = panel_fd)

# CDP: cumulative sum of year-dummy coefficients
ycoef <- coef(amg_s1)[grepl("^year_f", names(coef(amg_s1)))]
yrs   <- as.numeric(sub("year_f", "", names(ycoef)))
base  <- min(panel_clean$year)
cdp_df <- data.frame(
  year = c(base, yrs),
  cdp  = cumsum(c(0, ycoef))
)

panel_amg <- panel_clean %>%
  left_join(cdp_df, by = "year")

# Stage 2: country-by-country OLS with CDP
countries <- unique(panel_amg$iso3c)
amg_list  <- list()

for (cc in countries) {
  d <- panel_amg %>%
    filter(iso3c == cc) %>%
    filter(complete.cases(select(., ca_bal, energy_dep, ln_gdppc,
                                  trade, inflation, cdp)))
  if (nrow(d) < 5) next
  tryCatch({
    fit <- lm(ca_bal ~ energy_dep + ln_gdppc + trade + inflation + cdp, data = d)
    amg_list[[cc]] <- coef(fit)[c("energy_dep", "ln_gdppc", "trade", "inflation")]
  }, error = function(e) NULL)
}

if (length(amg_list) > 0) {
  amg_mat <- do.call(rbind, amg_list)
  N_amg   <- nrow(amg_mat)
  amg_b   <- colMeans(amg_mat, na.rm = TRUE)
  amg_se  <- apply(amg_mat, 2, sd, na.rm = TRUE) / sqrt(N_amg)
  amg_t   <- amg_b / amg_se
  amg_p   <- 2 * pt(abs(amg_t), df = N_amg - 1, lower.tail = FALSE)

  amg_out <- data.frame(
    coef    = round(amg_b, 4),
    SE      = round(amg_se, 4),
    t       = round(amg_t, 3),
    p       = round(amg_p, 4),
    sig     = ifelse(amg_p < 0.01, "***",
              ifelse(amg_p < 0.05, "**",
              ifelse(amg_p < 0.10, "*", "")))
  )
  cat("\nAMG Results (N =", N_amg, "countries):\n")
  print(amg_out)
  cat("AMG energy_dep: β =", round(amg_b["energy_dep"], 4),
      "(SE =", round(amg_se["energy_dep"], 4), ")\n")
}

# -----------------------------------------------------------------------------
# 7. CS-ARDL(1,0) — Chudik & Pesaran (2015)
# Add lagged DV + cross-sectional averages (CSA) of y and X
# -----------------------------------------------------------------------------
cat("\n=== STEP 6: CS-ARDL(1,0) Mean Group ===\n")

# Cross-sectional averages per year
csa <- panel_clean %>%
  group_by(year) %>%
  summarise(
    csa_ca     = mean(ca_bal,     na.rm = TRUE),
    csa_en     = mean(energy_dep, na.rm = TRUE),
    csa_gdp    = mean(ln_gdppc,   na.rm = TRUE),
    csa_trade  = mean(trade,      na.rm = TRUE),
    csa_inf    = mean(inflation,  na.rm = TRUE),
    .groups = "drop"
  )

panel_cs <- panel_clean %>%
  left_join(csa, by = "year") %>%
  group_by(iso3c) %>%
  arrange(year) %>%
  mutate(
    ca_lag1     = dplyr::lag(ca_bal, 1),
    csa_ca_lag1 = dplyr::lag(csa_ca, 1)
  ) %>%
  ungroup() %>%
  filter(!is.na(ca_lag1))

# Country-by-country CS-ARDL(1,0)
csardl_list <- list()

for (cc in unique(panel_cs$iso3c)) {
  d <- panel_cs %>%
    filter(iso3c == cc) %>%
    filter(complete.cases(select(., ca_bal, ca_lag1, energy_dep, ln_gdppc,
                                  trade, inflation, csa_ca, csa_ca_lag1,
                                  csa_en, csa_gdp, csa_trade, csa_inf)))
  if (nrow(d) < 7) next
  tryCatch({
    fit <- lm(ca_bal ~ ca_lag1 + energy_dep + ln_gdppc + trade + inflation +
                csa_ca + csa_ca_lag1 + csa_en + csa_gdp + csa_trade + csa_inf,
              data = d)
    phi    <- coef(fit)["ca_lag1"]
    b_sr   <- coef(fit)["energy_dep"]
    if (!is.na(phi) && abs(1 - phi) > 0.05 && phi < 1) {
      b_lr <- b_sr / (1 - phi)
      csardl_list[[cc]] <- c(sr = b_sr, lr = b_lr, ecm = phi - 1)
    }
  }, error = function(e) NULL)
}

if (length(csardl_list) > 0) {
  cs_mat  <- do.call(rbind, csardl_list)
  N_cs    <- nrow(cs_mat)
  cs_b    <- colMeans(cs_mat, na.rm = TRUE)
  cs_se   <- apply(cs_mat, 2, sd, na.rm = TRUE) / sqrt(N_cs)
  cs_t    <- cs_b / cs_se
  cs_p    <- 2 * pt(abs(cs_t), df = pmax(N_cs - 1, 1), lower.tail = FALSE)

  csardl_out <- data.frame(
    coef = round(cs_b, 4),
    SE   = round(cs_se, 4),
    t    = round(cs_t, 3),
    p    = round(cs_p, 4),
    sig  = ifelse(cs_p < 0.01, "***",
           ifelse(cs_p < 0.05, "**",
           ifelse(cs_p < 0.10, "*", "")))
  )
  cat("\nCS-ARDL(1,0) MG Results (N =", N_cs, "countries):\n")
  print(csardl_out)
  cat("CS-ARDL SR energy_dep: β =", round(cs_b["sr"], 4),
      "| LR: β =", round(cs_b["lr"], 4),
      "| ECM:", round(cs_b["ecm"], 4), "\n")
}

# -----------------------------------------------------------------------------
# 8. COEFFICIENT COMPARISON TABLE
# -----------------------------------------------------------------------------
cat("\n=== MASTER COEFFICIENT TABLE: energy_dep → CA Balance ===\n")

# Pooled OLS
m_ols  <- lm(ca_bal ~ energy_dep + ln_gdppc + trade + inflation,
              data = panel_clean, na.action = na.omit)
ols_se_hc <- sqrt(diag(sandwich::vcovHC(m_ols, type = "HC1")))

# Two-Way FE
m_fe  <- plm(ca_bal ~ energy_dep + ln_gdppc + trade + inflation,
              data = pdata, model = "within", effect = "twoways")
fe_se_hc  <- sqrt(diag(sandwich::vcovHC(m_fe,  type = "HC3")))

comp <- data.frame(
  Model     = c("Pooled OLS", "Two-Way FE"),
  beta      = round(c(coef(m_ols)["energy_dep"], coef(m_fe)["energy_dep"]), 4),
  SE        = round(c(ols_se_hc["energy_dep"], fe_se_hc["energy_dep"]), 4),
  Estimator = c("OLS/HC1", "FE/HC3"),
  stringsAsFactors = FALSE
)

if (!is.null(ccemg) && exists("ccemg_b")) {
  comp <- rbind(comp,
    data.frame(Model="CCEMG", beta=round(ccemg_b,4),
               SE=round(ccemg_se,4), Estimator="CMG/Pesaran2006"))
}
if (exists("amg_b") && "energy_dep" %in% names(amg_b)) {
  comp <- rbind(comp,
    data.frame(Model="AMG", beta=round(amg_b["energy_dep"],4),
               SE=round(amg_se["energy_dep"],4), Estimator="MG+CDP"))
}
if (exists("cs_b") && "sr" %in% names(cs_b)) {
  comp <- rbind(comp,
    data.frame(Model="CS-ARDL (SR)", beta=round(cs_b["sr"],4),
               SE=round(cs_se["sr"],4), Estimator="CSA-MG/Chudik2015"))
  comp <- rbind(comp,
    data.frame(Model="CS-ARDL (LR)", beta=round(cs_b["lr"],4),
               SE=round(cs_se["lr"],4), Estimator="CSA-MG/Chudik2015"))
}

comp$t_stat <- round(comp$beta / comp$SE, 3)
comp$sig    <- ifelse(abs(comp$t_stat) > 2.576, "***",
               ifelse(abs(comp$t_stat) > 1.960, "**",
               ifelse(abs(comp$t_stat) > 1.645, "*", "")))

cat("\n")
print(comp, row.names = FALSE)

# -----------------------------------------------------------------------------
# 9. SAVE
# -----------------------------------------------------------------------------
out_dir <- "../02-Data/"
write.csv(comp,
          paste0(out_dir, "model_comparison_", format(Sys.Date(), "%Y%m%d"), ".csv"),
          row.names = FALSE)

cat("\n=== CS-ARDL/CCEMG/AMG ESTIMATION COMPLETE ===\n")
cat("Output saved: 02-Data/model_comparison_", format(Sys.Date(), "%Y%m%d"), ".csv\n")
