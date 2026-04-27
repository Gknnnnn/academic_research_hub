# ============================================================
# AI Strategy Carbon DiD — Main Analysis (v0.1)
# Author: M. Gökhan Özdemir | 2026-04-09
# ============================================================
suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(did)
  library(ggplot2); library(readr)
})

PROJ <- here::here()
panel <- readRDS(file.path(PROJ, "400-Data/processed/ai_strategy_panel.rds"))

panel <- panel %>%
  filter(year >= 2005, year <= 2023) %>%
  group_by(iso_code) %>% filter(n() >= 10) %>% ungroup()

# ── M1: TWFE ──────────────────────────────────────────────────────────────────
m_co2 <- feols(ln_co2pc ~ post + ln_gdppc | iso_code + year,
               data = panel %>% filter(!is.na(ln_co2pc), !is.na(ln_gdppc)),
               cluster = ~iso_code)
m_ren <- feols(renewables_share_energy ~ post + ln_gdppc | iso_code + year,
               data = panel %>% filter(!is.na(renewables_share_energy), !is.na(ln_gdppc)),
               cluster = ~iso_code)

# ── M2: CS-ATT ────────────────────────────────────────────────────────────────
panel_co2 <- panel %>%
  filter(!is.na(ln_co2pc), !is.na(ln_gdppc)) %>%
  select(cid, year, g, ln_co2pc, ln_gdppc)

cs_co2 <- att_gt(
  yname = "ln_co2pc", tname = "year", idname = "cid", gname = "g",
  xformla = ~ln_gdppc, data = panel_co2,
  control_group = "nevertreated", est_method = "reg", clustervars = "cid"
)
cs_agg <- aggte(cs_co2, type = "simple")
cs_dyn <- aggte(cs_co2, type = "dynamic", min_e = -5, max_e = 4, na.rm = TRUE)

panel_ren <- panel %>%
  filter(!is.na(renewables_share_energy), !is.na(ln_gdppc)) %>%
  select(cid, year, g, renewables_share_energy, ln_gdppc)

cs_ren <- att_gt(
  yname = "renewables_share_energy", tname = "year", idname = "cid", gname = "g",
  xformla = ~ln_gdppc, data = panel_ren,
  control_group = "nevertreated", est_method = "reg", clustervars = "cid"
)
cs_ren_agg <- aggte(cs_ren, type = "simple")

# Pre-trend test
dyn <- cs_dyn$att.egt; times <- cs_dyn$egt; ses <- cs_dyn$se.egt
pre_idx <- which(times < 0)
chi2 <- sum((dyn[pre_idx]/ses[pre_idx])^2, na.rm=TRUE)
p_pretrend <- 1 - pchisq(chi2, df = sum(!is.na(dyn[pre_idx])))

# ── Save ──────────────────────────────────────────────────────────────────────
results <- list(
  m_co2=m_co2, m_ren=m_ren,
  cs_co2=cs_co2, cs_agg=cs_agg, cs_dyn=cs_dyn,
  cs_ren=cs_ren, cs_ren_agg=cs_ren_agg,
  pre_test=list(chi2=chi2, df=sum(!is.na(dyn[pre_idx])), p=p_pretrend)
)
saveRDS(results, file.path(PROJ, "600-Results/main_results.rds"))
message("Results saved.")
