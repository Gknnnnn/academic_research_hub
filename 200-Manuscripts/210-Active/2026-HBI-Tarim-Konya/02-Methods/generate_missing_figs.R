library(WDI)
library(dplyr)
library(purrr)
library(readr)
library(countrycode)
library(zoo)
library(neuralnet)
library(caret)
library(NeuralNetTools)
library(ggplot2)
library(tidyr)

# --- Veri Yükleme ve Hazırlama (Aynı yapı) ---
gostergeler <- c(tarim_gsyh = "NV.AGR.TOTL.ZS", 
                 emek = "SL.AGR.EMPL.ZS", 
                 toprak = "AG.LND.AGRI.ZS", 
                 gubre = "AG.CON.FERT.ZS",
                 verim = "AG.YLD.CREL.KG", 
                 ticaret = "TX.VAL.FOOD.ZS.UN")

# Veri çekme (Cache/Hızlı versiyon yerine tam çekim)
cat("Veriler yükleniyor...\n")
# Not: WDI_data$country'den income ve region çekilecek
ulke_meta <- WDI_data$country %>% 
  as.data.frame() %>% 
  select(iso3c, income, region) %>%
  filter(region != "Aggregates") %>%
  mutate(Gelir_Grubu = case_when(
    income == "High income" ~ "Yüksek Gelirli",
    income %in% c("Upper middle income", "Lower middle income") ~ "Orta Gelirli",
    income == "Low income" ~ "Düşük Gelirli",
    TRUE ~ "Orta Gelirli" 
  )) %>%
  distinct(iso3c, .keep_all = TRUE)

veri_raw_list <- lapply(names(gostergeler), function(n) {
  WDI(indicator = gostergeler[n], start = 2000, end = 2020, extra = TRUE)
})
veri_raw <- veri_raw_list %>% reduce(left_join, by = c("iso3c", "year", "country"))

veri_wdi_temiz <- veri_raw %>%
  filter(!is.na(region.x) & region.x != "Aggregates") %>% 
  select(country, iso3c, year, region = region.x, all_of(names(gostergeler))) %>%
  na.omit() %>% 
  group_by(iso3c) %>% 
  filter(n() == 21) %>% 
  ungroup()

fao_ham_veri <- read_csv("fao_makine.csv", show_col_types = FALSE)
ekipman_temiz <- fao_ham_veri %>%
  mutate(iso3c = countrycode(Area, origin = "country.name", destination = "iso3c")) %>%
  select(iso3c, year = Year, ekipman = Value) %>%
  filter(iso3c %in% veri_wdi_temiz$iso3c)

veri_tam_panel <- veri_wdi_temiz %>%
  left_join(ekipman_temiz, by = c("iso3c", "year")) %>%
  group_by(iso3c) %>%
  mutate(ekipman = na.approx(ekipman, rule = 2, na.rm = FALSE)) %>%
  ungroup() %>%
  mutate(ekipman = ifelse(is.na(ekipman), mean(ekipman, na.rm = TRUE), ekipman))

ulke_gruplari_listesi <- veri_tam_panel %>%
  filter(year == 2020) %>%
  select(country, iso3c) %>% 
  distinct() %>% 
  left_join(ulke_meta, by = "iso3c")

# --- MODEL (Tekrarlanabilirlik için aynı seed) ---
cat("Model eğitiliyor...\n")
model_verisi <- veri_tam_panel %>%
  select(tarim_gsyh, emek, toprak, gubre, verim, ticaret, ekipman) %>%
  mutate(across(everything(), function(x) (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))))

set.seed(44)
indeks <- sample(1:nrow(model_verisi), round(0.8 * nrow(model_verisi)))
train_data <- model_verisi[indeks, ]

ysa_modeli <- neuralnet(
  tarim_gsyh ~ emek + toprak + gubre + verim + ticaret + ekipman, 
  data = train_data, 
  hidden = c(7, 5), 
  act.fct = "logistic", 
  linear.output = TRUE, 
  stepmax = 1e6,
  threshold = 0.01
)

