# ============================================================
# CIVETS Unemployment — AMG + CCEMG (Parsimonious) + Webb
# Spec: unemp ~ ln_gdp_pc + inflation + goveff  (k=3)
# Script: 04b_amg_ccemg_parsimonious_20260426.R
# ============================================================

suppressPackageStartupMessages(library(tidyverse))

panel <- read_csv("01-Data/raw/civets_panel_merged_20260426.csv",
                  show_col_types = FALSE) %>%
  mutate(ln_gdp_pc = log(gdp_pc)) %>%
  arrange(iso3c, year)

countries <- sort(unique(panel$iso3c))
N <- 6; T_obs <- 24
dep  <- "unemp"
regs <- c("ln_gdp_pc", "inflation", "goveff")   # parsimonious
k    <- length(regs)

cat(sprintf("=== Parsimonious: %s ~ %s ===\n", dep, paste(regs, collapse=" + ")))
cat(sprintf("N=%d, T=%d, k=%d | DOF/country: CCEMG=%d, AMG=%d\n\n",
            N, T_obs, k, T_obs - k - 1 - (k+1), T_obs - k - 2))

# ── CS means for CCEMG ────────────────────────────────────
cs_means <- panel %>%
  group_by(year) %>%
  summarise(
    cs_y      = mean(unemp, na.rm = TRUE),
    cs_gdp    = mean(ln_gdp_pc, na.rm = TRUE),
    cs_inf    = mean(inflation, na.rm = TRUE),
    cs_goveff = mean(goveff, na.rm = TRUE),
    .groups = "drop"
  )
panel_aug <- panel %>% left_join(cs_means, by = "year")
augvars   <- c("cs_y", "cs_gdp", "cs_inf", "cs_goveff")

# ── CDP for AMG ───────────────────────────────────────────
panel_fd <- panel %>%
  group_by(iso3c) %>%
  mutate(
    d_unemp     = c(NA, diff(unemp)),
    d_ln_gdp_pc = c(NA, diff(ln_gdp_pc)),
    d_inflation = c(NA, diff(inflation)),
    d_goveff    = c(NA, diff(goveff))
  ) %>%
  ungroup() %>%
  filter(!is.na(d_unemp))

step1 <- lm(d_unemp ~ d_ln_gdp_pc + d_inflation + d_goveff + factor(year) - 1,
            data = panel_fd)

yc     <- coef(step1)[grep("factor", names(coef(step1)))]
yr     <- as.integer(gsub("factor\\(year\\)", "", names(yc)))
cdp_df <- tibble(year = yr, cdp = as.numeric(yc)) %>%
  bind_rows(tibble(year = min(panel$year), cdp = 0)) %>%
  arrange(year) %>%
  mutate(cdp_cum = cumsum(cdp))
panel_amg <- panel %>% left_join(cdp_df %>% select(year, cdp_cum), by = "year")

# ── Individual estimates ──────────────────────────────────
betas_cc <- matrix(NA, N, k, dimnames = list(countries, regs))
betas_am <- matrix(NA, N, k, dimnames = list(countries, regs))

fml_cc  <- unemp ~ ln_gdp_pc + inflation + goveff + cs_y + cs_gdp + cs_inf + cs_goveff
fml_am  <- unemp ~ ln_gdp_pc + inflation + goveff + cdp_cum

cat("Individual estimates:\n")
cat(sprintf("  %-3s | %8s %8s %8s | %8s %8s %8s\n",
            "Ctry", "CC.gdp", "CC.inf", "CC.gov", "AM.gdp", "AM.inf", "AM.gov"))
cat(paste(rep("-", 65), collapse = ""), "\n")

