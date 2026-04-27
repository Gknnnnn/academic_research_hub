# =============================================================================
# Script 06 — DAG: Bartik Exclusion Restriction Visualisation
# Paper: "Cognitive Barriers to Circular Economy Adoption: A Micro-Macro
#          Panel Analysis for EU-27"
# Author: Res. Asst. Dr. M. Gökhan Özdemir
# Target: Ecological Economics / Resources, Conservation & Recycling (Q1)
# Version: 2026-04-24
#
# PURPOSE:
#   Formalise and visualise the causal identification structure underlying
#   the Bartik shift-share IV (Script 05). The DAG makes three claims:
#     (E1) Relevance  : Z → CBI (green employment shifts → cognitive barrier)
#     (E2) Exclusion  : Z ⊥ CE_Action | CBI, U_obs (no direct path Z → Y)
#     (E3) Monotonicity: Z → CBI positive for all countries
#   Two supporting figures:
#     Fig A1: Full SCM (exposure=CBI, outcome=CE_Action)
#     Fig A2: Adjustment set (back-door criterion satisfied by observed controls)
#
# Literature:
#   Goldsmith-Pinkham, Sorkin & Swift (2020, AER)
#     doi:10.1257/aer.20181047
#   Pearl (2009) — Causality, CUP
#   Hernán & Robins (2020) — Causal Inference
#   Textor et al. (2011) dagitty — doi:10.1093/ije/dyr218
# =============================================================================

for (pkg in c("dagitty", "ggdag", "ggplot2", "dplyr")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
}
library(dagitty)
library(ggdag)
library(ggplot2)
library(dplyr)