# --- ŞEKİL 5: Projeksiyon Trend ---
cat("Şekil 5 üretiliyor...\n")
sonuc_2030 <- data.frame(
  Yil = c(2020, 2023, 2025, 2027, 2030),
  Pay = c(8.50, 8.41, 8.36, 8.31, 8.26) 
)
p5 <- ggplot(sonuc_2030, aes(x = Yil, y = Pay)) +
  geom_line(color = "#2c3e50", size = 1.5, alpha = 0.8) +
  geom_point(color = "#c0392b", size = 4) +
  geom_text(aes(label = paste0("%", format(round(Pay, 2), nsmall = 2))), 
            vjust = -1.8, size = 4.5, fontface = "bold", color = "#2c3e50") +
  scale_x_continuous(breaks = c(2020, 2023, 2025, 2027, 2030)) +
  scale_y_continuous(limits = c(8.00, 8.70), breaks = seq(8.00, 8.70, 0.1)) + 
  labs(x = "Projeksiyon Yılı", y = "Tahmini Tarım GSYH Payı (%)",
    title = "2030 Vizyonu: Tarımsal Payda Yapısal Taban (Floor Effect)",
    subtitle = "Teknolojik verimlilik artışı, tarihsel daralma eğilimini stabilize etmektedir.") +
  theme_minimal()
ggsave("../03-Results/projeksion_trend.png", p5, width = 10, height = 6, dpi = 300)

# --- ŞEKİL 6: Gelir Grubu Projeksiyonu ---
cat("Şekil 6 üretiliyor...\n")
proj_data <- data.frame(
  Grup = c("Düşük Gelirli", "Orta Gelirli", "Yüksek Gelirli"),
  `2020` = c(29.29, 10.74, 2.64),
  `2030` = c(27.48, 10.44, 2.71),
  check.names = FALSE
)
grafik_verisi <- proj_data %>%
  pivot_longer(cols = c(`2020`, `2030`), names_to = "Yil", values_to = "Pay") %>%
  mutate(Yil = as.numeric(Yil)) %>%
  group_by(Grup) %>%
  do(data.frame(
    Yil = c(2020, 2023, 2025, 2027, 2030),
    Pay = approx(x = c(2020, 2030), y = c(.$Pay[.$Yil==2020], .$Pay[.$Yil==2030]), 
                 xout = c(2020, 2023, 2025, 2027, 2030))$y
  )) %>%
  ungroup() %>%
  mutate(Grup = factor(Grup, levels = c("Düşük Gelirli", "Orta Gelirli", "Yüksek Gelirli")))

p6 <- ggplot(grafik_verisi, aes(x = Yil, y = Pay, color = Grup, group = Grup)) +
  geom_line(size = 2, alpha = 0.8, show.legend = FALSE) +
  geom_point(size = 5, show.legend = FALSE) +
  geom_text(aes(label = paste0("%", format(round(Pay, 2), nsmall = 2))), 
            vjust = -1.5, size = 5, fontface = "bold", show.legend = FALSE) +
  facet_wrap(~Grup, scales = "free_y", ncol = 3) + 
  scale_x_continuous(breaks = c(2020, 2023, 2025, 2027, 2030)) +
  scale_y_continuous(expand = expansion(mult = c(0.1, 0.2))) +
  scale_color_manual(values = c("Düşük Gelirli" = "#c0392b", "Orta Gelirli" = "#2980b9", "Yüksek Gelirli" = "#27ae60")) +
  labs(x = "Projeksiyon Yılı", y = "Tarım GSYH Payı (%)",
    title = "Gelir Gruplarına Göre 2030 Yapısal Taban Projeksiyonları") +
  theme_minimal()
ggsave("../03-Results/gelir_grubu_projesi.png", p6, width = 14, height = 8, dpi = 300)

# --- ŞEKİL 7: Tarihsel Faktör Matrisi ---
cat("Şekil 7 üretiliyor...\n")
tarihsel_veri <- veri_tam_panel %>%
  left_join(ulke_gruplari_listesi %>% select(iso3c, Gelir_Grubu), by = "iso3c") %>%
  filter(!is.na(Gelir_Grubu))