for (i in seq_along(countries)) {
  # CCEMG
  sub_cc <- panel_aug %>% filter(iso3c == countries[i])
  mc <- tryCatch(lm(fml_cc, data = sub_cc), error = function(e) NULL)
  if (!is.null(mc)) {
    b <- coef(mc)
    for (r in regs) if (r %in% names(b)) betas_cc[i, r] <- b[r]
  }
  # AMG
  sub_am <- panel_amg %>% filter(iso3c == countries[i])
  ma <- tryCatch(lm(fml_am, data = sub_am), error = function(e) NULL)
  if (!is.null(ma)) {
    b <- coef(ma)
    for (r in regs) if (r %in% names(b)) betas_am[i, r] <- b[r]
  }
  cat(sprintf("  %-3s | %8.3f %8.3f %8.3f | %8.3f %8.3f %8.3f\n",
              countries[i],
              betas_cc[i,"ln_gdp_pc"], betas_cc[i,"inflation"], betas_cc[i,"goveff"],
              betas_am[i,"ln_gdp_pc"], betas_am[i,"inflation"], betas_am[i,"goveff"]))
}
cat(paste(rep("-", 65), collapse = ""), "\n")

beta_cc <- colMeans(betas_cc, na.rm = TRUE)
se_cc   <- apply(betas_cc, 2, function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x))))
t_cc    <- beta_cc / se_cc

beta_am <- colMeans(betas_am, na.rm = TRUE)
se_am   <- apply(betas_am, 2, function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x))))
t_am    <- beta_am / se_am

cat(sprintf("  %-3s | %8.3f %8.3f %8.3f | %8.3f %8.3f %8.3f\n",
            "MG", beta_cc["ln_gdp_pc"], beta_cc["inflation"], beta_cc["goveff"],
                  beta_am["ln_gdp_pc"], beta_am["inflation"], beta_am["goveff"]))
cat(sprintf("  %-3s | %8.3f %8.3f %8.3f | %8.3f %8.3f %8.3f\n",
            "SE", se_cc["ln_gdp_pc"], se_cc["inflation"], se_cc["goveff"],
                  se_am["ln_gdp_pc"], se_am["inflation"], se_am["goveff"]))
cat(sprintf("  %-3s | %8.3f %8.3f %8.3f | %8.3f %8.3f %8.3f\n",
            "t",  t_cc["ln_gdp_pc"],  t_cc["inflation"],  t_cc["goveff"],
                  t_am["ln_gdp_pc"],  t_am["inflation"],  t_am["goveff"]))

# ── Webb wild cluster bootstrap ────────────────────────────
cat("\nWebb bootstrap (B=999)...\n")
set.seed(2026); B <- 999
webb_w  <- c(-sqrt(1.5), -1, -sqrt(0.5), sqrt(0.5), 1, sqrt(1.5))
boot_cc <- matrix(NA, B, k, dimnames = list(NULL, regs))
boot_am <- matrix(NA, B, k, dimnames = list(NULL, regs))

for (b in 1:B) {
  w_i <- sample(webb_w, N, replace = TRUE)
  panel_b <- panel %>% mutate(ln_gdp_pc = log(gdp_pc))
  for (i in seq_along(countries))
    panel_b$unemp[panel_b$iso3c == countries[i]] <-
      panel_b$unemp[panel_b$iso3c == countries[i]] * w_i[i]

  cs_b <- panel_b %>% group_by(year) %>%
    summarise(cs_y   = mean(unemp, na.rm = TRUE),
              cs_gdp = mean(ln_gdp_pc, na.rm = TRUE),
              cs_inf = mean(inflation, na.rm = TRUE),
              cs_goveff = mean(goveff, na.rm = TRUE), .groups = "drop")
  pb_cc <- panel_b %>% left_join(cs_b, by = "year")
  pb_am <- panel_b %>% left_join(cdp_df %>% select(year, cdp_cum), by = "year")

  bc_mat <- matrix(NA, N, k); ba_mat <- matrix(NA, N, k)
  for (i in seq_along(countries)) {
    sb_cc <- pb_cc %>% filter(iso3c == countries[i])
    mc_b <- tryCatch(lm(fml_cc, data = sb_cc), error = function(e) NULL)
    if (!is.null(mc_b)) {
      b_c <- coef(mc_b)
      for (r in regs) if (r %in% names(b_c)) bc_mat[i, which(regs == r)] <- b_c[r]
    }
    sb_am <- pb_am %>% filter(iso3c == countries[i])
    ma_b <- tryCatch(lm(fml_am, data = sb_am), error = function(e) NULL)
    if (!is.null(ma_b)) {
      b_a <- coef(ma_b)
      for (r in regs) if (r %in% names(b_a)) ba_mat[i, which(regs == r)] <- b_a[r]
    }
  }
  boot_cc[b, ] <- colMeans(bc_mat, na.rm = TRUE)
  boot_am[b, ] <- colMeans(ba_mat, na.rm = TRUE)
}

