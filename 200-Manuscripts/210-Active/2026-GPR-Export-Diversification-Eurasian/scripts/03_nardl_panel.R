# =============================================================================
# GPR & Export Diversification in Eurasian Economies
# Script 03: Panel NARDL — GPR Asymmetric Effects on Export Concentration
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Date: 2026-04-24
# =============================================================================
#
# Specification (country-by-country NARDL, then mean-group):
#   ΔHHI_t = α + ρ*HHI_{t-1} + θ^+*GPR^+_{t-1} + θ^-*GPR^-_{t-1}
#            + Σ controls + ε_t
#
# where GPR^+ = positive partial sum of ΔGPR (geopolitical escalations)
#       GPR^- = negative partial sum of ΔGPR (de-escalations)
#
# Tests:
#   1. Bounds test (cointegration between HHI and GPR)
#   2. Wald symmetry test: θ^+ = θ^-
#   3. Dumitrescu-Hurlin causality: GPR → HHI, HHI → GPR
#   4. CCEMG mean-group (cross-section dependence controlled)
# =============================================================================

pkgs <- c("dplyr","readr","tidyr","plm","ARDL","dynlm","lmtest","sandwich",
          "strucchange","ggplot2")
for (p in pkgs) if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos="https://cloud.r-project.org")

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tidyr); library(plm)
  library(dynlm); library(lmtest); library(sandwich)
  library(strucchange); library(ggplot2)
})

DATA_DIR   <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-GPR-Export-Diversification-Eurasian/data"
DRAFTS_DIR <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-GPR-Export-Diversification-Eurasian/drafts"
TODAY      <- format(Sys.Date(), "%Y%m%d")

dir.create(DRAFTS_DIR, showWarnings=FALSE, recursive=TRUE)

# --- Load panel ---------------------------------------------------------------
panel_files <- list.files(DATA_DIR, pattern="panel_gpr_hhi_.*\\.csv", full.names=TRUE)
if (length(panel_files) == 0) stop("Run script 02 first to build master panel.")

panel <- read_csv(panel_files[length(panel_files)], show_col_types=FALSE) |>
  arrange(iso3c, year)

cat("Panel:", nrow(panel), "obs |", n_distinct(panel$iso3c), "countries | years:", range(panel$year), "\n")

# Check HHI coverage
hhi_cov <- mean(!is.na(panel$hhi_dest))
cat("HHI coverage:", round(hhi_cov*100,1), "%\n")

if (hhi_cov < 0.5) {
  cat("⚠️  HHI coverage < 50% — BACI job may still be running.\n")
  cat("    Skipping estimation until BACI HHI is complete.\n")
  cat("    Re-run this script after baci_hhi_eurasian_*.csv is available.\n")
  quit(save="no")
}

# =============================================================================
# 1. CSD TEST
# =============================================================================
cat("\n=== Cross-Section Dependence Tests ===\n")

pdata <- pdata.frame(panel |> filter(!is.na(hhi_dest), !is.na(GPR)),
                     index=c("iso3c","year"))

vars_csd <- c("ln_hhi","ln_gpr","ln_gdppc","trade_open","res_rents")

csd_res <- lapply(vars_csd, function(v) {
  tryCatch({
    pd_v <- pdata[!is.na(pdata[[v]]), ]
    fe <- plm(as.formula(paste(v,"~ 1")), data=pd_v, model="within")
    cd <- plm::pcdtest(fe, test="cd")
    tibble(variable=v, CD_stat=round(cd$statistic,3), p_value=round(cd$p.value,4),
           result=ifelse(cd$p.value<0.05,"CSD ✓","No CSD"))
  }, error=function(e) tibble(variable=v, CD_stat=NA_real_, p_value=NA_real_, result=paste("Err:",e$message[1:40])))
}) |> bind_rows()

cat("CSD Results:\n"); print(csd_res)
write_csv(csd_res, file.path(DATA_DIR, paste0("results_csd_gpr_",TODAY,".csv")))

# =============================================================================
# 2. COUNTRY-BY-COUNTRY NARDL
# =============================================================================
cat("\n=== Country NARDL Estimation ===\n")

