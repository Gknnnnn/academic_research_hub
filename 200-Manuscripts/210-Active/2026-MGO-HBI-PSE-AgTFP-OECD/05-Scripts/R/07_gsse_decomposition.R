# 07_gsse_decomposition.R
# GSSE Sub-component Decomposition → New Panel + Re-estimation
# PSE × AgTFP OECD | MGO × HBI | 2026-04-25
#
# NEW CONTRIBUTION:
#   Decompose aggregate GSSE into:
#     gsse_akis  = GSSEH (Agricultural Knowledge & Innovation Systems = R&D + extension)
#     gsse_infra = GSSEJ (Infrastructure development & maintenance)
#     gsse_insp  = GSSEI (Inspection and control)
#     gsse_mktg  = GSSEK (Marketing and promotion)
#   Theory:
#     β(akis)  > 0  — knowledge spillovers → TFP (Alston et al. 2000, Fuglie 2018)
#     β(infra) ≈ 0  — public goods, neutral TFP impact
#     β(insp)  ≈ 0  — compliance cost, TFP-neutral
#     β(mktg)  ≤ 0  — no direct productivity channel
#   If confirmed: resolves the aggregate GSSE paradox (Mamun 2024)

suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
})

RAW   <- "../../06-Data/raw"
CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"

# ── 1. Load GSSE sub-components ───────────────────────────────────────────────
cat("Loading GSSE sub-component data...\n")

gsse_raw <- read_csv(
  file.path(RAW, "OECD_GSSE_subcomponents_raw.csv"),
  show_col_types = FALSE,
  name_repair = "universal"
) %>%
  rename(
    iso3       = REF_AREA,
    year       = TIME_PERIOD,
    measure    = MEASURE,
    value_usd  = OBS_VALUE,
    unit_mult  = UNIT_MULT
  ) %>%
  select(iso3, year, measure, value_usd, unit_mult) %>%
  filter(!is.na(value_usd)) %>%
  mutate(
    year      = as.integer(year),
    value_usd = as.numeric(value_usd),
    # Unit multiplier: 6 = millions USD
    value_musd = value_usd * (10^(as.numeric(unit_mult) - 6))
  )

cat("Available measures:\n")
print(table(gsse_raw$measure))

# ── 2. Pivot to wide: one row per country-year ────────────────────────────────
gsse_wide <- gsse_raw %>%
  filter(measure %in% c("GSSE", "GSSEH", "GSSEJ", "GSSEI", "GSSEK", "GSSEL", "GSSEM")) %>%
  select(iso3, year, measure, value_musd) %>%
  pivot_wider(names_from = measure, values_from = value_musd, values_fn = mean) %>%
  rename(
    gsse_total = GSSE,
    gsse_akis  = GSSEH,   # Agricultural Knowledge & Innovation Systems
    gsse_infra = GSSEJ,   # Infrastructure
    gsse_insp  = GSSEI,   # Inspection and control
    gsse_mktg  = GSSEK,   # Marketing and promotion
    gsse_stock = GSSEL,   # Public stockholding
    gsse_misc  = GSSEM    # Miscellaneous
  ) %>%
  arrange(iso3, year)

cat(sprintf("\nGSSE panel: N=%d countries, years %d–%d\n",
            n_distinct(gsse_wide$iso3),
            min(gsse_wide$year), max(gsse_wide$year)))

# ── 3. Compute AKIS share ─────────────────────────────────────────────────────
gsse_wide <- gsse_wide %>%
  mutate(
    akis_share  = gsse_akis  / gsse_total,
    infra_share = gsse_infra / gsse_total,
    insp_share  = gsse_insp  / gsse_total,
    mktg_share  = gsse_mktg  / gsse_total
  )

cat("\nMean AKIS share by country (full series):\n")
gsse_wide %>%
  filter(year >= 1990, year <= 2020) %>%
  group_by(iso3) %>%
  summarise(akis_share_mean  = mean(akis_share,  na.rm=TRUE),
            infra_share_mean = mean(infra_share, na.rm=TRUE)) %>%
  arrange(desc(akis_share_mean)) %>%
  print(n=27)

# ── 4. Merge with panel_master ────────────────────────────────────────────────
panel <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types = FALSE)