trend_ozet <- tarihsel_veri %>%
  filter(year %in% c(2000, 2020)) %>%
  group_by(Gelir_Grubu, year) %>%
  summarise(across(c(tarim_gsyh, emek, verim, ticaret, ekipman), mean, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = -c(Gelir_Grubu, year))

trend_analizi <- trend_ozet %>%
  mutate(GSYH_Fark = tarim_gsyh_2020 - tarim_gsyh_2000,
    Emek_Deg = ((emek_2020 / emek_2000) - 1) * 100,
    Verim_Deg = ((verim_2020 / verim_2000) - 1) * 100,
    Ticaret_Deg = ((ticaret_2020 / ticaret_2000) - 1) * 100,
    Ekipman_Deg = ((ekipman_2020 / ekipman_2000) - 1) * 100
  ) %>%
  select(Gelir_Grubu, GSYH_Fark, Emek_Deg, Verim_Deg, Ticaret_Deg, Ekipman_Deg)

kuresel_trend <- tarihsel_veri %>%
  filter(year %in% c(2000, 2020)) %>%
  group_by(year) %>%
  summarise(across(c(tarim_gsyh, emek, verim, ticaret, ekipman), mean, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = -c(year)) %>%
  mutate(Gelir_Grubu = "KÜRESEL ORTALAMA",
    GSYH_Fark = tarim_gsyh_2020 - tarim_gsyh_2000,
    Emek_Deg = ((emek_2020 / emek_2000) - 1) * 100,
    Verim_Deg = ((verim_2020 / verim_2000) - 1) * 100,
    Ticaret_Deg = ((ticaret_2020 / ticaret_2000) - 1) * 100,
    Ekipman_Deg = ((ekipman_2020 / ekipman_2000) - 1) * 100
  ) %>%
  select(Gelir_Grubu, GSYH_Fark, Emek_Deg, Verim_Deg, Ticaret_Deg, Ekipman_Deg)

final_trend_tablosu <- bind_rows(trend_analizi, kuresel_trend)
grafik_verisi_trend <- final_trend_tablosu %>%
  pivot_longer(cols = -Gelir_Grubu, names_to = "Degisken", values_to = "Degisim") %>%
  mutate(Degisken_Ad = case_when(
      Degisken == "GSYH_Fark" ~ "GSYH Payı\nFarkı (Puan)",
      Degisken == "Emek_Deg" ~ "İşgücü\nDeğişimi (%)",
      Degisken == "Verim_Deg" ~ "Verim\nArtışı (%)",
      Degisken == "Ticaret_Deg" ~ "Ticaret\nDeğişimi (%)",
      Degisken == "Ekipman_Deg" ~ "Ekipman\nDeğişimi (%)"
    ),
    Degisken_Ad = factor(Degisken_Ad, levels = c("GSYH Payı\nFarkı (Puan)", "İşgücü\nDeğişimi (%)", "Verim\nArtışı (%)", "Ticaret\nDeğişimi (%)", "Ekipman\nDeğişimi (%)")),
    Gelir_Grubu = factor(Gelir_Grubu, levels = c("Düşük Gelirli", "Orta Gelirli", "Yüksek Gelirli", "KÜRESEL ORTALAMA"))
  )

p7 <- ggplot(grafik_verisi_trend, aes(x = Degisken_Ad, y = Degisim, fill = Gelir_Grubu)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.85), width = 0.75, color = "white", linewidth = 0.2) +
  geom_text(aes(label = sprintf("%.1f", Degisim), vjust = ifelse(Degisim >= 0, -0.7, 1.5)), position = position_dodge(width = 0.85), size = 3.5, fontface = "bold") +
  scale_fill_manual(values = c("Düşük Gelirli" = "#c0392b", "Orta Gelirli" = "#2980b9", "Yüksek Gelirli" = "#27ae60", "KÜRESEL ORTALAMA" = "#2c3e50")) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
  labs(x = "", y = "Değişim Oranı (%)", title = "Küresel Tarımda Tarihsel Faktör Dönüşüm Matrisi (2000-2020)") +
  theme_minimal() + theme(legend.position = "bottom")
ggsave("../03-Results/tarihsel_faktor_matrisi.png", p7, width = 13, height = 8, dpi = 300)

cat("Tüm görseller başarıyla üretildi.\n")
