# 01_data_load_descriptives.R
# Load panel, validate, produce Table 1 (descriptive statistics)
# PSE × AgTFP OECD | MGO × HBI

library(tidyverse); library(plm); library(stargazer); library(xtable)

# ── Paths (adjust if running standalone) ──────────────────────────────────────
CLEAN <- "../../06-Data/clean"
TBLS  <- "../../03-Results/tables"
FIGS  <- "../../03-Results/figures"

# ── Load data ──────────────────────────────────────────────────────────────────
df <- read_csv(file.path(CLEAN, "panel_master.csv"), show_col_types = FALSE)
cat("Loaded:", nrow(df), "obs ×", ncol(df), "vars\n")
cat("Countries:", n_distinct(df$iso3), "| Years:", min(df$year), "-", max(df$year), "\n")

# ── Variable engineering ───────────────────────────────────────────────────────
df <- df %>%
  mutate(
    ln_tfp    = log(tfp_index),
    ln_gdppc  = log(gdppc_const2015),
    ln_fert   = log(fertilizer_kgha + 0.001),   # +ε to handle zeros
    ln_agland = log(agland_share + 0.001),
    # PSE variables (will be NA until PSE data merged)
    mps_share_w  = case_when(
      !is.na(mps_share) ~ pmin(pmax(mps_share, 0), 1),  # Winsorize [0,1]
      TRUE ~ NA_real_
    ),
    gsse_share_w = case_when(
      !is.na(gsse_share) ~ pmin(pmax(gsse_share, 0), 1),
      TRUE ~ NA_real_
    )
  )

# ── Panel object ───────────────────────────────────────────────────────────────
pdata <- pdata.frame(df, index = c("iso3", "year"))

# Check panel balance
cat("\nBalance check:\n")
print(is.pbalanced(pdata))

# ── Table 1: Descriptive Statistics ───────────────────────────────────────────
desc_vars <- c("tfp_index", "pse_pct", "mps_share", "gsse_share",
               "gdppc_const2015", "rural_share", "fertilizer_kgha",
               "agr_va_gdp")
desc_labels <- c("Agricultural TFP Index (1961=100)",
                 "% PSE",
                 "MPS Share (MPS/PSE)",
                 "GSSE Share (GSSE/(PSE+GSSE))",
                 "GDP per capita (const. 2015 USD)",
                 "Rural Population Share (%)",
                 "Fertilizer Consumption (kg/ha)",
                 "Agriculture VA (% GDP)")

# Build summary table manually
desc_df <- df %>%
  select(any_of(desc_vars)) %>%
  summarise(across(everything(), list(
    N    = ~sum(!is.na(.)),
    Mean = ~mean(., na.rm=TRUE),
    SD   = ~sd(., na.rm=TRUE),
    Min  = ~min(., na.rm=TRUE),
    Max  = ~max(., na.rm=TRUE)
  ))) %>%
  pivot_longer(everything(), names_to=c("var","stat"), names_sep="_(?=[^_]+$)") %>%
  pivot_wider(names_from=stat, values_from=value)

# Add labels
desc_df$Label <- desc_labels[match(desc_df$var, desc_vars)]
desc_df <- desc_df %>% select(Label, N, Mean, SD, Min, Max)

cat("\nTable 1 — Descriptive Statistics:\n")
print(desc_df, n=Inf)

# Export as LaTeX
tab1_tex <- xtable(desc_df,
  caption = "Descriptive Statistics",
  label   = "tab:desc",
  digits  = c(0, 0, 0, 2, 2, 2, 2)
)
print(tab1_tex,
  file            = file.path(TBLS, "tab1_descriptives.tex"),
  include.rownames = FALSE,
  booktabs        = TRUE,
  caption.placement = "top"
)
cat("→ Saved: tab1_descriptives.tex\n")

# ── Figure 1: PSE % vs TFP trends (OECD average) ─────────────────────────────
if ("pse_pct" %in% names(df)) {
  fig_data <- df %>%
    group_by(year) %>%
    summarise(
      mean_tfp = mean(tfp_index, na.rm=TRUE),
      mean_pse = mean(pse_pct, na.rm=TRUE),
      .groups = "drop"
    )

  p1 <- ggplot(fig_data, aes(x=year)) +
    geom_line(aes(y=mean_tfp, colour="AgTFP Index"), linewidth=0.9) +
    scale_y_continuous(name="AgTFP Index (OECD avg)") +
    theme_bw(base_size=11) +
    labs(colour=NULL, x=NULL) +
    theme(legend.position="bottom")

  p2 <- ggplot(fig_data, aes(x=year)) +
    geom_line(aes(y=mean_pse, colour="% PSE"), colour="steelblue", linewidth=0.9) +
    geom_hline(yintercept=0, linetype="dashed", colour="grey50") +
    scale_y_continuous(name="% PSE (OECD avg)") +
    theme_bw(base_size=11) + labs(x=NULL)

  # Try patchwork if available
  if (requireNamespace("patchwork", quietly=TRUE)) {
    library(patchwork)
    fig1 <- p1 / p2 + plot_annotation(
      title = "Agricultural TFP and Producer Support (OECD Average, 1990–2020)",
      theme = theme(plot.title = element_text(size=11, face="bold"))
    )
    ggsave(file.path(FIGS, "fig1_pse_tfp_trends.pdf"), fig1,
           width=7, height=5, device="pdf")
    cat("→ Saved: fig1_pse_tfp_trends.pdf\n")
  }
}

cat("\n✓ Step 1 complete: Descriptives done.\n")
cat("  Next: source('02_CD_slope_tests.R')\n")
