# =============================================================================
# IGI Global — Eurasian Energy Chapter
# Script 03: Manuscript Figures
# Author: Res. Asst. Dr. M. Gökhan Özdemir | 2026-04-22
# =============================================================================

library(ggplot2)
library(dplyr)
library(tidyr)

panel <- read.csv("../02-Data/panel_eurasian_energy_20260422.csv")

panel <- panel %>%
  mutate(status = ifelse(energy_dep < 0, "Net Exporter", "Net Importer"))

# Stable importer/exporter classification (based on period mean)
country_status <- panel %>%
  group_by(iso3c, country) %>%
  summarise(mean_dep = mean(energy_dep, na.rm=TRUE), .groups="drop") %>%
  mutate(status = ifelse(mean_dep < 0, "Net Exporter", "Net Importer"))

panel <- panel %>%
  select(-any_of("status")) %>%
  left_join(country_status %>% select(iso3c, status), by="iso3c")

theme_mgo <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor  = element_blank(),
    panel.border      = element_rect(colour="grey80", fill=NA),
    strip.background  = element_rect(fill="grey95"),
    legend.position   = "bottom",
    plot.title        = element_text(face="bold", size=11),
    plot.subtitle     = element_text(colour="grey40", size=9),
    plot.caption      = element_text(colour="grey50", size=8, hjust=0)
  )

# --- Figure 1: CA Balance Trends — Importers vs Exporters -------------------
ca_trends <- panel %>%
  filter(!is.na(ca_bal)) %>%
  group_by(year, status) %>%
  summarise(
    mean_ca = mean(ca_bal, na.rm=TRUE),
    se_ca   = sd(ca_bal, na.rm=TRUE) / sqrt(n()),
    .groups = "drop"
  )

fig1 <- ggplot(ca_trends, aes(x=year, y=mean_ca, colour=status, fill=status)) +
  geom_ribbon(aes(ymin=mean_ca-se_ca, ymax=mean_ca+se_ca), alpha=0.15, colour=NA) +
  geom_line(linewidth=1.1) +
  geom_point(size=2) +
  geom_hline(yintercept=0, linetype="dashed", colour="grey50", linewidth=0.6) +
  scale_colour_manual(values=c("Net Exporter"="#2166ac","Net Importer"="#d6604d")) +
  scale_fill_manual(values=c("Net Exporter"="#2166ac","Net Importer"="#d6604d")) +
  scale_x_continuous(breaks=seq(2000,2022,4)) +
  labs(
    title    = "Current Account Balance Diverges Persistently by Energy Status",
    subtitle = "Eurasian economies (N=14), 2000–2022 — shaded = ±1 SE",
    x = NULL, y = "Current account balance (% of GDP)",
    colour = NULL, fill = NULL,
    caption = "Source: World Bank WDI (BN.CAB.XOKA.GD.ZS). Author's calculations."
  ) +
  theme_mgo

ggsave("../04-Manuscript/fig1_ca_trends.png", fig1,
       width=7, height=4, dpi=300, bg="white")
ggsave("../04-Manuscript/fig1_ca_trends.pdf", fig1,
       width=7, height=4, bg="white")
cat("Figure 1 saved.\n")

# --- Figure 2: Energy Dependency Distribution (dot plot) --------------------
country_sum <- panel %>%
  group_by(iso3c, country, status) %>%
  summarise(
    mean_dep = mean(energy_dep, na.rm=TRUE),
    mean_ca  = mean(ca_bal, na.rm=TRUE),
    .groups  = "drop"
  ) %>%
  arrange(mean_dep) %>%
  mutate(country = factor(country, levels=country))

fig2 <- ggplot(country_sum, aes(x=mean_dep, y=country, colour=status)) +
  geom_vline(xintercept=0, linetype="dashed", colour="grey50") +
  geom_point(aes(size=abs(mean_ca)), alpha=0.85) +
  scale_colour_manual(values=c("Net Exporter"="#2166ac","Net Importer"="#d6604d")) +
  scale_size_continuous(range=c(3,10), name="|CA balance| (pp)") +
  scale_x_continuous(labels=function(x) paste0(x,"%")) +
  labs(
    title    = "Energy Dependency and Current Account Position: Country Averages (2000–2022)",
    subtitle = "Dot size = absolute current account balance (% GDP)",
    x = "Mean energy import dependency (% of energy use)",
    y = NULL, colour = NULL,
    caption = "Source: World Bank WDI. Author's calculations."
  ) +
  theme_mgo +
  theme(legend.box="vertical")

ggsave("../04-Manuscript/fig2_country_dot.png", fig2,
       width=7, height=5, dpi=300, bg="white")
ggsave("../04-Manuscript/fig2_country_dot.pdf", fig2,
       width=7, height=5, bg="white")
cat("Figure 2 saved.\n")

cat("=== FIGURES COMPLETE ===\n")
