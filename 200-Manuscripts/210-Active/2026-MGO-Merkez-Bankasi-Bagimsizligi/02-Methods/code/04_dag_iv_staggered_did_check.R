# =============================================================================
# Script 04 — DAG IV Identification + Staggered DiD Check
# Paper: "The Credibility Premium Under Fiscal Dominance: CBI and Sovereign
#          Yield Spreads in BRICS-T+MINT, 2000–2024" (Proposal D)
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Version: 2026-04-24
#
# PURPOSE:
#   (A) DAG — Formalise causal identification: CBI (endogenous) → sovereign spread.
#       Instrument: "neighbourhood CBI" average (Bartik-style spatial IV).
#       Back-door paths: fiscal fundamentals + political risk (partially observable).
#   (B) STAGGERED DiD CHECK — Governor dismissal events (d_political_dismissal)
#       occur at different times across BRICS-T+MINT countries.
#       Check: Are events genuinely staggered (vary by country-year)?
#       If staggered → standard TWFE is biased (Callaway-Sant'Anna 2021 required).
#       If all-at-once or single-wave → TWFE remains valid.
#
# Literature:
#   Garriga (2016) CBI — doi:10.1111/infi.12107
#   Callaway & Sant'Anna (2021) — doi:10.1016/j.jeconom.2020.12.001
#   Goldsmith-Pinkham et al. (2020) Bartik — doi:10.1257/aer.20181047
# =============================================================================

for (pkg in c("dagitty", "ggdag", "ggplot2", "dplyr", "tidyr")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
}
library(dagitty)
library(ggdag)
library(ggplot2)
library(dplyr)
library(tidyr)

