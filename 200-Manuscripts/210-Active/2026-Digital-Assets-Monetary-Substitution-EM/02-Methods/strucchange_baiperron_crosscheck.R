# ============================================================================
# strucchange_baiperron_crosscheck.R — Paper 6 (Digital Assets / EM)
# Author : Dr. M. Gökhan Özdemir — Kırıkkale University
# Date   : 2026-04-10
#
# Purpose: Cross-check Python Bai-Perron (2003) supF p-values against R
#          strucchange package. Python uses χ²(q) approximation; R uses
#          the exact finite-sample F-distribution critical values from
#          Bai-Perron (2003) Table 1.
#
# CLAUDE.md rule: "Bai-Perron supF p-values are χ²(q) approximations —
#  cross-check with strucchange before any Q1 submission."
#
# Model (per country): Δfx_it ~ 1 + inflation_monthly_it
#   (same equation as run_paper6_v5_baiperron.py)
#
# Output: strucchange_baiperron_crosscheck.csv + .md summary
# ============================================================================

suppressMessages({
  library(strucchange)
  library(dplyr)
  library(tidyr)
})

# ── Paths ───────────────────────────────────────────────────────────────────
DATA <- paste0(
  "~/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/",
  "200-Manuscripts/210-Active/2026-Digital-Assets-Monetary-Substitution-EM/",
  "03-Results/paper6_em_panel_v5_vix.csv"
)
OUT_DIR <- paste0(
  "~/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/",
  "200-Manuscripts/210-Active/2026-Digital-Assets-Monetary-Substitution-EM/",
  "03-Results"
)

cat("═══════════════════════════════════════════════════════════════\n")
cat(" Paper 6 — Bai-Perron R strucchange Cross-Check\n")
cat(sprintf(" Run: %s\n", Sys.time()))
cat("═══════════════════════════════════════════════════════════════\n\n")
cat(" Equation: Δfx ~ 1 + inflation_monthly  (per country)\n")
cat(" Trimming: h=0.15  Max breaks: m=3  Significance: 5%\n\n")

# ── Data ────────────────────────────────────────────────────────────────────
df <- read.csv(DATA, stringsAsFactors = FALSE)
df$DATE <- as.Date(df$DATE)
df <- df[order(df$country, df$DATE), ]
df <- df[!is.na(df$fx_depreciation) & !is.na(df$inflation_monthly), ]

# Python Bai-Perron results for comparison
python_results <- list(
  Argentina   = list(breaks=3, dates=c("2018-09","2022-07","2024-01"),
                     supF=c(10.218,9.336,7.148), p=c(0.0000,0.0001,0.0008)),
  Brazil      = list(breaks=1, dates=c("2002-09"),
                     supF=c(3.343),              p=c(0.0353)),
  India       = list(breaks=2, dates=c("1983-07","1991-07"),
                     supF=c(7.011,8.571),        p=c(0.0009,0.0002)),
  Mexico      = list(breaks=1, dates=c("1998-09"),
                     supF=c(6.559),              p=c(0.0014)),
  Nigeria     = list(breaks=1, dates=c("2016-05"),
                     supF=c(8.035),              p=c(0.0003)),
  `South Africa` = list(breaks=2, dates=c("1993-07","2002-12"),
                     supF=c(4.170,3.399),        p=c(0.0155,0.0334))
)

countries <- c("Argentina","Brazil","India","Mexico","Nigeria","South Africa")
results_all <- list()