BASE_PATH <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-CE-Cognitive-Econometrics"
FIG_PATH  <- file.path(BASE_PATH, "600-Results/CE_pilot_v3")
dir.create(FIG_PATH, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# 1. FULL SCM (Structural Causal Model)
# =============================================================================
# Nodes:
#   Z        = Bartik instrument (shift-share green employment growth)
#   CBI      = Cognitive Barrier Index [ENDOGENOUS, EXPOSURE]
#   CE_Action= Circular Economy adoption behaviour [OUTCOME]
#   U_ind    = Unobserved individual heterogeneity (preferences, values) [LATENT]
#   U_ctry   = Unobserved country-level factors (culture, institutions) [LATENT]
#   X_obs    = Observed controls (age, female, income, urban, employed)
#   Ctry_FE  = Country fixed effects (control for time-invariant U_ctry)
#
# Causal claims (Bartik exclusion):
#   Z → CBI          : shift-share exposure raises green job availability
#                       → reduced CBI via learning-by-doing / social norms
#   CBI → CE_Action  : main causal path of interest
#   X_obs → CBI      : socio-demographics shape cognitive barriers
#   X_obs → CE_Action: direct effect of demographics on pro-environmental behaviour
#   U_ind → CBI      : individual values → CBI (unmeasured)
#   U_ind → CE_Action: individual values → CE behaviour (unmeasured)
#   U_ctry → CBI     : culture → cognitive barriers (proxied by Ctry_FE)
#   U_ctry → CE_Action: culture → CE adoption (proxied by Ctry_FE)
#   Ctry_FE → Z      : country economic structure → instrument (by construction)
#   Ctry_FE → CBI    : absorbs U_ctry in regression
#   Ctry_FE → CE_Action: absorbs U_ctry in regression
#
# Key EXCLUSION claim: NO direct path Z → CE_Action.
# This is justified by:
#   - Bartik Z is constructed from 2010 sector shares × national shift g_{s,t}
#   - The national shift is a supply-side green-transition shock
#   - Conditional on X_obs + Ctry_FE, Z has no direct effect on individual CE decisions
# =============================================================================

dag_full <- dagitty('dag {
  Z         [pos="0,1"]
  CBI       [pos="2,1" exposure]
  CE_Action [pos="4,1" outcome]
  U_ind     [pos="3,0" latent]
  U_ctry    [pos="1,2" latent]
  X_obs     [pos="2,2"]
  Ctry_FE   [pos="0,2"]

  Z -> CBI
  CBI -> CE_Action
  X_obs -> CBI
  X_obs -> CE_Action
  U_ind -> CBI
  U_ind -> CE_Action
  U_ctry -> CBI
  U_ctry -> CE_Action
  Ctry_FE -> Z
  Ctry_FE -> CBI
  Ctry_FE -> CE_Action
}')

cat("=== DAG: Bartik Exclusion SCM ===\n")
cat("Is acyclic:", isAcyclic(dag_full), "\n")

# Adjustment set for CBI → CE_Action (back-door)
adj_full <- adjustmentSets(dag_full, "CBI", "CE_Action", type = "all")
cat("\nAdjustment sets for CBI → CE_Action:\n")
print(adj_full)

# Implied conditional independencies (testable predictions)
ci_full <- impliedConditionalIndependencies(dag_full)
cat("\nTestable conditional independencies:\n")
for (ci in ci_full) cat(" ", as.character(ci), "\n")

# KEY TESTABLE PREDICTION (Exclusion):
# Z ⊥ CE_Action | CBI, X_obs, Ctry_FE
# i.e., after controlling for CBI + covariates, Bartik instrument is independent of outcome
cat("\nKey exclusion test: Z ⊥ CE_Action | CBI, X_obs, Ctry_FE\n")
cat("This is the Bartik exclusion restriction — testable via placebo in Script 05.\n")

# =============================================================================
# 2. Figure A1: Full SCM visualisation
# =============================================================================

# Build tidy DAG manually for better layout control
node_data <- data.frame(
  name = c("Z", "CBI", "CE_Action", "U_ind", "U_ctry", "X_obs", "Ctry_FE"),
  x    = c(0, 2, 4, 3, 1, 2.5, 0),
  y    = c(1, 1, 1, 2, 0, 0,   0),
  node_type = c("instrument", "exposure", "outcome",
                "latent", "latent", "observed_control", "fixed_effect"),
  stringsAsFactors = FALSE
)

edge_data <- data.frame(
  from = c("Z",    "CBI", "X_obs", "X_obs",    "U_ind", "U_ind",     "U_ctry", "U_ctry",     "Ctry_FE", "Ctry_FE", "Ctry_FE"),
  to   = c("CBI",  "CE_Action", "CBI", "CE_Action", "CBI", "CE_Action", "CBI", "CE_Action", "Z",       "CBI",     "CE_Action"),
  style = c("solid", "solid", "solid", "solid",
            "dashed", "dashed", "dashed", "dashed",
            "dotted", "dotted", "dotted"),
  label = c("Relevance\n(E1)", "Main\ncausal path", "Controls", "Controls",
            "Unobs.\nheterog.", "Unobs.\nheterog.", "Unobs.\nculture", "Unobs.\nculture",
            "Struct.", "Struct.", "Struct."),
  stringsAsFactors = FALSE
)

# Colour palette
type_colours <- c(
  "instrument"        = "#1A9641",
  "exposure"          = "#D7191C",
  "outcome"           = "#2166AC",
  "latent"            = "#762A83",
  "observed_control"  = "#F4A582",
  "fixed_effect"      = "#969696"
)

# Create ggplot manually (ggdag layout can be overridden)
p_scm <- ggplot() +
  # Edges: draw arrows using geom_segment with arrow
  geom_segment(
    data = edge_data %>%
      left_join(node_data %>% rename(from = name, x_from = x, y_from = y), by = "from") %>%
      left_join(node_data %>% rename(to   = name, x_to   = x, y_to   = y), by = "to"),
    aes(x = x_from, y = y_from, xend = x_to, yend = y_to, linetype = style),
    arrow = arrow(length = unit(0.20, "cm"), type = "closed"),
    colour = "grey30", linewidth = 0.7,
    position = "identity"
  ) +
  # Nodes
  geom_point(
    data = node_data,
    aes(x = x, y = y, colour = node_type, shape = node_type),
    size = 8
  ) +
  geom_text(
    data = node_data,
    aes(x = x, y = y, label = name),
    size = 3.5, fontface = "bold", colour = "white"
  ) +
  scale_colour_manual(values = type_colours,
                      labels = c("Fixed effects", "Instrument (Bartik Z)", "Latent", "Exposure (CBI)",
                                 "Observed controls", "Outcome (CE Action)"),
                      name = "Node type") +
  scale_shape_manual(values = c("instrument" = 15, "exposure" = 19, "outcome" = 17,
                                "latent" = 8, "observed_control" = 18, "fixed_effect" = 14),
                     name = "Node type") +
  scale_linetype_manual(values = c("solid" = "solid", "dashed" = "dashed", "dotted" = "dotted"),
                        labels = c("Direct causal", "Unobserved", "Structural/control"),
                        name = "Edge type") +
  annotate("label", x = 1, y = 1.3, label = "Exclusion:\nZ ⊥ CE_Action | CBI, X",
           size = 2.8, colour = "#1A9641", fill = "#F7FCF5",
           label.padding = unit(0.3, "lines")) +
  labs(
    title    = "Fig. A1: Structural Causal Model — Bartik IV Identification",
    subtitle = "Bartik shift-share instrument (Z) satisfies exclusion restriction: Z → CBI, no direct Z → CE_Action path",
    caption  = paste0(
      "Note: U_ind, U_ctry = latent confounders (unobserved individual preferences + country culture).\n",
      "Adjustment set: {X_obs, Ctry_FE}. Testable exclusion: Z ⊥ CE_Action | CBI, X_obs, Ctry_FE.\n",
      "EU-27 micro panel (EB 95.1/98.1/101.2), N≈20k individuals across 27 countries."
    )
  ) +
  theme_void(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 11, margin = margin(b = 4)),
    plot.subtitle = element_text(size = 9, colour = "grey30", margin = margin(b = 8)),
    plot.caption  = element_text(size = 7.5, colour = "grey40", hjust = 0),
    plot.margin   = margin(10, 10, 10, 10),
    legend.position = "right"
  )

