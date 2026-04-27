suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(tibble)
})

base_dir <- "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/300-Projects/310-Active-Papers/2026-HBI-Tarim-Konya"
results_dir <- file.path(base_dir, "03-Results")

scenario_summary <- readr::read_csv(
  file.path(results_dir, "scenario_summary_2030_authoritative.csv"),
  show_col_types = FALSE
)

write.csv(
  scenario_summary,
  file.path(results_dir, "scenario_summary_2030.csv"),
  row.names = FALSE
)

global_ref <- scenario_summary %>%
  filter(Gelir_Grubu == "Kuresel Ortalama")

global_paths <- tibble(
  Senaryo = c("Kötü", "Orta", "İyi"),
  `2020` = c(global_ref$`2020`, global_ref$`2020`, global_ref$`2020`),
  `2030` = c(global_ref$Kotu, global_ref$Orta, global_ref$Iyi)
) %>%
  pivot_longer(cols = c(`2020`, `2030`), names_to = "Yil", values_to = "Pay") %>%
  mutate(Yil = as.numeric(Yil))

p_global <- ggplot(global_paths, aes(x = Yil, y = Pay, color = Senaryo, group = Senaryo)) +
  geom_line(linewidth = 1.8, alpha = 0.9) +
  geom_point(size = 4.5) +
  geom_text(
    aes(label = paste0("%", format(round(Pay, 2), nsmall = 2))),
    vjust = -1.1,
    size = 4.1,
    fontface = "bold",
    show.legend = FALSE
  ) +
  scale_color_manual(values = c("Kötü" = "#b91c1c", "Orta" = "#2563eb", "İyi" = "#15803d")) +
  scale_x_continuous(breaks = c(2020, 2030)) +
  labs(
    title = "Küresel Tarım Payı: 2020 Baz Değeri ve 2030 Üç Senaryo",
    subtitle = "Yetkili tablo rakamlarıyla birebir: Kötü %5.79, Orta %6.13, İyi %6.27",
    x = "Yıl",
    y = "Tarım GSYH Payı (%)",
    color = "Senaryo"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(
  file.path(results_dir, "scenario_global_paths.png"),
  p_global,
  width = 12,
  height = 7,
  dpi = 180
)

group_bars <- scenario_summary %>%
  filter(Gelir_Grubu != "Kuresel Ortalama") %>%
  pivot_longer(cols = c(Kotu, Orta, Iyi), names_to = "Senaryo", values_to = "Pay")

p_groups <- ggplot(group_bars, aes(x = Gelir_Grubu, y = Pay, fill = Senaryo)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.64) +
  geom_text(
    aes(label = sprintf("%.2f", Pay)),
    position = position_dodge(width = 0.72),
    vjust = -0.25,
    size = 3.6
  ) +
  scale_fill_manual(values = c(Kotu = "#b91c1c", Orta = "#2563eb", Iyi = "#15803d")) +
  labs(
    title = "2030 Senaryoları: Gelir Gruplarına Göre Karşılaştırma",
    subtitle = "Yapısal taban tek sayı değil; gelir grubuna göre farklı bantlarda oluşuyor",
    x = NULL,
    y = "2030 tahmini tarım GSYH payı (%)",
    fill = "Senaryo"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

ggsave(
  file.path(results_dir, "scenario_group_bars.png"),
  p_groups,
  width = 12,
  height = 7,
  dpi = 180
)

cat("Generated authoritative scenario outputs:\n")
cat(file.path(results_dir, "scenario_summary_2030.csv"), "\n")
cat(file.path(results_dir, "scenario_global_paths.png"), "\n")
cat(file.path(results_dir, "scenario_group_bars.png"), "\n")