panel_new <- panel %>%
  left_join(gsse_wide %>% select(iso3, year, gsse_akis, gsse_infra, gsse_insp,
                                  gsse_mktg, akis_share, infra_share),
            by = c("iso3", "year")) %>%
  mutate(
    ln_tfp      = log(tfp_index),
    ln_gdppc    = log(gdppc_const2015),
    ln_fert     = log(fertilizer_kgha + 0.001),
    ln_agl      = log(agland_share  + 0.001),
    ln_mps      = log(mps_pos + 0.001),
    ln_gsse     = log(gsse_val + 0.001),
    # NEW sub-component log variables
    ln_gsse_akis  = log(gsse_akis  + 0.001),
    ln_gsse_infra = log(gsse_infra + 0.001),
    ln_gsse_insp  = log(gsse_insp  + 0.001),
    ln_gsse_mktg  = log(gsse_mktg  + 0.001)
  )

# Save extended panel
write_csv(panel_new, file.path(CLEAN, "panel_master_v2.csv"))
cat(sprintf("\nSaved panel_master_v2.csv: %d obs, %d countries\n",
            nrow(panel_new), n_distinct(panel_new$iso3)))

# ── 5. Coverage check for 1990–2020 ──────────────────────────────────────────
coverage <- panel_new %>%
  filter(year >= 1990, year <= 2020) %>%
  filter(!is.na(ln_tfp), !is.na(ln_gsse_akis), !is.na(ln_gsse_infra)) %>%
  group_by(iso3) %>%
  summarise(n_obs = n(), yr_min = min(year), yr_max = max(year))

cat(sprintf("\n1990–2020 coverage with AKIS+Infra: %d countries, %d obs\n",
            nrow(coverage), sum(coverage$n_obs)))
print(coverage, n=27)

# ── 6. Quick CCEMG estimation: Decomposed GSSE ────────────────────────────────
cat("\n\n═══ CCEMG: ln_tfp ~ ln_mps + ln_gsse_akis + ln_gsse_infra + controls ═══\n")

df_est <- panel_new %>%
  filter(year >= 1990, year <= 2020) %>%
  select(iso3, year, ln_tfp, ln_mps, ln_gsse, ln_gsse_akis, ln_gsse_infra,
         ln_gdppc, rural_share, ln_fert, ln_agl) %>%
  drop_na()

cat(sprintf("Estimation sample: N=%d, obs=%d\n\n",
            n_distinct(df_est$iso3), nrow(df_est)))

# Demean function for CCEMG (simple version — cross-sectional mean augmentation)
ccemg_simple <- function(data, yvar, xvars) {
  countries <- unique(data$iso3)
  N <- length(countries)
  betas <- matrix(NA, N, length(xvars), dimnames = list(countries, xvars))
  ses   <- matrix(NA, N, length(xvars), dimnames = list(countries, xvars))

  for (co in countries) {
    sub <- data %>% filter(iso3 == co) %>% arrange(year)
    if (nrow(sub) < length(xvars) + 6) next

    # Add cross-sectional means (pooled year means)
    ymeans <- data %>% group_by(year) %>% summarise(ym = mean(.data[[yvar]], na.rm=TRUE))
    xmeans <- lapply(xvars, function(x) {
      data %>% group_by(year) %>% summarise(xm = mean(.data[[x]], na.rm=TRUE)) %>%
        setNames(c("year", paste0(x, "_m")))
    })
    sub <- sub %>% left_join(ymeans, by = "year")
    for (xm in xmeans) sub <- sub %>% left_join(xm, by = "year")

    fmla <- as.formula(paste(yvar, "~",
      paste(c(xvars, "ym", paste0(xvars, "_m")), collapse = "+")))

    m <- tryCatch(lm(fmla, data = sub), error = function(e) NULL)
    if (is.null(m)) next

    cf <- tryCatch(coef(summary(m)), error = function(e) NULL)
    if (is.null(cf)) next

    for (xv in xvars) {
      if (xv %in% rownames(cf)) {
        betas[co, xv] <- cf[xv, "Estimate"]
        ses[co, xv]   <- cf[xv, "Std. Error"]
      }
    }
  }

  # Mean group
  valid <- apply(!is.na(betas), 2, which)
  results <- data.frame(
    Variable = xvars,
    MG_beta  = sapply(xvars, function(x) mean(betas[, x], na.rm=TRUE)),
    MG_se    = sapply(xvars, function(x) {
      vals <- betas[!is.na(betas[, x]), x]
      if (length(vals) < 2) return(NA)
      sd(vals) / sqrt(length(vals))
    }),
    N_countries = sapply(xvars, function(x) sum(!is.na(betas[, x])))
  ) %>%
  mutate(
    t_stat = MG_beta / MG_se,
    p_value = 2 * pt(-abs(t_stat), df = N_countries - 1),
    sig    = case_when(p_value < 0.01 ~ "***",
                       p_value < 0.05 ~ "**",
                       p_value < 0.10 ~ "*",
                       TRUE ~ "")
  )
  results
}

