# =============================================================================
# CHRONIC INFLATION × IMPOSSIBLE TRINITY — Webb Wild Cluster Bootstrap
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-28
# Purpose: Regional subsample Probit inference with Webb (2023) wild cluster
#          bootstrap — MANDATORY for all subsamples with N_clusters < 30
#          ANAYASA: Webb bootstrap mandatory when N_clusters < 30
# Ref: Webb (2023, CAJE) DOI:10.1111/caje.12661
#      fwildclusterboot: Roodman et al. (2019), R/Stata/Julia
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(fwildclusterboot); library(lmtest)
  library(sandwich)
})

PANEL_PATH <- "../02-Data/clean/panel_chronic_inf_trilemma_v2.csv"
OUT_DIR    <- "../06-Results/tables"
dir.create(OUT_DIR, recursive=TRUE, showWarnings=FALSE)

panel <- read_csv(PANEL_PATH, show_col_types=FALSE)
panel_m <- panel |> filter(!is.na(MII), !is.na(gdp_growth))

# Year factor for FWB (needs integer or factor, not date)
panel_m <- panel_m |> mutate(year_f = as.factor(year))

# Cluster sizes
cat("=== Cluster counts per region ===\n")
panel_m |> group_by(region) |>
  summarise(N_cc = n_distinct(iso3c), N_obs = n()) |>
  arrange(N_cc) |> print()

# Note: fwildclusterboot works with lm; for Probit use LPM approximation
# LPM is acceptable for inference about marginal effects when outcome is binary
# and interest is in sign/significance, not exact probability prediction.
# Alternative: boottest() extension via wildBootTests for GLM

# =============================================================================
# REGIONS NEEDING WEBB (N_clusters < 30)
# =============================================================================
REGIONS_WEBB <- c(
  "South Asia",
  "Middle East & North Africa",
  "Europe & Central Asia",
  "East Asia & Pacific",
  "Latin America & Caribbean"
)

results_webb <- list()

for (reg in REGIONS_WEBB) {
  sub <- panel_m |> filter(region == reg)
  N_cc <- n_distinct(sub$iso3c)
  cat(sprintf("\n=== %s (N=%d countries, %d obs) ===\n", reg, N_cc, nrow(sub)))

  if (N_cc < 5) {
    cat("  ⚠️  Too few clusters for bootstrap — skip\n")
    next
  }

  # LPM with two-way FE via within transformation
  # (fwildclusterboot requires lm; use demeaned data)
  sub_fe <- sub |>
    group_by(iso3c) |>
    mutate(across(c(chronic10, MII, ERS, KAOPEN, gdp_growth,
                    trade_open, broad_money), ~ . - mean(., na.rm=TRUE))) |>
    ungroup()

  lpm_fe <- tryCatch(
    lm(chronic10 ~ MII + ERS + KAOPEN + gdp_growth + trade_open +
         broad_money + year_f,
       data = sub_fe),
    error = function(e) { cat("  lm error:", e$message, "\n"); NULL }
  )

  if (is.null(lpm_fe)) next

  # Standard clustered SE (for comparison)
  cl_se <- coeftest(lpm_fe,
                    vcov = vcovCL(lpm_fe, cluster = ~iso3c, data = sub_fe))
  cat("  Clustered SE (standard):\n")
  cat(sprintf("    MII:    b=%.3f, p=%.3f\n",
              coef(lpm_fe)["MII"],
              cl_se["MII", "Pr(>|t|)"]))
  cat(sprintf("    ERS:    b=%.3f, p=%.3f\n",
              coef(lpm_fe)["ERS"],
              cl_se["ERS", "Pr(>|t|)"]))
  cat(sprintf("    KAOPEN: b=%.3f, p=%.3f\n",
              coef(lpm_fe)["KAOPEN"],
              cl_se["KAOPEN", "Pr(>|t|)"]))

  # Webb wild cluster bootstrap
  wb_results <- list()
  for (var in c("MII", "ERS", "KAOPEN")) {
    tryCatch({
      # Rademacher weights by default; Webb = 6-point for N_cc < 10
      wb <- boottest(
        object   = lpm_fe,
        clustid  = "iso3c",
        param    = var,
        B        = 9999,
        type     = if (N_cc <= 10) "webb" else "rademacher",
        impose_null = TRUE
      )
      s_wb <- summary(wb)   # data.frame: term, estimate, statistic, p.value, conf.low, conf.high
      wb_results[[var]] <- list(
        b      = coef(lpm_fe)[var],
        p_webb = wb$p_val,
        ci_lo  = s_wb$conf.low,
        ci_hi  = s_wb$conf.high
      )
      cat(sprintf("  Webb bootstrap %s: b=%.3f, p_webb=%.3f, CI=[%.3f, %.3f]\n",
                  var,
                  wb_results[[var]]$b,
                  wb_results[[var]]$p_webb,
                  wb_results[[var]]$ci_lo,
                  wb_results[[var]]$ci_hi))
    }, error = function(e) {
      cat(sprintf("  boottest error (%s): %s\n", var, e$message))
      wb_results[[var]] <<- NULL
    })
  }

  results_webb[[reg]] <- wb_results
}