fig_a1 <- file.path(FIG_PATH, "figA_dag_bartik_scm.png")
ggsave(fig_a1, p_scm, width = 9, height = 5, dpi = 300)
cat("Saved:", fig_a1, "\n")

# =============================================================================
# 3. Figure A2: Adjustment set visualisation (back-door paths)
# =============================================================================

# Back-door paths from CBI to CE_Action (confounders that need control):
# Path 1: CBI ← U_ind → CE_Action  (unobserved, not closeable — IV needed)
# Path 2: CBI ← U_ctry → CE_Action  (proxied by Ctry_FE)
# Path 3: CBI ← X_obs → CE_Action  (closed by controlling X_obs)

bd_df <- data.frame(
  path   = c("CBI ← U_ind → CE_Action",
             "CBI ← U_ctry → CE_Action",
             "CBI ← X_obs → CE_Action"),
  type   = c("Unobservable\n(IV required)", "Proxied by\nCtry_FE", "Closed by\ncontrolling X_obs"),
  status = c("Open — requires IV", "Closed by Ctry_FE", "Closed by X_obs"),
  colour = c("#D7191C", "#1A9641", "#2166AC")
)

p_adj <- ggplot(bd_df, aes(x = 1, y = seq_along(path), label = paste0(path, "\n→ ", status))) +
  geom_tile(aes(fill = status), width = 3.8, height = 0.7, alpha = 0.15,
            colour = bd_df$colour, linewidth = 0.8) +
  geom_text(size = 3.2, fontface = c("bold", "plain", "plain")) +
  scale_fill_manual(values = c("Open — requires IV" = "#D7191C",
                               "Closed by Ctry_FE" = "#1A9641",
                               "Closed by X_obs"   = "#2166AC"),
                    name = NULL) +
  xlim(-1.5, 3.5) +
  labs(
    title    = "Fig. A2: Back-Door Paths and Adjustment Strategy",
    subtitle = "Three confounding pathways; Bartik IV closes the unobservable path",
    caption  = paste0(
      "Note: Back-door criterion (Pearl 2009). Adjustment set: {X_obs, Ctry_FE}.\n",
      "Residual confounding via U_ind is addressed by Bartik IV in Script 05.\n",
      "Bartik exclusion means Z does not open new back-door paths."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text  = element_blank(), axis.title = element_blank(),
    panel.grid = element_blank(),
    plot.title    = element_text(face = "bold"),
    plot.caption  = element_text(size = 7.5, colour = "grey40"),
    legend.position = "bottom"
  )

fig_a2 <- file.path(FIG_PATH, "figA_dag_adjustment_bartik.png")
ggsave(fig_a2, p_adj, width = 8, height = 4, dpi = 300)
cat("Saved:", fig_a2, "\n")

# =============================================================================
# 4. Manuscript appendix text
# =============================================================================
cat("\n=== MANUSCRIPT APPENDIX LANGUAGE ===\n")
cat(sprintf(paste0(
  "We formalise identification via a Directed Acyclic Graph (DAG; Pearl 2009).\n",
  "The Bartik shift-share instrument Z (country × year exposure to national green-\n",
  "sector employment growth, constructed from 2010 industry composition shares)\n",
  "satisfies three conditions: (E1) relevance — Z predicts CBI through green labour\n",
  "market spillovers and social norm diffusion; (E2) exclusion — conditional on\n",
  "observed covariates X and country fixed effects, Z does not directly influence\n",
  "CE_Action (no Z → CE_Action path in the DAG); and (E3) monotonicity — Z increases\n",
  "green labour exposure uniformly across individuals. The back-door paths from CBI\n",
  "to CE_Action are: unobserved individual heterogeneity U_ind (addressed by IV),\n",
  "country culture U_ctry (proxied by country fixed effects), and observed\n",
  "socio-demographics X_obs (controlled directly). The exclusion restriction\n",
  "is tested via a pre-CEAP (2010-2019) placebo regression reported in Table A5.\n"
)))

cat("\n✓ Rank 6 DAG complete. Figures: figA_dag_bartik_scm.png, figA_dag_adjustment_bartik.png\n")