nardl_country <- lapply(unique(panel$iso3c), function(cty) {
  d <- panel |> filter(iso3c==cty, !is.na(hhi_dest), !is.na(GPR)) |> arrange(year)
  if (nrow(d) < 15) {
    cat(cty, ": insufficient obs (", nrow(d), ")\n"); return(NULL)
  }

  tryCatch({
    # NARDL: manual ECM with partial sums
    d_ts <- ts(d, start=min(d$year), frequency=1)

    m <- dynlm(
      d(ln_hhi) ~ L(ln_hhi) + L(pos_gpr) + L(neg_gpr) +
        d(pos_gpr) + d(neg_gpr) + L(d(ln_hhi), 1) +
        L(ln_gdppc, 0) + L(trade_open, 0),
      data = d_ts
    )

    cf <- coef(summary(m))
    rho <- cf["L(ln_hhi)","Estimate"]

    # Long-run multipliers
    lr_pos <- if ("L(pos_gpr)" %in% rownames(cf)) cf["L(pos_gpr)","Estimate"] / abs(rho) else NA
    lr_neg <- if ("L(neg_gpr)" %in% rownames(cf)) cf["L(neg_gpr)","Estimate"] / abs(rho) else NA

    # Wald test for symmetry
    wald_p <- tryCatch({
      test <- linearHypothesis(m, "L(pos_gpr) = L(neg_gpr)")
      test$`Pr(>F)`[2]
    }, error=function(e) NA_real_)

    tibble(
      iso3c   = cty,
      n       = nrow(d),
      rho     = round(rho, 4),
      lr_gpr_pos = round(lr_pos, 4),
      lr_gpr_neg = round(lr_neg, 4),
      wald_sym_p = round(wald_p, 4),
      asymmetric = ifelse(!is.na(wald_p) & wald_p < 0.10, "YES*", "No"),
      r2      = round(summary(m)$r.squared, 4)
    )
  }, error=function(e) {
    cat(cty, "NARDL error:", e$message, "\n"); NULL
  })
}) |> bind_rows()

if (nrow(nardl_country) > 0) {
  cat("\nCountry NARDL results:\n")
  print(nardl_country)

  # Mean-group panel NARDL
  N_mg <- nrow(nardl_country)
  MG_pos <- mean(nardl_country$lr_gpr_pos, na.rm=TRUE)
  MG_neg <- mean(nardl_country$lr_gpr_neg, na.rm=TRUE)
  SE_pos <- sd(nardl_country$lr_gpr_pos, na.rm=TRUE) / sqrt(N_mg)
  SE_neg <- sd(nardl_country$lr_gpr_neg, na.rm=TRUE) / sqrt(N_mg)

  cat("\n=== PANEL NARDL (Mean-Group) ===\n")
  cat("L^+(GPR escalation → HHI):", round(MG_pos,4), "| SE:", round(SE_pos,4),
      " | t:", round(MG_pos/SE_pos,3),
      ifelse(abs(MG_pos/SE_pos)>2.576,"***",ifelse(abs(MG_pos/SE_pos)>1.960,"**",ifelse(abs(MG_pos/SE_pos)>1.645,"*",""))),"\n")
  cat("L^-(GPR de-escalation → HHI):", round(MG_neg,4), "| SE:", round(SE_neg,4),
      " | t:", round(MG_neg/SE_neg,3),
      ifelse(abs(MG_neg/SE_neg)>2.576,"***",ifelse(abs(MG_neg/SE_neg)>1.960,"**",ifelse(abs(MG_neg/SE_neg)>1.645,"*",""))),"\n")

  mg_nardl <- tibble(
    estimator="MG-NARDL", N=N_mg,
    LR_GPR_pos=round(MG_pos,4), se_pos=round(SE_pos,4),
    LR_GPR_neg=round(MG_neg,4), se_neg=round(SE_neg,4),
    asymmetric = ifelse(abs(MG_pos - MG_neg) > 1.96*sqrt(SE_pos^2+SE_neg^2), "YES", "No")
  )
  write_csv(mg_nardl,       file.path(DATA_DIR, paste0("results_mg_nardl_",TODAY,".csv")))
  write_csv(nardl_country,  file.path(DATA_DIR, paste0("results_nardl_country_",TODAY,".csv")))

  # Heterogeneity plot
  plot_data <- nardl_country |>
    filter(!is.na(lr_gpr_pos)) |>
    pivot_longer(cols=c(lr_gpr_pos, lr_gpr_neg), names_to="shock", values_to="lr") |>
    mutate(shock = ifelse(shock=="lr_gpr_pos","GPR Escalation (LR+)","GPR De-escalation (LR-)"))

  p_ht <- ggplot(plot_data, aes(x=reorder(iso3c, lr), y=lr, fill=shock)) +
    geom_col(position="dodge") +
    scale_fill_manual(values=c("GPR Escalation (LR+)"="#D7191C","GPR De-escalation (LR-)"="#2166AC")) +
    labs(title="NARDL Long-Run Multipliers by Country: GPR → Export Concentration (HHI)",
         x=NULL, y="Long-Run Multiplier", fill=NULL) +
    coord_flip() +
    theme_minimal(base_size=11) +
    theme(legend.position="bottom", panel.grid.major.y=element_blank())

  ggsave(file.path(DRAFTS_DIR, "fig01_nardl_lr_country.png"), p_ht, width=8, height=5, dpi=300)
  cat("Figure saved: fig01_nardl_lr_country.png\n")
}

cat("\n✅ Script 03 complete. Next: write 04-Manuscript/main.qmd\n")