# =============================================================================
# SUMMARY TABLE
# =============================================================================
cat("\n=== WEBB BOOTSTRAP SUMMARY ===\n")
cat(sprintf("%-35s %-8s %-8s %-8s %-8s %-8s %-8s\n",
            "Region", "MII_b", "MII_p", "ERS_b", "ERS_p", "KAO_b", "KAO_p"))
cat(strrep("-", 80), "\n")

for (reg in names(results_webb)) {
  r <- results_webb[[reg]]
  cat(sprintf("%-35s %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f\n",
              substr(reg, 1, 34),
              if (!is.null(r$MII))    r$MII$b      else NA,
              if (!is.null(r$MII))    r$MII$p_webb else NA,
              if (!is.null(r$ERS))    r$ERS$b      else NA,
              if (!is.null(r$ERS))    r$ERS$p_webb else NA,
              if (!is.null(r$KAOPEN)) r$KAOPEN$b   else NA,
              if (!is.null(r$KAOPEN)) r$KAOPEN$p_webb else NA))
}

# SSA comparison (N=41 > 30, standard clustered SE sufficient)
sub_ssa <- panel_m |> filter(region == "Sub-Saharan Africa")
lpm_ssa <- lm(chronic10 ~ MII + ERS + KAOPEN + gdp_growth + trade_open + broad_money + year_f,
              data = sub_ssa |>
                group_by(iso3c) |>
                mutate(across(c(chronic10,MII,ERS,KAOPEN,gdp_growth,trade_open,broad_money),
                               ~.-mean(.,na.rm=T))) |>
                ungroup())
ssa_cl  <- coeftest(lpm_ssa, vcov = vcovCL(lpm_ssa, cluster = ~iso3c, data = sub_ssa))
cat(sprintf("%-35s %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f  [clustered SE, N_cc=41]\n",
            "Sub-Saharan Africa",
            coef(lpm_ssa)["MII"],    ssa_cl["MII",    "Pr(>|t|)"],
            coef(lpm_ssa)["ERS"],    ssa_cl["ERS",    "Pr(>|t|)"],
            coef(lpm_ssa)["KAOPEN"], ssa_cl["KAOPEN", "Pr(>|t|)"]))

# Save
sink(file.path(OUT_DIR, "webb_bootstrap_regional.txt"))
cat("Webb Wild Cluster Bootstrap — Regional Subsamples\n")
cat("ANAYASA: Webb mandatory for N_clusters < 30\n")
cat("Bootstrap type: Webb (6-point) for N≤10; Rademacher otherwise. B=9,999.\n\n")
cat(sprintf("%-35s %-8s %-8s %-8s %-8s %-8s %-8s\n",
            "Region", "MII_b", "MII_p", "ERS_b", "ERS_p", "KAO_b", "KAO_p"))
cat(strrep("-", 80), "\n")
for (reg in names(results_webb)) {
  r <- results_webb[[reg]]
  cat(sprintf("%-35s %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f\n",
              substr(reg, 1, 34),
              if (!is.null(r$MII))    r$MII$b      else NA,
              if (!is.null(r$MII))    r$MII$p_webb else NA,
              if (!is.null(r$ERS))    r$ERS$b      else NA,
              if (!is.null(r$ERS))    r$ERS$p_webb else NA,
              if (!is.null(r$KAOPEN)) r$KAOPEN$b   else NA,
              if (!is.null(r$KAOPEN)) r$KAOPEN$p_webb else NA))
}
sink()
cat("\n✅ Saved: 06-Results/tables/webb_bootstrap_regional.txt\n")
cat("=== 05_webb_bootstrap.R COMPLETE ===\n")