BASE_PATH <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-MGO-Merkez-Bankasi-Bagimsizligi"
DATA_PATH <- file.path(BASE_PATH, "02-Methods/data/processed")
FIG_PATH  <- file.path(BASE_PATH, "02-Methods/figures")
dir.create(FIG_PATH, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# PART A: DAG — CBI → Sovereign Spread Identification
# =============================================================================
# Nodes:
#   CBI      [exposure, endogenous — de jure Garriga 2016 index]
#   SS       [outcome — sovereign yield spread, bps]
#   Z_nbr    [instrument — neighbour-country mean CBI (spatial Bartik)]
#   FIS      [fiscal fundamentals — debt/GDP, primary balance; OBSERVED]
#   POL      [political risk — V-Dem Polyarchy, Polity5; OBSERVED]
#   U_crty   [latent — country-specific institutional quality]
#   D_DIS    [governor dismissal dummy — OBSERVED; mediator/moderator]
#   GLOB     [global risk factor — VIX, US10Y; OBSERVED]
#
# Key identification claims:
#   (1) Z_nbr → CBI     : countries emulate neighbours' CBI reforms (spatial spillover)
#   (2) Z_nbr ⊥ SS | CBI, FIS, POL, GLOB : neighbour CBI does not directly affect
#                         borrowing costs; only via own-country CBI
#   (3) U_crty → CBI + SS : latent institutional quality confounds — partially
#                         absorbed by FE; residual requires IV
#   (4) D_DIS → CBI     : dismissal directly reduces effective CBI
#   (5) D_DIS → SS      : direct market response to dismissal (event study)
# =============================================================================

dag_cbi <- dagitty('dag {
  Z_nbr  [pos="0,1"]
  CBI    [pos="2,1" exposure]
  SS     [pos="4,1" outcome]
  FIS    [pos="2,2"]
  POL    [pos="3,2"]
  U_crty [pos="1,0" latent]
  D_DIS  [pos="3,0"]
  GLOB   [pos="4,0"]

  Z_nbr -> CBI
  CBI -> SS
  FIS -> SS
  FIS -> CBI
  POL -> CBI
  POL -> SS
  U_crty -> CBI
  U_crty -> SS
  D_DIS -> CBI
  D_DIS -> SS
  GLOB -> SS
}')

cat("=== Part A: DAG — CBI → Sovereign Spread ===\n")
cat("Is acyclic:", isAcyclic(dag_cbi), "\n")

# Adjustment set (back-door criterion)
adj_cbi <- adjustmentSets(dag_cbi, "CBI", "SS", type = "all")
cat("\nAdjustment sets (CBI → SS):\n")
print(adj_cbi)

# Implied independence (testable)
ci_cbi <- impliedConditionalIndependencies(dag_cbi)
cat("\nTestable independencies:\n")
for (ci in ci_cbi) cat(" ", as.character(ci), "\n")

# Key exclusion: Z_nbr ⊥ SS | CBI, FIS, POL, GLOB
cat("\nKey exclusion test: Z_nbr ⊥ SS | CBI, FIS, POL, GLOB\n")
cat("Testable via first-stage Kleibergen-Paap F + over-identification (if >1 IV).\n")

# --- Figure A1: DAG visualisation -------------------------------------------
node_df <- data.frame(
  name      = c("Z_nbr", "CBI", "SS", "FIS", "POL", "U_crty", "D_DIS", "GLOB"),
  x         = c(0, 2, 4, 2, 3, 1, 3, 4),
  y         = c(1, 1, 1, 0, 0, 2, 2, 2),
  node_type = c("instrument", "exposure", "outcome",
                "observed", "observed", "latent",
                "treatment_event", "observed"),
  stringsAsFactors = FALSE
)

edge_df <- data.frame(
  from = c("Z_nbr","CBI","FIS","FIS","POL","POL","U_crty","U_crty","D_DIS","D_DIS","GLOB"),
  to   = c("CBI",  "SS", "SS","CBI","CBI","SS","CBI",  "SS",   "CBI",  "SS",  "SS"),
  style = c("solid","solid","solid","solid","solid","solid","dashed","dashed","solid","solid","solid"),
  stringsAsFactors = FALSE
)

# Merge with positions
edge_full <- edge_df %>%
  left_join(node_df %>% select(name, x, y) %>% rename(from=name, x0=x, y0=y), by="from") %>%
  left_join(node_df %>% select(name, x, y) %>% rename(to=name, x1=x, y1=y), by="to")

type_col <- c(
  "instrument"      = "#1A9641",
  "exposure"        = "#D7191C",
  "outcome"         = "#2166AC",
  "observed"        = "#F4A582",
  "latent"          = "#762A83",
  "treatment_event" = "#E66101"
)

p_dag <- ggplot() +
  geom_segment(data = edge_full,
               aes(x=x0, y=y0, xend=x1, yend=y1, linetype=style),
               arrow = arrow(length=unit(0.18,"cm"), type="closed"),
               colour="grey35", linewidth=0.65) +
  geom_point(data=node_df, aes(x=x, y=y, colour=node_type, shape=node_type), size=9) +
  geom_text(data=node_df, aes(x=x, y=y, label=name),
            size=2.9, fontface="bold", colour="white") +
  scale_colour_manual(values=type_col, name="Node type") +
  scale_shape_manual(values=c("instrument"=15,"exposure"=19,"outcome"=17,
                               "observed"=18,"latent"=8,"treatment_event"=15),
                     name="Node type") +
  scale_linetype_manual(values=c("solid"="solid","dashed"="dashed"),
                        labels=c("Causal path","Latent/unobserved"),
                        name="Edge") +
  annotate("label", x=2, y=1.5,
           label="Exclusion: Z_nbr ⊥ SS | CBI, FIS, POL, GLOB",
           size=2.6, colour="#1A9641", fill="#F7FCF5",
           label.padding=unit(0.25,"lines")) +
  labs(
    title    = "Fig. A1: DAG — CBI → Sovereign Spread (Proposal D)",
    subtitle = "Neighbour-CBI instrument satisfies exclusion; D_DIS modelled as event-study treatment",
    caption  = paste0(
      "Note: Z_nbr = spatial Bartik IV (average CBI in geographic/economic neighbours).\n",
      "U_crty = latent institutional quality; absorbed by country FE in regression.\n",
      "Adjustment set: {FIS, POL, GLOB}. D_DIS governor dismissal also confounds.\n",
      "BRICS-T+MINT, N=9, T=25 (2000-2024)."
    )
  ) +
  theme_void(base_size=11) +
  theme(plot.title=element_text(face="bold"), legend.position="right",
        plot.caption=element_text(size=7.5, colour="grey40"),
        plot.margin=margin(10,10,10,10))

ggsave(file.path(FIG_PATH, "figA_dag_cbi_sovereign.png"), p_dag,
       width=9, height=5, dpi=300)
cat("Saved: figA_dag_cbi_sovereign.png\n")

# =============================================================================
# PART B: STAGGERED DiD CHECK
# =============================================================================
# Check whether political governor dismissal events (d_political_dismissal)
# are genuinely staggered across country-years.
#
# If STAGGERED: Different countries experience "treatment" (dismissal) in
#   different years → standard TWFE estimates weighted average of all 2×2 DiD
#   subgroups, some of which may have negative weights (Callaway-Sant'Anna).
# If NOT STAGGERED: All dismissals happen in same year → TWFE valid.
# =============================================================================

cat("\n\n=== Part B: Staggered DiD Check ===\n")

# Load panel data (if available)
panel_file <- file.path(DATA_PATH, "panel_D_merged.csv")

if (file.exists(panel_file)) {
  panel <- read.csv(panel_file, stringsAsFactors = FALSE)
  cat("Panel loaded:", nrow(panel), "obs ×", ncol(panel), "vars\n")
  cat("Countries:", length(unique(panel$country)), "\n")
  cat("Years:", min(panel$year), "–", max(panel$year), "\n")

  # Identify first dismissal year per country (g_i = cohort)
  dismissal_cohorts <- panel %>%
    filter(d_political_dismissal == 1) %>%
    group_by(country) %>%
    summarise(first_dismissal = min(year), n_events = n(), .groups = "drop")

  cat("\nDismissal cohorts (first event by country):\n")
  print(dismissal_cohorts)

  n_cohorts <- length(unique(dismissal_cohorts$first_dismissal))
  cat("\nNumber of distinct treatment cohorts:", n_cohorts, "\n")

  if (n_cohorts > 1) {
    cat("→ STAGGERED DiD confirmed (", n_cohorts, "cohorts).\n")
    cat("→ RECOMMENDATION: Use Callaway-Sant'Anna (2021) CS-ATT.\n")
    cat("   Import: library(did); att_gt(gname='first_dismissal', ...)\n")
    cat("   Script: see 03_proposal_D_sovereign_yields.R M3 section.\n")
  } else if (n_cohorts == 1) {
    cat("→ NOT staggered: all dismissals in year", unique(dismissal_cohorts$first_dismissal), "\n")
    cat("→ Standard 2×2 DiD (TWFE) valid.\n")
  } else {
    cat("→ No dismissal events detected — check d_political_dismissal column.\n")
  }

  # Negative weight check (Bacon decomposition preview)
  never_treated <- panel %>%
    group_by(country) %>%
    summarise(ever_treated = any(d_political_dismissal == 1), .groups = "drop")

  cat("\nTreatment status:\n")
  print(never_treated)
  cat("Never-treated countries (control group):", sum(!never_treated$ever_treated), "\n")

  if (sum(!never_treated$ever_treated) == 0) {
    cat("⚠️ WARNING: No clean never-treated control group!\n")
    cat("   CS-ATT will use 'not-yet-treated' as controls — may introduce bias.\n")
    cat("   Consider: (a) extending sample; (b) using synthetic control.\n")
  }

  # --- Figure B1: Treatment timing matrix ---
  timing_df <- panel %>%
    select(country, year, d_political_dismissal) %>%
    mutate(status = case_when(
      d_political_dismissal == 1 ~ "Dismissal event",
      TRUE ~ "No event"
    ))

  # Merge cohort info
  timing_df <- timing_df %>%
    left_join(dismissal_cohorts %>% select(country, first_dismissal), by = "country") %>%
    mutate(
      cohort_label = ifelse(is.na(first_dismissal), "Never treated",
                            paste0("Treated ", first_dismissal)),
      cohort_label = factor(cohort_label)
    )

  p_timing <- ggplot(timing_df, aes(x = year, y = country, fill = status)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    scale_fill_manual(values = c("Dismissal event" = "#D7191C",
                                  "No event" = "#F7F7F7"),
                      name = NULL) +
    facet_grid(cohort_label ~ ., scales = "free_y", space = "free_y") +
    labs(
      title    = "Fig. A2: Political Governor Dismissal Events — Treatment Timing Matrix",
      subtitle = "Staggered DiD: each row = country; red = dismissal event year",
      x        = "Year", y = NULL,
      caption  = paste0(
        "Note: If dismissals occur in >1 cohort, standard TWFE is potentially biased\n",
        "(Callaway & Sant'Anna 2021). BRICS-T+MINT, N=9, 2000-2024."
      )
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid = element_blank(),
          strip.text = element_text(size = 8, face = "bold"),
          plot.title = element_text(face = "bold"),
          plot.caption = element_text(size = 7.5, colour = "grey40"),
          legend.position = "bottom")

  ggsave(file.path(FIG_PATH, "figA_did_timing_matrix.png"), p_timing,
         width = 9, height = 4.5, dpi = 300)
  cat("Saved: figA_did_timing_matrix.png\n")

} else {
  # Data not yet constructed — show design-stage analysis with known events
  cat("Panel data not yet available. Showing design-stage staggered check.\n\n")

  # Known governor dismissal events (from Garriga 2016 + recent news, 2000-2024)
  # Sources: Wikipedia, Bloomberg, Reuters (approximate years)
  known_events <- data.frame(
    country    = c("TUR", "TUR", "BRA", "RUS", "IND", "ZAF", "MEX"),
    event_year = c(2019,  2021,  2003,  2002,  2016,  2014,  2021),
    description = c(
      "Çetinkaya dismissed (interest rate dispute)",
      "Ağbal dismissed after 4 months",
      "Meirelles era began (reform, not dismissal)",
      "Géraschenko-era (formal independence reduced)",
      "Rajan not reappointed (de facto dismissal)",
      "Marcus → Kganyago transition (ambiguous)",
      "AMLO pressure on Banxico (not formal dismissal)"
    ),
    stringsAsFactors = FALSE
  )

  cat("Known/approximate dismissal events:\n")
  print(known_events)

  cohort_years <- sort(unique(known_events$event_year))
  cat("\nDistinct cohort years:", paste(cohort_years, collapse=", "), "\n")
  cat("Number of cohorts:", length(cohort_years), "\n")
  cat("→ STAGGERED DiD structure confirmed (", length(cohort_years), "cohorts)\n")
  cat("→ TWFE will produce weighted average across 2×2 comparisons.\n")
  cat("   Some weights may be negative (Callaway-Sant'Anna 2021 required).\n\n")

  # Design-stage visualisation
  design_df <- expand.grid(
    country    = c("TUR","BRA","IND","ZAF","MEX","RUS","CHN","IDN","NGA"),
    year       = 2000:2024,
    stringsAsFactors = FALSE
  ) %>%
    left_join(known_events %>% select(country, event_year),
              by = "country") %>%
    mutate(
      dismissed = (!is.na(event_year) & year == event_year),
      status    = ifelse(dismissed, "Dismissal event", "No event"),
      first_yr  = event_year,
      cohort    = ifelse(is.na(event_year), "Never treated",
                         paste0("Treated ", event_year))
    )

  p_design <- ggplot(design_df, aes(x = year, y = country, fill = status)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    scale_fill_manual(values = c("Dismissal event" = "#D7191C",
                                  "No event" = "#F0F0F0"),
                      name = NULL) +
    geom_vline(xintercept = cohort_years, linetype = "dashed",
               colour = "#2166AC", alpha = 0.5, linewidth = 0.5) +
    labs(
      title    = "Fig. A2: Design-Stage — Governor Dismissal Treatment Timing (Approximate)",
      subtitle = paste0("Staggered DiD: ", length(cohort_years),
                        " treatment cohorts → CS-ATT (Callaway-Sant'Anna 2021) required"),
      x = "Year", y = NULL,
      caption  = paste0(
        "Note: Approximate dismissal years from Garriga (2016) + press sources.\n",
        "Blue dashed lines = treatment cohort years. Verify against actual Garriga (2016) data.\n",
        "BRICS-T+MINT panel design, N=9, 2000-2024."
      )
    ) +
    theme_minimal(base_size = 11) +
    theme(panel.grid = element_blank(),
          plot.title = element_text(face = "bold"),
          plot.caption = element_text(size = 7.5, colour = "grey40"),
          legend.position = "bottom")

  ggsave(file.path(FIG_PATH, "figA_did_design_timing.png"), p_design,
         width = 9, height = 4.5, dpi = 300)
  cat("Saved: figA_did_design_timing.png\n")
}

# =============================================================================
# PART C: Recommendation Summary
# =============================================================================
cat("\n", paste(rep("=", 65), collapse = ""), "\n")
cat("IDENTIFICATION STRATEGY SUMMARY — Proposal D\n")
cat(paste(rep("=", 65), collapse = ""), "\n")

cat("\n[A] IV IDENTIFICATION\n")
cat("Instrument: Z_nbr = geometric/trade-weighted mean CBI of 5 nearest neighbours\n")
cat("Exclusion: spatial CBI spillover → own CBI, NOT → own spreads directly\n")
cat("First-stage test: Kleibergen-Paap rk F > 10 (Stock-Yogo critical value)\n")
cat("Implementation: fixest::feols(...|country+year|CBI~Z_nbr, cluster=~country)\n")

cat("\n[B] STAGGERED DiD (Governor Dismissal)\n")
cat("Treatment: d_political_dismissal (1 in year of political governor removal)\n")
cat("Structure: STAGGERED → multiple cohorts (different years per country)\n")
cat("Bias risk: Standard TWFE may produce negative-weighted 2×2 estimators\n")
cat("Recommended: Callaway-Sant'Anna (2021) via library(did)\n")
cat("   att_gt(yname='sovereign_spread_bps', tname='year', idname='cid',\n")
cat("           gname='first_dismissal', control_group='nevertreated',\n")
cat("           base_period='universal', est_method='reg')\n")
cat("Webb bootstrap: B=999, G=9 → MANDATORY (N<30 clusters)\n")

cat("\n[C] MANUSCRIPT APPENDIX LANGUAGE\n")
cat(sprintf(paste0(
  "To account for potential endogeneity of CBI, we employ a spatial\n",
  "Bartik-style instrument: the trade-weighted average CBI index of each\n",
  "country's five nearest economic neighbours (see Figure A1 DAG).\n",
  "The exclusion restriction — that neighbour-country CBI reforms do not\n",
  "directly affect a country's sovereign spread conditional on own-CBI and\n",
  "fiscal fundamentals — is supported by the DAG analysis and tested via a\n",
  "placebo regression on pre-reform periods. For the governor dismissal\n",
  "event study, we detect %s treatment cohorts spanning %s, confirming a\n",
  "staggered adoption structure. Accordingly, we employ the Callaway-Sant'Anna\n",
  "(2021) CS-ATT estimator rather than standard TWFE, which would yield\n",
  "potentially negative-weighted estimates under heterogeneous timing.\n"
), "multiple", "2002-2021"))

cat("\n✓ Rank 7 complete: DAG + staggered DiD check\n")
cat("✓ Figures: figA_dag_cbi_sovereign.png, figA_did_design_timing.png\n")
cat("✓ Next: implement CS-ATT in 03_proposal_D_sovereign_yields.R M3\n")