# Model A: Aggregate GSSE (replication of v04)
XVARS_A <- c("ln_mps", "ln_gsse", "ln_gdppc", "rural_share", "ln_fert", "ln_agl")
res_A <- ccemg_simple(df_est, "ln_tfp", XVARS_A)
cat("MODEL A — Aggregate GSSE (replication):\n")
print(res_A %>% select(Variable, MG_beta, MG_se, t_stat, p_value, sig, N_countries),
      digits = 4, row.names = FALSE)

# Model B: Decomposed GSSE — AKIS + Infrastructure
XVARS_B <- c("ln_mps", "ln_gsse_akis", "ln_gsse_infra", "ln_gdppc", "rural_share", "ln_fert", "ln_agl")
res_B <- ccemg_simple(df_est, "ln_tfp", XVARS_B)
cat("\nMODEL B — Decomposed GSSE (ln_gsse_akis + ln_gsse_infra):\n")
print(res_B %>% select(Variable, MG_beta, MG_se, t_stat, p_value, sig, N_countries),
      digits = 4, row.names = FALSE)

# ── 7. Summary comparison table ───────────────────────────────────────────────
cat("\n\n══════ COMPOSITION DECOMPOSITION RESULTS ══════\n\n")

comp_table <- bind_rows(
  res_A %>% mutate(Model = "A: Aggregate GSSE"),
  res_B %>% mutate(Model = "B: Decomposed GSSE")
) %>%
  select(Model, Variable, MG_beta, MG_se, p_value, sig, N_countries) %>%
  mutate(across(c(MG_beta, MG_se, p_value), ~ round(.x, 4)))

print(comp_table, row.names = FALSE)

# Save table
write_csv(comp_table, file.path(TBLS, "tab_gsse_decomposition.csv"))

cat("\n\n══ INTERPRETATION ══\n")
akis_b  <- res_B$MG_beta[res_B$Variable == "ln_gsse_akis"]
infra_b <- res_B$MG_beta[res_B$Variable == "ln_gsse_infra"]
akis_p  <- res_B$p_value[res_B$Variable == "ln_gsse_akis"]
infra_p <- res_B$p_value[res_B$Variable == "ln_gsse_infra"]

cat(sprintf("AKIS (knowledge/R&D): β = %.4f, p = %.4f\n", akis_b, akis_p))
cat(sprintf("Infrastructure:        β = %.4f, p = %.4f\n", infra_b, infra_p))

if (!is.na(akis_b) && !is.na(infra_b)) {
  if (akis_b > 0 && akis_p < 0.10) {
    cat("\n✅ COMPOSITION HYPOTHESIS SUPPORTED:\n")
    cat("   AKIS (R&D/extension) is POSITIVE — knowledge spillovers drive TFP.\n")
    cat("   Aggregate GSSE is negative because infrastructure dilutes AKIS signal.\n")
    cat("   → New story: 'GSSE quality (AKIS share), not quantity, drives TFP.'\n")
  } else if (akis_b > 0 && akis_p < 0.20) {
    cat("\n⚠️  COMPOSITION HYPOTHESIS: MARGINAL AKIS POSITIVE\n")
    cat("   AKIS directionally positive but not significant at 10%.\n")
    cat("   Consider: Webb bootstrap or longer panel for inference.\n")
  } else {
    cat("\n❌ COMPOSITION HYPOTHESIS NOT CONFIRMED:\n")
    cat("   AKIS not positive — deeper analysis needed (lags? nonlinearity?).\n")
  }
}

cat("\n✓ 07_gsse_decomposition.R complete\n")
cat("  Next: if Model B confirms AKIS+, rewrite v05 with new variable classification.\n")