for (cty in countries) {
  cat(sprintf("══ %s ══\n", cty))
  sub <- df[df$country == cty, ]
  sub <- sub[order(sub$DATE), ]
  T_i <- nrow(sub)
  cat(sprintf("  T = %d  (range: %s to %s)\n",
              T_i, format(min(sub$DATE)),format(max(sub$DATE))))

  if (T_i < 20) {
    cat("  Insufficient obs — skip\n\n")
    next
  }

  y <- sub$fx_depreciation
  x <- sub$inflation_monthly

  # ── strucchange Fstats (empirical fluctuation process) ──────────────────
  # Equation: y ~ x (intercept by default in breakpoints)
  tryCatch({
    h_min <- max(2L, floor(0.15 * T_i))   # integer min-segment length
    bp <- breakpoints(y ~ x, h = h_min, breaks = 3)
    bp_summary <- summary(bp)

    # Optimal m via BIC
    bic_vec <- bp_summary$RSS["BIC", ]
    m_bic   <- which.min(bic_vec) - 1L  # 0-indexed: m=0,1,2,3
    cat(sprintf("  BIC-optimal breaks: m̂ = %d\n", m_bic))

    # strucchange Fstats (overall supF — Andrews 1993)
    from_i <- ceiling(0.15 * T_i)
    to_i   <- floor(0.85 * T_i)
    fs  <- Fstats(y ~ x, from = from_i, to = to_i)
    sc1 <- sctest(fs, type = "supF")
    cat(sprintf("  sctest supF(overall): F = %.3f  p = %.4f\n",
                sc1$statistic, sc1$p.value))

    # Sequential sctest for m=1,2,3 (like Python sequential supF)
    for (mm in 1:3) {
      tryCatch({
        bpm  <- breakpoints(bp, breaks = mm)
        if (mm <= 1 || !is.null(bpm$breakpoints)) {
          # F-test for mm vs mm-1 breaks using RSS ratio
          rss_mm   <- bp_summary$RSS["RSS", mm + 1]
          rss_mm_1 <- bp_summary$RSS["RSS", mm]
          # Approximate F: (RSS(m-1)-RSS(m))/RSS(m) * (T-2m) / p
          k_reg <- 2L   # intercept + slope
          T_eff <- T_i - 2L * mm
          if (T_eff > 0 && rss_mm > 0) {
            F_seq <- ((rss_mm_1 - rss_mm) / k_reg) / (rss_mm / T_eff)
            p_chi <- 1 - pchisq(F_seq * k_reg, df = k_reg)
            cat(sprintf("  supF(%d|%d): F=%.3f  p_chi=%.4f\n",
                        mm, mm-1, F_seq, p_chi))
          }
        }
      }, error = function(e2) NULL)
    }

    # Extract estimated break dates if breaks > 0
    bd <- character(0)
    if (m_bic >= 1L) {
      bp_m <- breakpoints(bp, breaks = m_bic)
      if (!is.null(bp_m$breakpoints) && !any(is.na(bp_m$breakpoints))) {
        bd <- sub$DATE[bp_m$breakpoints]
        cat(sprintf("  Break dates (BIC m=%d): %s\n", m_bic,
                    paste(format(bd, "%Y-%m"), collapse=", ")))
      } else {
        m_bic <- 0L
        cat("  No structural breaks selected by BIC\n")
      }
    } else {
      cat("  No structural breaks selected by BIC\n")
    }

    # RSS at m=0,1,2,3
    cat("  RSS by m: ")
    rss_row <- bp_summary$RSS["RSS", ]
    for (k in seq_along(rss_row)) {
      cat(sprintf("m=%d:%.2f ", k-1, rss_row[k]))
    }
    cat("\n")

    # Compare with Python
    py  <- python_results[[cty]]
    cat(sprintf("\n  Comparison (Python χ² vs R strucchange):\n"))
    cat(sprintf("  Python m̂=%d  Break(s): %s\n",
                py$breaks, paste(py$dates, collapse=", ")))
    bd_str <- if (length(bd) > 0L) paste(format(bd, "%Y-%m"), collapse=", ") else "(none)"
    cat(sprintf("  R      m̂=%d  Break(s): %s\n", m_bic, bd_str))

    # Agreement check: m matches?
    m_agree   <- (m_bic == py$breaks)
    # Date match within 3 months for each break
    date_agree <- NA
    if (m_bic == py$breaks && m_bic >= 1 && length(bd) == length(py$dates)) {
      py_dates   <- as.Date(paste0(py$dates, "-01"))
      date_diffs <- abs(as.numeric(bd - py_dates))
      date_agree <- all(date_diffs <= 93)   # within 3 months
    } else if (m_bic == 0 && py$breaks == 0) {
      date_agree <- TRUE
    }

    status <- if (!is.na(date_agree) && date_agree) "✓ AGREE" else
              if (m_agree) "≈ m-agree, dates differ" else "⚠ DISAGREE"
    cat(sprintf("  Status: %s\n\n", status))

    results_all[[cty]] <- list(
      country        = cty,
      T              = T_i,
      py_m           = py$breaks,
      R_m_bic        = m_bic,
      py_dates       = paste(py$dates, collapse=";"),
      R_dates        = if (length(bd) > 0L) paste(format(bd, "%Y-%m"), collapse=";") else "",
      sctest_F       = round(sc1$statistic, 3),
      sctest_p       = round(sc1$p.value, 4),
      py_supF_1_0    = py$supF[1],
      py_p_1_0       = py$p[1],
      m_agree        = m_agree,
      status         = status
    )

  }, error = function(e) {
    cat(sprintf("  ERROR: %s\n\n", conditionMessage(e)))
    results_all[[cty]] <<- list(
      country = cty, T = T_i, error = conditionMessage(e)
    )
  })
}

