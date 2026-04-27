# ============================================================
# AI Strategy Carbon DiD — Figures (v0.1)
# Author: M. Gökhan Özdemir | 2026-04-09
# ============================================================
suppressPackageStartupMessages({
  library(dplyr); library(ggplot2); library(fixest)
  library(did); library(readr)
})

PROJ   <- here::here()
FIG    <- file.path(PROJ, "600-Results/figures")
dir.create(FIG, showWarnings=FALSE, recursive=TRUE)

results <- readRDS(file.path(PROJ, "600-Results/main_results.rds"))
cs_dyn  <- results$cs_dyn

# ── Figure 1: CS-ATT Event-study plot ────────────────────────────────────────
es_df <- tibble(
  e     = cs_dyn$egt,
  att   = cs_dyn$att.egt,
  se    = cs_dyn$se.egt,
  ci_lo = att - 1.96 * se,
  ci_hi = att + 1.96 * se,
  pre   = e < 0
)

fig1 <- ggplot(es_df, aes(x = e, y = att)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_vline(xintercept = -0.5, linetype = "dotted", colour = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), fill = "steelblue", alpha = 0.20) +
  geom_line(colour = "steelblue3", linewidth = 0.7) +
  geom_point(aes(shape = pre, fill = pre), size = 2.8, colour = "steelblue4") +
  scale_shape_manual(values = c(21, 22), guide = "none") +
  scale_fill_manual(values = c("white", "steelblue3"), guide = "none") +
  scale_x_continuous(breaks = seq(-5, 4, 1),
                     labels = c("-5","-4","-3","-2","-1","0","1","2","3","4")) +
  labs(
    x     = "Years relative to AI strategy adoption",
    y     = expression(paste("CS-ATT on ", ln(CO[2]/capita))),
    title = "Event-Study: National AI Strategy Adoption and Per Capita CO\u2082 Emissions",
    subtitle = "Callaway\u2013Sant\u2019Anna ATT, never-treated control group, 95% CI"
  ) +
  annotate("text", x = -3.5, y = max(es_df$ci_hi)*0.85,
           label = "Pre-treatment period\n(parallel trends passes)", size = 2.8,
           colour = "grey40", hjust = 0) +
  annotate("text", x = 2.5, y = min(es_df$ci_lo)*0.85,
           label = "Delayed effect\n(years 3\u20134)",
           size = 2.8, colour = "steelblue4", hjust = 0) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(size = 10, face = "bold"),
    plot.subtitle    = element_text(size = 8.5, colour = "grey40")
  )

ggsave(file.path(FIG, "fig1_eventstudy_co2.pdf"), fig1,
       width = 7, height = 4.5, device = cairo_pdf)
ggsave(file.path(FIG, "fig1_eventstudy_co2.png"), fig1,
       width = 7, height = 4.5, dpi = 300)
message("Figure 1 saved.")

# ── Figure 2: Goodman-Bacon decomposition ─────────────────────────────────────
# Uses bacondecomp package
if (!requireNamespace("bacondecomp", quietly = TRUE)) {
  install.packages("bacondecomp", repos = "https://cran.r-project.org")
}
library(bacondecomp)

panel <- readRDS(file.path(PROJ, "400-Data/processed/ai_strategy_panel.rds")) %>%
  filter(year >= 2005, year <= 2023) %>%
  group_by(iso_code) %>% filter(n() >= 10) %>% ungroup() %>%
  filter(!is.na(ln_co2pc), !is.na(ln_gdppc))

bacon_out <- bacon(ln_co2pc ~ post,
                   data = panel %>%
                     select(iso_code, year, ln_co2pc, post) %>%
                     arrange(iso_code, year),
                   id_var = "iso_code",
                   time_var = "year",
                   quietly = TRUE)

cat("Goodman-Bacon decomposition:\n")
bacon_sum <- bacon_out %>%
  group_by(type) %>%
  summarise(mean_est = weighted.mean(estimate, weight),
            total_wt = sum(weight), .groups = "drop")
print(bacon_sum)

fig2 <- ggplot(bacon_out, aes(x = weight, y = estimate, colour = type, shape = type)) +
  geom_point(size = 2.5, alpha = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  scale_colour_manual(
    values = c("Earlier vs Later Treated" = "#e74c3c",
               "Later vs Earlier Treated" = "#e67e22",
               "Treated vs Untreated"     = "#2980b9"),
    name = "Comparison type"
  ) +
  scale_shape_manual(
    values = c("Earlier vs Later Treated" = 17,
               "Later vs Earlier Treated" = 15,
               "Treated vs Untreated"     = 16),
    name = "Comparison type"
  ) +
  labs(
    x     = "Weight in TWFE estimator",
    y     = "DiD estimate",
    title = "Goodman-Bacon Decomposition of TWFE Estimate",
    subtitle = paste0("Overall TWFE \u03b2 = ",
                      round(coef(results$m_co2)["post"], 3),
                      "; weighted avg of these comparisons")
  ) +
  theme_bw(base_size = 11) +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    plot.title       = element_text(size = 10, face = "bold"),
    plot.subtitle    = element_text(size = 8.5, colour = "grey40")
  )

ggsave(file.path(FIG, "fig2_goodman_bacon.pdf"), fig2,
       width = 7, height = 4.5, device = cairo_pdf)
ggsave(file.path(FIG, "fig2_goodman_bacon.png"), fig2,
       width = 7, height = 4.5, dpi = 300)
message("Figure 2 (Goodman-Bacon) saved.")

# Save bacon summary for manuscript
saveRDS(list(bacon_out=bacon_out, bacon_sum=bacon_sum),
        file.path(PROJ, "600-Results/bacon_decomp.rds"))