ci_cc_lo <- apply(boot_cc, 2, quantile, 0.025, na.rm = TRUE)
ci_cc_hi <- apply(boot_cc, 2, quantile, 0.975, na.rm = TRUE)
ci_am_lo <- apply(boot_am, 2, quantile, 0.025, na.rm = TRUE)
ci_am_hi <- apply(boot_am, 2, quantile, 0.975, na.rm = TRUE)

p_cc <- sapply(seq_along(regs), function(j) {
  bs <- boot_cc[, j] - mean(boot_cc[, j], na.rm = TRUE)
  2 * min(mean(bs >= abs(beta_cc[j]), na.rm = TRUE),
          mean(bs <= -abs(beta_cc[j]), na.rm = TRUE))
})
p_am <- sapply(seq_along(regs), function(j) {
  bs <- boot_am[, j] - mean(boot_am[, j], na.rm = TRUE)
  2 * min(mean(bs >= abs(beta_am[j]), na.rm = TRUE),
          mean(bs <= -abs(beta_am[j]), na.rm = TRUE))
})

sg <- function(p) if (p < 0.01) "***" else if (p < 0.05) "**" else if (p < 0.10) "*" else "   "

cat("\n═══════════════════════════════════════════════════════════\n")
cat("LONG-RUN ESTIMATES: CCEMG and AMG | Webb 95% CI (B=999)\n")
cat(sprintf("Model: unemp ~ ln_gdp_pc + inflation + goveff | N=%d T=%d\n", N, T_obs))
cat("═══════════════════════════════════════════════════════════\n")
cat(sprintf("%-13s  %6s%3s  %-18s  %6s%3s  %-18s\n",
            "Variable", "CCEMG", "", "Webb 95% CI", "AMG", "", "Webb 95% CI"))
cat(paste(rep("─", 66), collapse = ""), "\n")

res_rows <- list()
for (j in seq_along(regs)) {
  r <- regs[j]
  cat(sprintf("%-13s  %6.3f%3s [%7.3f,%7.3f]  %6.3f%3s [%7.3f,%7.3f]\n",
              r,
              beta_cc[r], sg(p_cc[j]), ci_cc_lo[r], ci_cc_hi[r],
              beta_am[r], sg(p_am[j]), ci_am_lo[r], ci_am_hi[r]))
  res_rows[[r]] <- tibble(
    variable = r,
    ccemg = round(beta_cc[r], 4), cc_lo = round(ci_cc_lo[r], 4),
    cc_hi = round(ci_cc_hi[r], 4), p_cc = round(p_cc[j], 4),
    amg   = round(beta_am[r], 4), am_lo = round(ci_am_lo[r], 4),
    am_hi = round(ci_am_hi[r], 4), p_am = round(p_am[j], 4)
  )
}
cat(paste(rep("─", 66), collapse = ""), "\n")
cat("Notes: Webb (2023) 6-point weights {±√0.5, ±1, ±√1.5}\n")
cat("       *** p<0.01  ** p<0.05  * p<0.10 (two-sided)\n")
cat("⚠ N=6: large-sample inference unreliable; Webb bootstrap is primary\n")

results_df <- bind_rows(res_rows)
dir.create("03-Output/tables", recursive = TRUE, showWarnings = FALSE)
write_csv(results_df, "03-Output/tables/results_amg_ccemg_webb_parsimonious_20260426.csv")
cat("\n✅ Saved: results_amg_ccemg_webb_parsimonious_20260426.csv\n")