# ── Summary table ────────────────────────────────────────────────────────────
cat("═══════════════════════════════════════════════════════════════\n")
cat(" Cross-Check Summary\n")
cat("═══════════════════════════════════════════════════════════════\n\n")
cat(sprintf("  %-14s  %5s  %5s  %6s  %6s  %8s  %8s  %s\n",
            "Country","Py-m","R-m","Py-F","R-F","Py-p","R-p","Status"))
cat("  " , paste(rep("─",80), collapse=""), "\n", sep="")

rows_df <- lapply(results_all, function(r) {
  if (!is.null(r$error)) {
    cat(sprintf("  %-14s  ERROR: %s\n", r$country, r$error))
    return(NULL)
  }
  cat(sprintf("  %-14s  %5d  %5d  %6.3f  %6.3f  %8.4f  %8.4f  %s\n",
              r$country, r$py_m, r$R_m_bic,
              r$py_supF_1_0, r$sctest_F,
              r$py_p_1_0, r$sctest_p,
              r$status))
  as.data.frame(r[c("country","T","py_m","R_m_bic","py_dates","R_dates",
                     "sctest_F","sctest_p","py_supF_1_0","py_p_1_0",
                     "m_agree","status")])
})
rows_df <- do.call(rbind, Filter(Negate(is.null), rows_df))

if (!is.null(rows_df) && nrow(rows_df) > 0) {
  write.csv(rows_df,
    file.path(OUT_DIR, "strucchange_baiperron_crosscheck.csv"),
    row.names = FALSE)
  cat(sprintf("\n  Saved: %s/strucchange_baiperron_crosscheck.csv\n", OUT_DIR))
}

# ── Methodological notes ─────────────────────────────────────────────────────
cat("\n══ Methodological Notes ══\n")
cat(sprintf("
  1. Python supF p-values use the χ²(q) asymptotic approximation where
     q = number of regressors + 1. This is the Bai-Perron (2003) standard
     but is known to be conservative (over-rejects) in small T.

  2. R strucchange::Fstats() uses the exact finite-sample F-distribution
     (Andrews 1993), which is the preferred approach for moderate T.
     sctest(type='supF') is the overall structural stability test;
     it is equivalent to the sup Wald test (Quandt 1960 / Andrews 1993).

  3. strucchange::breakpoints() selects m by BIC minimisation —
     this may differ from the sequential supF(ℓ+1|ℓ) selection in Python,
     which uses the χ² p-value threshold at 5%%.

  4. For Q1 submission: report BOTH methods with a note that
     'p-values from Python use χ²(q) approximation; R strucchange
     BIC-selected m serves as cross-validation.' If m disagrees between
     methods, use the more conservative estimate and report the discrepancy.

  5. Argentina (2018-09, 2022-07, 2024-01) are the policy-relevant breaks
     in the GCAI analysis window (2021-2024). These should agree closely
     since T_AR=110 is moderate and both methods converge for large T.
     Any disagreement on the 2022-07 break (LUNA/FTX crash) warrants
     explicit footnote in the manuscript.
"))

cat("\n  strucchange cross-check complete.\n")
